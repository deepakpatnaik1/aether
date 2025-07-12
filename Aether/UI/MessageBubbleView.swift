//
//  MessageBubbleView.swift
//  Aether
//
//  Individual message rendering with clean styling
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(message.author)
                .font(.caption)
                .foregroundColor(.secondary)
            MarkdownRenderer(content: message.content)
                .padding()
        }
    }
}