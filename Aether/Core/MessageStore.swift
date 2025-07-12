//
//  MessageStore.swift
//  Aether
//
//  Shared message state for ScrollbackView and InputBarView
//
//  IMPLEMENTATION: Observable Message Management
//  ===========================================
//
//  DESIGN PRINCIPLE: Single source of truth for conversation state
//  - Shared between ScrollbackView (display) and InputBarView (input)
//  - ObservableObject for automatic SwiftUI updates
//  - Thread-safe message appending for LLM responses
//
//  USAGE:
//  - InputBarView adds user message and LLM response
//  - ScrollbackView displays the message array
//  - Automatic UI updates via @Published

import Foundation
import SwiftUI

class MessageStore: ObservableObject {
    @Published var messages: [ChatMessage] = []
    private let llmManager = LLMManager()
    
    func sendMessage(_ content: String) {
        // Add user message immediately
        addUserMessage(content)
        
        // Handle LLM streaming in background
        Task {
            do {
                print("Sending message: '\(content)'")
                
                // Get complete response (non-streaming)
                let messageId = startStreamingMessage()
                
                let response = try await llmManager.sendMessage(content)
                await updateStreamingMessage(id: messageId, content: response)
                
                print("✅ LLM Streaming completed")
            } catch {
                print("❌ LLM Error: \(error)")
                print("❌ Error description: \(error.localizedDescription)")
                if let llmError = error as? LLMServiceError {
                    print("❌ LLM Service Error: \(llmError)")
                }
                // Add error message to scrollback
                addAIMessage("Sorry, I encountered an error: \(error.localizedDescription)", author: "System")
            }
        }
    }
    
    private func addUserMessage(_ content: String) {
        let message = ChatMessage(content: content, author: "User")
        DispatchQueue.main.async {
            self.messages.append(message)
        }
    }
    
    func addAIMessage(_ content: String, author: String = "AI") {
        let message = ChatMessage(content: content, author: author)
        DispatchQueue.main.async {
            self.messages.append(message)
        }
    }
    
    func startStreamingMessage(author: String = "AI") -> UUID {
        let message = ChatMessage(content: "", author: author)
        let messageId = message.id
        DispatchQueue.main.async {
            self.messages.append(message)
        }
        return messageId
    }
    
    @MainActor
    func updateStreamingMessage(id: UUID, content: String) {
        if let index = self.messages.firstIndex(where: { $0.id == id }) {
            let originalMessage = self.messages[index]
            // Create new message with updated content but preserve original ID, author, and timestamp
            let updatedMessage = ChatMessage(
                id: originalMessage.id, 
                content: content, 
                author: originalMessage.author, 
                timestamp: originalMessage.timestamp
            )
            self.messages[index] = updatedMessage
        }
    }
    
    func clearMessages() {
        DispatchQueue.main.async {
            self.messages.removeAll()
        }
    }
}