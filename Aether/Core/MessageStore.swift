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
//  CURRENT SCOPE: Basic User ↔ AI chat interface
//  - Hardcoded "User" and "AI" authors (intentionally simple)
//  - Focus on reliability and clean separation
//  - Foundation for future persona system

import Foundation
import SwiftUI
import Combine

class MessageStore: ObservableObject {
    @Published var messages: [ChatMessage] = []
    private let llmManager = LLMManager()
    
    // Navigation events
    private let navigationSubject = PassthroughSubject<NavigationDirection, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    enum NavigationDirection {
        case up, down
        case smoothUp, smoothDown
    }
    
    var navigationPublisher: AnyPublisher<NavigationDirection, Never> {
        navigationSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Message Coordination
    
    /// Send user message and coordinate LLM response
    func sendMessage(_ content: String) {
        Task { @MainActor in
            addUserMessage(content)
        }
        coordinateLLMResponse(for: content)
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
        let message = ChatMessage(content: content, author: "User")
        messages.append(message)
    }
    
    /// Add AI message to conversation (for error handling)
    @MainActor
    private func addAIMessage(_ content: String) {
        let message = ChatMessage(content: content, author: "AI")
        messages.append(message)
    }
    
    /// Create empty AI message for streaming updates
    @MainActor
    private func startAIMessage() -> UUID {
        let message = ChatMessage(content: "", author: "AI")
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
            timestamp: originalMessage.timestamp
        )
        messages[index] = updatedMessage
    }
    
    // MARK: - LLM Coordination
    
    /// Handle LLM response coordination in background
    private func coordinateLLMResponse(for userMessage: String) {
        Task {
            do {
                // Start empty AI message for response
                let messageId = await startAIMessage()
                
                // Get LLM response (non-streaming for reliability)
                let response = try await llmManager.sendMessage(userMessage)
                
                // Update with complete response
                await updateStreamingMessage(id: messageId, content: response)
                
            } catch {
                // Handle LLM errors gracefully
                await handleLLMError(error)
            }
        }
    }
    
    /// Handle LLM service errors with user-friendly messages
    @MainActor
    private func handleLLMError(_ error: Error) {
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
        
        addAIMessage(errorMessage)
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
}