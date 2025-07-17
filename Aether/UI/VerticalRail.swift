//
//  VerticalRail.swift
//  Aether
//
//  VS Code-style vertical activity rail for future integrations
//
//  BLUEPRINT SECTION: 🚨 UI - VerticalRail
//  =======================================
//
//  DESIGN PRINCIPLES:
//  - Minimal footprint: 48px fixed width matching VS Code
//  - Future extensibility: Icon-based integration points
//  - Visual consistency: Noir aesthetic matching app theme
//
//  RESPONSIBILITIES:
//  - Provide vertical rail container for future tool icons
//  - Maintain fixed 48px width regardless of window size
//  - Integrate cleanly with centered content layout
//

import SwiftUI

struct VerticalRail: View {
    private let tokens = DesignTokens.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Empty rail content for now
            // Future: Tool icons, integrations, settings
            Spacer()
        }
        .frame(width: 48)
        .frame(maxHeight: .infinity)
        .background(
            // Subtle dark background matching noir aesthetic
            Color.black.opacity(0.3)
        )
    }
}

#Preview {
    VerticalRail()
        .frame(height: 600)
        .background(Color.black)
}