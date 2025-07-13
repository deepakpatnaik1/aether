//
//  ChatMessage.swift
//  Aether
//
//  Core data model for unified team conversation messages
//
//  BLUEPRINT SECTION: 🚨 UI - ScrollbackView, MessageBubbleView
//  ===========================================================
//
//  DESIGN PRINCIPLE: "Team journal, not chat interface"
//  - All 5 team members (Boss + Vanessa + Gunnar + Vlad + Samara + Claude) unified display
//  - No left/right UI distinction between speakers - everyone on same side
//  - Each message labeled with persona name only (personas add their own emojis)
//  - Consecutive messages from same speaker visually grouped
//
//  SEPARATION OF CONCERNS:
//  - Pure data model - no business logic
//  - Message rendering handled by MessageBubbleView
//  - Message flow management handled by MessageStore
//  - LLM interactions handled by Services layer
//
//  MESSAGE STRUCTURE:
//  - Unique identifier for message anchoring and streaming updates
//  - Content supports full markdown rendering (handled by MarkdownRenderer)
//  - Author attribution via persona name (resolved by PersonaRegistry)
//  - Timestamp for chronological ordering
//
//  STREAMING SUPPORT:
//  - UUID preservation required for real-time message updates
//  - Two-phase creation: initial empty message + streaming content updates
//  - MessageStore coordinates streaming lifecycle

import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let author: String
    let timestamp: Date
    
    // CREATION INITIALIZER: New message from user input or LLM start
    // Used by: MessageStore.addUserMessage(), MessageStore.startStreamingMessage()
    init(content: String, author: String) {
        self.id = UUID()
        self.content = content
        self.author = author
        self.timestamp = Date()
    }
    
    // UPDATE INITIALIZER: Streaming content updates with UUID preservation
    // Used by: MessageStore.updateStreamingMessage() for real-time LLM responses
    // CRITICAL: Preserves original ID, author, and timestamp during content updates
    init(id: UUID, content: String, author: String, timestamp: Date) {
        self.id = id
        self.content = content
        self.author = author
        self.timestamp = timestamp
    }
}