//
//  MessageStore.swift
//  Aether
//
//  Observable message state manager for basic human-LLM chat interface
//
//  BLUEPRINT SECTION: 🚨 Core - Message Management
//  ===============================================
//
//  DESIGN PRINCIPLES:
//  - Separation of Concerns: Message state management only, no UI logic
//  - Single Source of Truth: Shared conversation state across all UI components
//  - No Hardcoding: Clean, maintainable message flow
//  - Thread Safety: All UI updates on main thread via @MainActor
//
//  RESPONSIBILITIES:
//  - Manage conversation message array state
//  - Coordinate with LLM services for responses
//  - Handle streaming message updates
//  - Provide clean interface for UI components
//
//  CURRENT SCOPE: Complete memory-integrated chat interface with superjournal
//  - Hardcoded "User" and "AI" authors (intentionally simple before persona system)
//  - Full conversation persistence and Boss profile integration
//  - Agentic superjournal auto-save for complete audit trail
//  - Foundation for future persona system
//
//  ACHIEVEMENTS TODAY:
//  ✅ Boss profile integration - AI knows who Boss is and his role
//  ✅ Superjournal auto-save - Every turn automatically preserved
//  ✅ Existing conversation migration - "What is outer space?" conversations preserved
//  ✅ Enterprise-grade audit trail - Complete conversation logging system

import Foundation
import SwiftUI
import Combine

class MessageStore: ObservableObject {
    @Published var messages: [ChatMessage] = []
    let llmManager = LLMManager()
    
    // BLUEPRINT: Memory integration for conversation persistence
    private let memoryIndex = ContextMemoryIndex.shared
    
    // BLUEPRINT: Vault writing integration for superjournal auto-save
    private let vaultWriter = VaultWriter.shared
    
    // PERSONA SYSTEM: PersonaRegistry dependency for persona-aware message handling
    @ObservedObject var personaRegistry: PersonaRegistry
    
    // Navigation events
    private let navigationSubject = PassthroughSubject<NavigationDirection, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // Auto-save state tracking
    private var currentUserMessage: String?
    
    // PERSONA SYSTEM: Current active persona tracking (super-persistent)
    @Published private var currentPersona: String = ""
    
    init(personaRegistry: PersonaRegistry) {
        self.personaRegistry = personaRegistry
        
        // BLUEPRINT: Load conversation history and current persona from vault on startup
        Task { @MainActor in
            loadCurrentPersona()
            loadConversationHistory()
        }
    }
    
    enum NavigationDirection {
        case up, down
        case smoothUp, smoothDown
    }
    
    var navigationPublisher: AnyPublisher<NavigationDirection, Never> {
        navigationSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Message Coordination
    
    /// Send user message with Boss-directed persona parsing
    func sendMessage(_ content: String) {
        print("🔴 PERSONA_DEBUG: sendMessage called with content: '\(content)'")
        
        // Parse first word to detect persona targeting
        let (targetPersona, messageContent) = parsePersonaFromMessage(content)
        print("🔴 PERSONA_DEBUG: parsePersonaFromMessage returned targetPersona: \(targetPersona ?? "nil"), messageContent: '\(messageContent)'")
        
        // If persona found, set as current active (synchronously since we're already on main thread)
        if let persona = targetPersona {
            print("🔴 PERSONA_DEBUG: Setting current persona to: \(persona)")
            setCurrentPersona(persona)
        } else {
            print("🔴 PERSONA_DEBUG: No persona found, keeping current persona: \(getCurrentPersona())")
        }
        
        // Add Boss's message first
        Task { @MainActor in
            addUserMessage(content) // Always save full original message
        }
        
        // Check for write commands first
        if let writeResult = VaultWriter.shared.processCommand(messageContent) {
            if writeResult == "CLEAR_SCROLLBACK_COMMAND" {
                // Handle scrollback clearing
                Task { @MainActor in
                    clearMessages()
                    addAIMessage("🧹 Scrollback cleared - conversation reset to zero messages", persona: getCurrentPersona())
                }
            } else {
                Task { @MainActor in
                    addAIMessage(writeResult, persona: getCurrentPersona())
                }
            }
        } else {
            // Route to current active persona with cleaned content
            let finalPersona = getCurrentPersona()
            print("🔴 PERSONA_DEBUG: Routing to LLM with persona: \(finalPersona), messageContent: '\(messageContent)'")
            coordinateLLMResponse(for: messageContent, persona: finalPersona)
        }
    }
    
    /// Get current persona for UI state
    func getCurrentPersona() -> String {
        print("🔴 PERSONA_DEBUG: getCurrentPersona() returning: \(currentPersona)")
        return currentPersona
    }
    
    /// Set current active persona (super-persistent)
    func setCurrentPersona(_ persona: String) {
        print("🔴 PERSONA_DEBUG: setCurrentPersona called with: \(persona)")
        
        guard personaRegistry.personaExists(persona) else {
            print("🔴 PERSONA_ERROR: Persona '\(persona)' does not exist in registry!")
            return
        }
        
        let oldPersona = currentPersona
        currentPersona = persona
        print("🔴 PERSONA_DEBUG: Persona changed from '\(oldPersona)' to '\(currentPersona)'")
        
        saveCurrentPersona()
    }
    
    /// Parse first word of message to detect persona targeting
    /// Returns (targetPersona, cleanedContent) - persona is nil if no match found
    private func parsePersonaFromMessage(_ content: String) -> (String?, String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.components(separatedBy: .whitespaces)
        
        guard let firstWord = words.first, !firstWord.isEmpty else {
            return (nil, content)
        }
        
        // Check if first word matches any persona (case-insensitive, strip punctuation)
        let cleanedFirstWord = firstWord.trimmingCharacters(in: .punctuationCharacters).lowercased()
        for personaId in personaRegistry.allPersonaIds() {
            if personaId.lowercased() == cleanedFirstWord {
                // Found persona match - remove first word from content
                let remainingWords = Array(words.dropFirst())
                let cleanedContent = remainingWords.joined(separator: " ")
                return (personaId, cleanedContent)
            }
        }
        
        // No persona match - return original content
        return (nil, content)
    }
    
    /// Clear all messages from conversation
    func clearMessages() {
        Task { @MainActor in
            messages.removeAll()
        }
    }
    
    // MARK: - Message State Management
    
    /// Add user message to conversation
    @MainActor
    private func addUserMessage(_ content: String) {
        let message = ChatMessage(content: content, author: "User", persona: nil) // Boss messages have no persona
        messages.append(message)
        saveConversationHistory()
        
        // BLUEPRINT: Track user message for superjournal auto-save
        currentUserMessage = content
    }
    
    /// Add AI message to conversation (for error handling and write commands)
    @MainActor
    private func addAIMessage(_ content: String, persona: String? = nil) {
        let message = ChatMessage(content: content, author: "AI", persona: persona)
        messages.append(message)
    }
    
    /// Create empty AI message for streaming updates
    @MainActor
    private func startAIMessage(persona: String? = nil) -> UUID {
        let message = ChatMessage(content: "", author: "AI", persona: persona)
        let messageId = message.id
        messages.append(message)
        return messageId
    }
    
    /// Update streaming message content while preserving metadata
    @MainActor
    private func updateStreamingMessage(id: UUID, content: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        
        let originalMessage = messages[index]
        let updatedMessage = ChatMessage(
            id: originalMessage.id,
            content: content,
            author: originalMessage.author,
            timestamp: originalMessage.timestamp,
            persona: originalMessage.persona
        )
        messages[index] = updatedMessage
        saveConversationHistory()
        
        // BLUEPRINT: Auto-save complete turn to superjournal when AI response is complete
        if originalMessage.author == "AI", let userMsg = currentUserMessage, !content.isEmpty {
            autoSaveCompleteTurn(userMessage: userMsg, aiResponse: content, persona: originalMessage.persona)
            currentUserMessage = nil // Reset for next turn
        }
    }
    
    // MARK: - LLM Coordination
    
    /// Handle LLM response coordination with persona applying machine compression
    private func coordinateLLMResponse(for userMessage: String, persona: String? = nil) {
        print("🔴 PERSONA_DEBUG: coordinateLLMResponse called with userMessage: '\(userMessage)', persona: \(persona ?? "nil")")
        
        Task {
            do {
                // Start empty AI message for response
                let messageId = await MainActor.run { startAIMessage(persona: persona) }
                print("🔴 PERSONA_DEBUG: Created AI message with ID: \(messageId), persona: \(persona ?? "nil")")
                
                // Get LLM response with persona applying machine compression
                print("🔴 PERSONA_DEBUG: Calling llmManager.sendMessage...")
                let personaResponse = try await llmManager.sendMessage(userMessage, persona: persona)
                print("🔴 PERSONA_DEBUG: LLM response received successfully")
                
                // Update with main response
                await MainActor.run { updateStreamingMessage(id: messageId, content: personaResponse.mainResponse) }
                
                // Save complete turn to superjournal (full audit trail)
                autoSaveCompleteTurn(userMessage: userMessage, aiResponse: personaResponse.mainResponse, persona: persona)
                
                // Save trimmed version to journal if available
                if let trimmedResponse = personaResponse.trimmedResponse {
                    await MainActor.run { saveTrimmedResponse(trimmedResponse) }
                }
                
            } catch {
                // Handle LLM errors gracefully
        print("🔴 PERSONA_ERROR: LLM error occurred: \(error)")
                await MainActor.run { handleLLMError(error, persona: persona) }
            }
        }
    }
    
    /// Save trimmed response to journal folder
    /// REAL-TIME INTEGRATION: New journal entries immediately available for next bundle
    @MainActor
    private func saveTrimmedResponse(_ trimmedContent: String) {
        Task {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
            dateFormatter.timeZone = TimeZone.current
            
            let timestamp = dateFormatter.string(from: Date())
            let filename = "Trim-\(timestamp).md"
            let journalPath = "\(VaultConfig.journalPath)/\(filename)"
            
            do {
                // Ensure journal directory exists
                try FileManager.default.createDirectory(atPath: VaultConfig.journalPath, 
                                                       withIntermediateDirectories: true, 
                                                       attributes: nil)
                
                // Write trimmed content atomically
                try trimmedContent.write(toFile: journalPath, atomically: true, encoding: .utf8)
                
                print("✅ Journal entry saved: \(filename)")
                
                // CRITICAL: No caching - OmniscientBundleBuilder will load fresh content
                // The wheel of Aether turns: this trim will be included in the next bundle
                
            } catch {
                print("❌ Failed to save trimmed response: \(error)")
            }
        }
    }
    
    /// Handle LLM service errors with user-friendly messages
    @MainActor
    private func handleLLMError(_ error: Error, persona: String? = nil) {
        print("🔴 PERSONA_ERROR: handleLLMError called with error: \(error), persona: \(persona ?? "nil")")
        
        let errorMessage: String
        
        if let llmError = error as? LLMServiceError {
            print("🔴 PERSONA_ERROR: Error is LLMServiceError: \(llmError)")
            switch llmError {
            case .missingAPIKey(let details):
                errorMessage = "Configuration error: \(details)"
            case .invalidResponse:
                errorMessage = "Unable to get response from AI service"
            case .httpError(let code):
                errorMessage = "Network error (code \(code)). Please try again."
            case .requestError(let underlyingError):
                errorMessage = "Request error: \(underlyingError.localizedDescription)"
            case .parsingError(let underlyingError):
                errorMessage = "Parsing error: \(underlyingError.localizedDescription)"
            }
        } else {
            print("🔴 PERSONA_ERROR: Error is NOT LLMServiceError, using generic message")
            errorMessage = "An unexpected error occurred. Please try again."
        }
        
        print("🔴 PERSONA_ERROR: Adding AI error message: '\(errorMessage)' with persona: \(persona ?? "nil")")
        addAIMessage(errorMessage, persona: persona)
    }
    
    // MARK: - Message Navigation
    
    /// Navigate to previous message (public interface)
    func navigateUp() {
        navigationSubject.send(.up)
    }
    
    /// Navigate to next message (public interface)
    func navigateDown() {
        navigationSubject.send(.down)
    }
    
    /// Smooth scroll up (public interface)
    func smoothScrollUp() {
        navigationSubject.send(.smoothUp)
    }
    
    /// Smooth scroll down (public interface)
    func smoothScrollDown() {
        navigationSubject.send(.smoothDown)
    }
    
    // MARK: - Memory Management
    
    /// Load current persona from vault (super-persistent across app restarts)
    @MainActor
    private func loadCurrentPersona() {
        let path = VaultConfig.currentPersonaPath
        if FileManager.default.fileExists(atPath: path) {
            do {
                let savedPersona = try String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                if !savedPersona.isEmpty && personaRegistry.personaExists(savedPersona) {
                    currentPersona = savedPersona
                    return
                }
            } catch {
                print("⚠️ Failed to load current persona: \(error)")
            }
        }
        
        // First-time default or fallback - use first available persona
        currentPersona = personaRegistry.allPersonaIds().first ?? "samara"
        saveCurrentPersona()
    }
    
    /// Save current persona to vault (super-persistent across app restarts)
    private func saveCurrentPersona() {
        let path = VaultConfig.currentPersonaPath
        do {
            try currentPersona.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("❌ Failed to save current persona: \(error)")
        }
    }
    
    /// Load conversation history from memory for scrollback display
    /// BLUEPRINT: Eventually loads full omniscient memory context
    /// CURRENT: Loads conversation state for UI display (separate from superjournal backup)
    @MainActor
    private func loadConversationHistory() {
        let savedMessages = memoryIndex.getConversationHistory()
        messages = savedMessages
    }
    
    /// Save conversation history to memory for scrollback persistence
    /// BLUEPRINT: Eventually triggers semantic consolidation when memory grows large
    /// CURRENT: Simple persistence after each message (separate from superjournal backup)
    private func saveConversationHistory() {
        memoryIndex.saveConversationHistory(messages)
    }
    
    // MARK: - Superjournal Auto-Save (Blueprint Implementation)
    // 🎉 ACHIEVEMENT: Agentic superjournal system - no manual intervention required
    
    /// Auto-save complete conversation turn to superjournal
    /// BLUEPRINT: "FullTurn-YYYY-MM-DD-HHMM.md — Complete uncompressed logs"
    /// ACHIEVEMENT: ✅ Fully automated - triggers when AI response completes
    /// INTEGRATION: Clean separation - MessageStore detects turns, VaultWriter handles files
    private func autoSaveCompleteTurn(userMessage: String, aiResponse: String, persona: String?) {
        Task {
            vaultWriter.autoSaveTurn(userMessage: userMessage, aiResponse: aiResponse, persona: persona ?? getCurrentPersona())
        }
    }
    
    
}

