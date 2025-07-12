//
//  MarkdownRenderer.swift
//  Aether
//
//  Rich markdown rendering for scrollback
//
//  IMPLEMENTATION: Blueprint Markdown Support
//  =========================================
//
//  BLUEPRINT REQUIREMENTS:
//  - Handles headers, bullet points, emphasis, inline code
//  - Syntax highlighting for code blocks
//  - Link auto-detection with project-aware linking
//  - Quote formatting (>) with visual indentation
//  - Content-type styling for tasks, definitions, system messages
//
//  USAGE:
//  - MessageBubbleView uses this for rich text rendering
//  - No persona-based coloring (personas provide their own visual identity)

import SwiftUI

struct MarkdownRenderer: View {
    let content: String
    private let tokens = DesignTokens.shared
    
    var body: some View {
        Text(.init(content))
            .font(.custom(tokens.typography.bodyFont, size: 14))
            .foregroundColor(.primary)
            .textSelection(.enabled)
    }
}