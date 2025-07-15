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
    private var hasMigratedToSuperjournal = false
    private var hasMigratedHistoricalTrims = false
    
    // PERSONA SYSTEM: Current active persona tracking
    @Published private var currentPersona: String = "samara"
    
    init(personaRegistry: PersonaRegistry) {
        self.personaRegistry = personaRegistry
        
        // BLUEPRINT: Load conversation history from vault on startup
        // CURRENT: Simple conversation restoration
        Task { @MainActor in
            loadConversationHistory()
            migrateExistingConversationToSuperjournal()
            migrateHistoricalMessagesToTrims()
            // NOTE: fixSuperjournalTimestamps() removed - was destructive
            
            // DISABLED: One-time machine trim processing (was generating poor quality trims)
            // await VaultWriter.shared.processSuperJournalToTrims()
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
        // Parse first word to detect persona targeting
        let (targetPersona, messageContent) = parsePersonaFromMessage(content)
        
        // If persona found, set as current active
        if let persona = targetPersona {
            Task { @MainActor in
                setCurrentPersona(persona)
            }
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
                    addAIMessage("🧹 Scrollback cleared - conversation reset to zero messages", persona: "aether")
                }
            } else {
                Task { @MainActor in
                    addAIMessage(writeResult, persona: "aether") // Legacy responses become "aether"
                }
            }
        } else {
            // Route to current active persona with cleaned content
            coordinateLLMResponse(for: messageContent, persona: getCurrentPersona())
        }
    }
    
    /// Get current persona for UI state
    func getCurrentPersona() -> String {
        return currentPersona
    }
    
    /// Set current active persona
    func setCurrentPersona(_ persona: String) {
        guard personaRegistry.personaExists(persona) else {
            print("⚠️ Cannot set unknown persona: \(persona)")
            return
        }
        currentPersona = persona
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
            autoSaveCompleteTurn(userMessage: userMsg, aiResponse: content)
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
                autoSaveCompleteTurn(userMessage: userMessage, aiResponse: personaResponse.mainResponse)
                
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
    /// BREAKTHROUGH: Automatic semantic compression with every response
    @MainActor
    private func saveTrimmedResponse(_ trimmedContent: String) {
        Task {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            
            let timestamp = dateFormatter.string(from: Date())
            let filename = "Trim-\(timestamp).md"
            let journalPath = "\(VaultConfig.journalPath)/\(filename)"
            
            do {
                // Ensure journal directory exists
                try FileManager.default.createDirectory(atPath: VaultConfig.journalPath, 
                                                       withIntermediateDirectories: true, 
                                                       attributes: nil)
                
                // Write trimmed content
                try trimmedContent.write(toFile: journalPath, atomically: true, encoding: .utf8)
                print("📝 Saved machine trim: \(filename)")
                
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
        print("❌ LLM Error: \(error)")
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
    
    /// Load conversation history from vault
    /// BLUEPRINT: Eventually loads full omniscient memory context
    /// CURRENT: Simple conversation restoration on app startup
    @MainActor
    private func loadConversationHistory() {
        let savedMessages = memoryIndex.getConversationHistory()
        messages = savedMessages
        print("📖 Restored \(messages.count) messages from conversation history")
    }
    
    /// Save conversation history to vault
    /// BLUEPRINT: Eventually triggers semantic consolidation when memory grows large
    /// CURRENT: Simple persistence after each message
    private func saveConversationHistory() {
        memoryIndex.saveConversationHistory(messages)
    }
    
    // MARK: - Superjournal Auto-Save (Blueprint Implementation)
    // 🎉 ACHIEVEMENT: Agentic superjournal system - no manual intervention required
    
    /// Auto-save complete conversation turn to superjournal
    /// BLUEPRINT: "FullTurn-YYYY-MM-DD-HHMM.md — Complete uncompressed logs"
    /// ACHIEVEMENT: ✅ Fully automated - triggers when AI response completes
    /// INTEGRATION: Clean separation - MessageStore detects turns, VaultWriter handles files
    private func autoSaveCompleteTurn(userMessage: String, aiResponse: String) {
        Task {
            vaultWriter.autoSaveTurn(userMessage: userMessage, aiResponse: aiResponse)
        }
    }
    
    /// Migrate existing conversation to superjournal (one-time operation)
    /// BLUEPRINT: Backfill existing conversations for complete audit trail
    /// ACHIEVEMENT: ✅ Preserves "What is outer space?" and all historical conversations
    /// ENSURES: No conversation data lost during superjournal system implementation
    @MainActor
    private func migrateExistingConversationToSuperjournal() {
        guard !hasMigratedToSuperjournal && !messages.isEmpty else { return }
        
        Task {
            vaultWriter.migratePreviousTurns(messages)
        }
        
        hasMigratedToSuperjournal = true
    }
    
    /// Migrate existing conversation history to machine trims (one-time operation)
    /// BREAKTHROUGH: Backfill all historical messages with automatic semantic compression
    /// ENSURES: Complete conversation history gets machine compression treatment retroactively
    @MainActor
    private func migrateHistoricalMessagesToTrims() {
        guard !hasMigratedHistoricalTrims && !messages.isEmpty else { return }
        
        print("🔄 Starting historical message migration to machine trims...")
        
        Task {
            let conversationTurns = groupMessagesIntoTurns(messages)
            print("📊 Found \(conversationTurns.count) conversation turns to migrate")
            
            for turn in conversationTurns {
                await generateHistoricalTrim(userMessage: turn.userMessage, aiMessage: turn.aiMessage)
            }
            
            print("✅ Historical message migration completed - \(conversationTurns.count) trims generated")
        }
        
        hasMigratedHistoricalTrims = true
    }
    
    /// Group messages into conversation turns (User → AI pairs)
    private func groupMessagesIntoTurns(_ messages: [ChatMessage]) -> [ConversationTurn] {
        var turns: [ConversationTurn] = []
        var currentUserMessage: ChatMessage?
        
        for message in messages {
            if message.author == "User" {
                currentUserMessage = message
            } else if message.author == "AI", let userMsg = currentUserMessage {
                // Create turn pair
                let turn = ConversationTurn(
                    userMessage: userMsg,
                    aiMessage: message,
                    timestamp: message.timestamp
                )
                turns.append(turn)
                currentUserMessage = nil
            }
        }
        
        return turns
    }
    
    /// Generate historical trim for a conversation turn
    private func generateHistoricalTrim(userMessage: ChatMessage, aiMessage: ChatMessage) async {
        do {
            // Use LLMManager to generate trim (same as current system)
            let trimResponse = try await generateTrimForTurn(
                userContent: userMessage.content,
                aiContent: aiMessage.content,
                originalTimestamp: aiMessage.timestamp
            )
            
            // Save with original timestamp
            await MainActor.run { saveHistoricalTrim(trimResponse, originalTimestamp: aiMessage.timestamp) }
            
        } catch {
            print("❌ Failed to generate historical trim: \(error)")
        }
    }
    
    /// Generate trim for a specific turn using machine methodology
    private func generateTrimForTurn(userContent: String, aiContent: String, originalTimestamp: Date) async throws -> String {
        // Load machine compression methodology
        let compressionPath = "\(VaultConfig.vaultRoot)/playbook/tools/machine-trim.md"
        let compressionRules = try String(contentsOfFile: compressionPath, encoding: .utf8)
        
        // Build prompt for historical trim generation with proper speaker attribution
        let prompt = """
        HISTORICAL CONVERSATION TURN COMPRESSION:
        
        Apply machine compression to this conversation turn between Boss and Aether:
        
        BOSS MESSAGE:
        \(userContent)
        
        AETHER RESPONSE:
        \(aiContent)
        
        COMPRESSION METHODOLOGY:
        \(compressionRules)
        
        IMPORTANT: Use speaker labels "boss:" and "aether:" in the dialog section, not "user:" or "ai:".
        This is historical conversation between Boss and Aether before other personas joined.
        
        Generate only the compressed trim output - no additional explanation or formatting.
        """
        
        // Use LLMManager to process the trim
        return try await llmManager.sendMessage(prompt)
    }
    
    /// Save historical trim with original timestamp
    @MainActor
    private func saveHistoricalTrim(_ trimContent: String, originalTimestamp: Date) {
        Task {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            
            let timestamp = dateFormatter.string(from: originalTimestamp)
            let filename = "Trim-\(timestamp)-historical.md"
            let journalPath = "\(VaultConfig.journalPath)/\(filename)"
            
            do {
                // Ensure journal directory exists
                try FileManager.default.createDirectory(atPath: VaultConfig.journalPath, 
                                                       withIntermediateDirectories: true, 
                                                       attributes: nil)
                
                // Write historical trim
                try trimContent.write(toFile: journalPath, atomically: true, encoding: .utf8)
                print("📝 Saved historical trim: \(filename)")
                
            } catch {
                print("❌ Failed to save historical trim: \(error)")
            }
        }
    }
    // MARK: - Journal File Reprocessing
    
    /// Reprocess existing journal files using proper LLM dual-task compression
    /// PURPOSE: Fix the 19 broken journal files that were generated with programmatic compression
    func reprocessJournalFiles() async {
        print("🔄 Starting journal file reprocessing with LLM dual-task compression...")
        
        // Get all superjournal files
        let superjournalFiles = VaultWriter.shared.getSuperJournalFiles()
        print("📊 Found \(superjournalFiles.count) superjournal files to reprocess")
        
        for filename in superjournalFiles {
            do {
                // Parse superjournal file
                let superjournalPath = "\(VaultConfig.superJournalPath)/\(filename)"
                let content = try String(contentsOfFile: superjournalPath, encoding: .utf8)
                let (userMessage, aiResponse, persona) = parseSuperJournalFile(content)
                
                if !userMessage.isEmpty && !aiResponse.isEmpty {
                    // Use LLM dual-task system to get proper compression
                    let personaResponse = try await llmManager.sendMessage(userMessage, persona: persona)
                    
                    if let trimmedResponse = personaResponse.trimmedResponse {
                        // Save properly compressed version
                        let timestamp = extractTimestampFromFilename(filename)
                        VaultWriter.shared.saveMachineTrim(trimmedResponse, timestamp: timestamp)
                        print("✅ Reprocessed: \(filename)")
                    } else {
                        print("⚠️ No compressed response from LLM for: \(filename)")
                    }
                } else {
                    print("⚠️ Could not parse superjournal file: \(filename)")
                }
                
            } catch {
                print("❌ Failed to reprocess \(filename): \(error)")
            }
        }
        
        print("🎉 Journal file reprocessing complete!")
    }
    
    /// Parse superjournal file to extract user message, AI response, and persona
    private func parseSuperJournalFile(_ content: String) -> (userMessage: String, aiResponse: String, persona: String) {
        let lines = content.components(separatedBy: .newlines)
        
        var userMessage = ""
        var aiResponse = ""
        var persona = "Aether"
        
        var collectingUser = false
        var collectingAI = false
        
        for line in lines {
            if line.hasPrefix("## Boss") {
                collectingUser = true
                collectingAI = false
            } else if line.hasPrefix("## Aether") {
                collectingUser = false
                collectingAI = true
                persona = "Aether"
            } else if line.hasPrefix("## Samara") {
                collectingUser = false
                collectingAI = true
                persona = "Samara"
            } else if line.hasPrefix("## Vlad") {
                collectingUser = false
                collectingAI = true
                persona = "Vlad"
            } else if line.hasPrefix("## Vanessa") {
                collectingUser = false
                collectingAI = true
                persona = "Vanessa"
            } else if line.hasPrefix("---") || line.hasPrefix("*End of turn*") {
                collectingUser = false
                collectingAI = false
            } else if collectingUser && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !userMessage.isEmpty {
                    userMessage += "\n"
                }
                userMessage += line
            } else if collectingAI && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !aiResponse.isEmpty {
                    aiResponse += "\n"
                }
                aiResponse += line
            }
        }
        
        return (userMessage, aiResponse, persona)
    }
    
    /// Extract timestamp from superjournal filename for journal file creation
    private func extractTimestampFromFilename(_ filename: String) -> String {
        // Convert "FullTurn-20250715-090000.md" to "20250715-090000"
        let pattern = "FullTurn-(\\d{8}-\\d{6})\\.md"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: filename.utf16.count)
        
        if let match = regex.firstMatch(in: filename, options: [], range: range) {
            return (filename as NSString).substring(with: match.range(at: 1))
        }
        
        return ""
    }
}

/// Conversation turn data structure for migration
private struct ConversationTurn {
    let userMessage: ChatMessage
    let aiMessage: ChatMessage
    let timestamp: Date
}