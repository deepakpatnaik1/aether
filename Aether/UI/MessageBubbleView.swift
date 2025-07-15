//
//  MessageBubbleView.swift
//  Aether
//
//  Individual message rendering with clean styling
//
//  BLUEPRINT SECTION: 🚨 UI - MessageBubbleView
//  =============================================
//
//  DESIGN PRINCIPLES:
//  - No Hardcoding: All typography from DesignTokens.json
//  - Separation of Concerns: Pure message rendering, no business logic
//  - Modularity: Clean styling with external design tokens

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    let showAuthor: Bool
    private let tokens = DesignTokens.shared
    
    // PERSONA SYSTEM: Access PersonaRegistry for display name lookup
    @EnvironmentObject var personaRegistry: PersonaRegistry
    
    init(message: ChatMessage, showAuthor: Bool = true) {
        self.message = message
        self.showAuthor = showAuthor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showAuthor {
                Text(displayName)
                    .font(.custom(tokens.typography.bodyFont, size: tokens.elements.scrollback.authorFontSize))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }
            
            MarkdownRenderer(content: message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }
    
    // MARK: - Persona Display Logic
    
    /// Returns appropriate display name for message sender
    /// Handles Boss messages, existing "Aether" messages, and new persona messages
    private var displayName: String {
        // Handle Boss messages (User author or no persona)
        if message.author == "User" || message.isFromBoss {
            return "Boss"
        }
        
        // Handle existing messages - "AI" author becomes "Aether" (origin story)
        if message.author == "AI" && message.persona == nil {
            return "Aether"
        }
        
        // Handle new persona messages - use PersonaRegistry for lookup
        if let personaId = message.persona {
            let displayName = personaRegistry.displayName(for: personaId)
            
            // If PersonaRegistry returns "Unknown", fall back to capitalized persona ID
            if displayName == "Unknown" {
                return personaId.capitalized
            }
            return displayName
        }
        
        // Fallback for unknown cases
        return "Unknown"
    }
}