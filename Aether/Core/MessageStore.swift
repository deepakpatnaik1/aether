//
//  MessageStore.swift
//  Aether
//
//  Manages conversation state and coordinates AI responses for the user

import Foundation
import SwiftUI
import Combine

class MessageStore: ObservableObject {
    @Published var messages: [ChatMessage] = []
    let llmManager = LLMManager()
    
    // Preserves conversation history between app sessions
    private let memoryIndex = ContextMemoryIndex.shared
    
    // Automatically saves conversations for user review
    private let vaultWriter = VaultWriter.shared
    
    // Manages available AI personas for the user to interact with
    @ObservedObject var personaRegistry: PersonaRegistry
    
    // Navigation events
    private let navigationSubject = PassthroughSubject<NavigationDirection, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // Tracks current message for automatic saving
    private var currentUserMessage: String?
    
    // Remembers which AI persona the user is currently talking to
    @Published private var currentPersona: String = ""
    
    init(personaRegistry: PersonaRegistry) {
        self.personaRegistry = personaRegistry
        
        // Restores previous conversation and persona when app starts
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
    
    /// Processes user messages and generates AI responses
    func sendMessage(_ content: String) {
        // Check if user is addressing a specific AI persona
        let (targetPersona, messageContent) = parsePersonaFromMessage(content)
        
        // Switch to the specified persona if mentioned
        if let persona = targetPersona {
            Task { @MainActor in
                setCurrentPersona(persona)
            }
        }
        
        // Add user's message to conversation
        Task { @MainActor in
            addUserMessage(content)
        }
        
        // Handle special commands like file operations
        if let writeResult = VaultWriter.shared.processCommand(messageContent) {
            if writeResult == "CLEAR_SCROLLBACK_COMMAND" {
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
            // Send message to AI for response
            coordinateLLMResponse(for: messageContent, persona: getEffectivePersona())
        }
    }
    
    /// Returns which AI persona the user is currently talking to
    func getCurrentPersona() -> String {
        return currentPersona
    }
    
    /// Changes which AI persona the user is talking to
    func setCurrentPersona(_ persona: String) {
        guard personaRegistry.personaExists(persona) else {
            return
        }
        currentPersona = persona
        saveCurrentPersona()
        
        // Automatically use Claude Code API when talking to Claude persona
        if persona.lowercased() == "claude" {
            Task { @MainActor in
                switchToClaudeCodeModel()
            }
        }
    }
    
    /// Checks if user mentioned a persona name to switch to that AI
    private func parsePersonaFromMessage(_ content: String) -> (String?, String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.components(separatedBy: .whitespaces)
        
        guard let firstWord = words.first, !firstWord.isEmpty else {
            return (nil, content)
        }
        
        let cleanedFirstWord = firstWord.trimmingCharacters(in: .punctuationCharacters).lowercased()
        for personaId in personaRegistry.allPersonaIds() {
            if personaId.lowercased() == cleanedFirstWord {
                let remainingWords = Array(words.dropFirst())
                let cleanedContent = remainingWords.joined(separator: " ")
                return (personaId, cleanedContent)
            }
        }
        
        return (nil, content)
    }
    
    /// Clears all messages from the conversation view
    func clearMessages() {
        Task { @MainActor in
            messages.removeAll()
        }
    }
    
    // MARK: - Message State Management
    
    /// Adds user's message to the conversation
    @MainActor
    private func addUserMessage(_ content: String) {
        let message = ChatMessage(content: content, author: "User", persona: nil)
        messages.append(message)
        saveConversationHistory()
        
        currentUserMessage = content
    }
    
    /// Adds AI response to the conversation
    @MainActor
    private func addAIMessage(_ content: String, persona: String? = nil) {
        let message = ChatMessage(content: content, author: "AI", persona: persona)
        messages.append(message)
    }
    
    /// Creates placeholder for AI response while it's being generated
    @MainActor
    private func startAIMessage(persona: String? = nil) -> UUID {
        let message = ChatMessage(content: "", author: "AI", persona: persona)
        let messageId = message.id
        messages.append(message)
        return messageId
    }
    
    /// Updates AI message as response is being generated
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
        Task {
            do {
                // Start empty AI message for response
                let messageId = await MainActor.run { startAIMessage(persona: persona) }
                
                // Get LLM response with persona applying machine compression
                let personaResponse = try await llmManager.sendMessage(userMessage, persona: persona)
                
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
        let errorMessage: String
        
        if let llmError = error as? LLMServiceError {
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
            errorMessage = "An unexpected error occurred. Please try again."
        }
        
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
    
    /// Restores conversation when user reopens the app
    @MainActor
    private func loadConversationHistory() {
        let savedMessages = memoryIndex.getConversationHistory()
        messages = savedMessages
    }
    
    /// Saves conversation so it persists when user closes the app
    private func saveConversationHistory() {
        memoryIndex.saveConversationHistory(messages)
    }
    
    // MARK: - Conversation Archiving
    
    /// Automatically saves complete conversations for user review
    private func autoSaveCompleteTurn(userMessage: String, aiResponse: String, persona: String?) {
        Task {
            vaultWriter.autoSaveTurn(userMessage: userMessage, aiResponse: aiResponse, persona: persona ?? getCurrentPersona())
        }
    }
    
    // MARK: - Claude Integration
    
    /// Automatically switches to Claude Code API when user talks to Claude
    @MainActor
    private func switchToClaudeCodeModel() {
        let claudeCodeModelKey = "claude-code:claude-code-sonnet"
        llmManager.switchModel(to: claudeCodeModelKey)
    }
    
    /// Ensures Claude Code model only works with Claude persona
    func validatePersonaModelCompatibility() -> Bool {
        let currentModel = llmManager.getCurrentModel()
        
        if currentModel.contains("claude-code") && currentPersona.lowercased() != "claude" {
            Task { @MainActor in
                setCurrentPersona("claude")
            }
        }
        
        return true
    }
    
    /// Returns which persona should respond based on current model selection
    func getEffectivePersona() -> String {
        let currentModel = llmManager.getCurrentModel()
        
        if currentModel.contains("claude-code") {
            return "claude"
        }
        
        return currentPersona
    }
    
}

