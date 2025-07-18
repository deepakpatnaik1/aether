//
//  ContentView.swift
//  Aether
//
//  Super-top-level default SwiftUI container
//
//  ARCHITECTURE: 3-Pane Cognitive Layout with Glassmorphic Design
//  ============================================================
//
//  This component implements the core 3-pane architecture that mirrors cognitive processing:
//  - Pane 1: Main conversation thread (always visible)
//  - Pane 2: Quick aside for parallel processing (appears with 2+ panes)
//  - Pane 3: Additional context channel (appears with 3 panes)
//
//  GLASSMORPHIC SEPARATORS:
//  - Elegant vertical separators replace harsh borders
//  - Gradient transparency matching input bar design
//  - Positioned from input bar level to top with proper padding
//  - Subtle inner glow effect for premium aesthetic
//
//  WINDOW CYCLING:
//  - Ctrl+§ cycles: 1/3 → 2/3 → full → 2/3 → 1/3
//  - Smooth spring animations with proper easing
//  - Fixed screen-relative widths prevent stretching artifacts
//
//  DESIGN PRINCIPLES:
//  - Separation of Concerns: Pure UI composition, no business logic
//  - No Hardcoding: All styling via DesignTokens.json
//  - Modularity: Reusable PaneContainer and GlassmorphicSeparator components
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appCoordinator = AppCoordinator()
    
    var body: some View {
        // Blueprint 5.0: Fixed-width content centered in full-screen window
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Vertical rail on left (48px fixed width)
                VerticalRail()
                
                // Content area - let SwiftUI center it naturally
                ZStack(alignment: .bottom) {
                    // Main content area (full height with bottom padding for input bar)
                    ScrollbackView()
                        .padding(.bottom, 110) // Space for compact input bar
                    
                    // Input bar floating at bottom
                    InputBarView()
                }
                .frame(width: 592)
                .frame(maxWidth: .infinity)
            }
        }
        .environmentObject(appCoordinator.messageStore)
        .environmentObject(appCoordinator.focusManager)
        .environmentObject(appCoordinator.textMeasurementService)
        .environmentObject(appCoordinator.scrollCoordinator)
        .environmentObject(appCoordinator.personaRegistry)
        .background(
            Color(
                red: DesignTokens.shared.background.primary.red,
                green: DesignTokens.shared.background.primary.green,
                blue: DesignTokens.shared.background.primary.blue
            )
        )
        .onAppear {
            // Force full-screen window on launch - Blueprint 5.0
            if let window = NSApp.windows.first {
                if let screen = NSScreen.main {
                    window.setFrame(screen.visibleFrame, display: true, animate: false)
                }
            }
        }
        .focusable()
        .onKeyPress(keys: [.upArrow, .downArrow, .escape]) { keyPress in
            if keyPress.modifiers.contains(.option) && (keyPress.key == .upArrow || keyPress.key == .downArrow) {
                appCoordinator.keyboardHandler.handleArrowKeys(key: keyPress.key, modifiers: keyPress.modifiers)
                return .handled
            } else if keyPress.key == .escape {
                // Exit turn mode when escape is pressed
                appCoordinator.scrollCoordinator.exitTurnMode()
                return .handled
            }
            return .ignored
        }
        .onTapGesture {
            // Ensure the view regains focus when clicked anywhere
        }
    }
    
    // MARK: - Layout Calculations
    
    /// Calculate content width accounting for rail and minimum side padding
    /// This creates the Claude-like centered layout with clean space on sides
    private func calculateContentWidth(screenWidth: CGFloat) -> CGFloat {
        let railWidth: CGFloat = 48
        let minSidePadding: CGFloat = 40 // Minimum padding on each side
        let preferredWidth: CGFloat = DesignTokens.shared.layout.sizing["contentWidth"] ?? 600
        
        // Available width after rail
        let availableWidth = screenWidth - railWidth
        
        // Maximum content width ensuring uniform side padding
        let maxContentWidth = availableWidth - (minSidePadding * 2)
        
        // Use preferred width if it fits, otherwise use maximum available
        return min(preferredWidth, maxContentWidth)
    }
}

#Preview {
    ContentView()
}
