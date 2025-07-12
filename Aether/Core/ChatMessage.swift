//
//  ChatMessage.swift
//  Aether
//
//  Core data model for conversation messages
//
//  IMPLEMENTATION: Unified Team Message Structure
//  =============================================
//
//  DESIGN PRINCIPLE: "Team journal, not chat interface"
//  - All team members (Boss + personas) on same side
//  - No left/right UI distinction between speakers
//  - Each message labeled with persona name only
//  - Consecutive messages from same speaker grouped
//
//  MESSAGE STRUCTURE:
//  - Unique identifier for message anchoring (#message-124)
//  - Content supports full markdown rendering
//  - Author attribution via persona name
//  - Timestamp for chronological ordering
//
//  USAGE:
//  - ScrollbackView displays message flow
//  - MessageBubbleView renders individual messages
//  - LLMManager creates new messages from responses

import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let author: String
    let timestamp: Date
    
    init(content: String, author: String) {
        self.id = UUID()
        self.content = content
        self.author = author
        self.timestamp = Date()
    }
}