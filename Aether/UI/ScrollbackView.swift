//
//  ScrollbackView.swift
//  Aether
//
//  Team-style unified message flow — Boss and personas on same side
//
//  IMPLEMENTATION: Unified Team Message Display
//  ==========================================
//
//  BLUEPRINT REQUIREMENTS:
//  - All team members in single vertical thread
//  - No left/right UI distinction between speakers
//  - All message bubbles aligned uniformly (left-aligned)
//  - Soft black background with gradients
//  - Consecutive messages from same speaker visually grouped
//
//  DESIGN PRINCIPLE:
//  "You and your personas are one team — not on opposite sides"

import SwiftUI

struct ScrollbackView: View {
    @State private var messages: [ChatMessage] = []
    
    private let tokens = DesignTokens.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: tokens.elements.scrollback["messageSpacing"] ?? 12) {
                ForEach(messages) { message in
                    MessageBubbleView(message: message)
                }
            }
            .padding(.horizontal, tokens.layout.padding["scrollback"] ?? 20)
            .padding(.top, tokens.layout.padding["top"] ?? 20)
        }
    }
}