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
    private let tokens = DesignTokens.shared
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(message.author)
                .font(.custom(tokens.typography.bodyFont, size: tokens.elements.scrollback.authorFontSize))
                .foregroundColor(.secondary)
            MarkdownRenderer(content: message.content)
                .padding()
        }
    }
}