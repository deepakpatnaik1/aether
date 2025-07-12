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
    @StateObject private var threePaneManager = ThreePaneManager()
    @StateObject private var keyboardHandler: KeyboardHandler
    
    init() {
        let manager = ThreePaneManager()
        _threePaneManager = StateObject(wrappedValue: manager)
        _keyboardHandler = StateObject(wrappedValue: KeyboardHandler(threePaneManager: manager))
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Pane 1 - Always visible
                PaneContainer(
                    isActive: threePaneManager.activePaneIndex == 0,
                    paneIndex: 0,
                    threePaneManager: threePaneManager
                )
                .frame(width: threePaneManager.paneWidth)
                
                // Glassmorphic separator between Pane 1 and 2
                if threePaneManager.shouldShowPane2 {
                    GlassmorphicSeparator()
                }
                
                // Pane 2 - Visible when 2+ panes
                if threePaneManager.shouldShowPane2 {
                    PaneContainer(
                        isActive: threePaneManager.activePaneIndex == 1,
                        paneIndex: 1,
                        threePaneManager: threePaneManager
                    )
                    .frame(width: threePaneManager.paneWidth)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                }
                
                // Glassmorphic separator between Pane 2 and 3
                if threePaneManager.shouldShowPane3 {
                    GlassmorphicSeparator()
                }
                
                // Pane 3 - Visible when 3 panes
                if threePaneManager.shouldShowPane3 {
                    PaneContainer(
                        isActive: threePaneManager.activePaneIndex == 2,
                        paneIndex: 2,
                        threePaneManager: threePaneManager
                    )
                    .frame(width: threePaneManager.paneWidth)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                }
                
                Spacer(minLength: 0) // Absorb any remaining space
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            Color(
                red: DesignTokens.shared.background.primary.red,
                green: DesignTokens.shared.background.primary.green,
                blue: DesignTokens.shared.background.primary.blue
            )
        )
        .onAppear {
            threePaneManager.setupInitialWindowSize()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            threePaneManager.handleAppActivation()
        }
        .focusable()
        .onKeyPress(keys: [.init("§")]) { keyPress in
            if keyPress.modifiers.contains(.control) {
                keyboardHandler.handleKeyPress(key: "§", modifiers: keyPress.modifiers)
                return .handled
            }
            return .ignored
        }
    }
    
}

struct PaneContainer: View {
    let isActive: Bool
    let paneIndex: Int
    let threePaneManager: ThreePaneManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            VStack {
                // Debug header
                VStack(spacing: DesignTokens.shared.elements.panes.spacing) {
                    Text("Pane \(paneIndex + 1)")
                        .foregroundColor(.white.opacity(DesignTokens.shared.elements.panes.textOpacity))
                        .font(.custom(DesignTokens.shared.typography.bodyFont, size: 17))
                    
                    Text(isActive ? "Active" : "Inactive")
                        .foregroundColor(isActive ? .blue : .gray)
                        .font(.custom(DesignTokens.shared.typography.bodyFont, size: 12))
                    
                    // Debug info
                    VStack(alignment: .leading, spacing: DesignTokens.shared.elements.panes.debugSpacing) {
                        Text("Window: \(windowSizeText)")
                            .font(.custom(DesignTokens.shared.typography.bodyFont, size: 10))
                            .foregroundColor(.gray)
                        Text("Visible: \(threePaneManager.visiblePaneCount)")
                            .font(.custom(DesignTokens.shared.typography.bodyFont, size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, DesignTokens.shared.elements.panes.topPadding)
                
                Spacer()
            }
            
            // Input bar at bottom (only show in active pane)
            if isActive {
                InputBarView()
            }
        }
        .onTapGesture {
            threePaneManager.setActivePane(paneIndex)
        }
    }
    
    private var windowSizeText: String {
        switch threePaneManager.currentWindowSize {
        case .oneThird: return "1/3"
        case .twoThirds: return "2/3"
        case .full: return "Full"
        }
    }
}

// MARK: - Glassmorphic Separator Component
//
// IMPLEMENTATION: Elegant Vertical Pane Separators
// ===============================================
//
// Replaces harsh white borders with sophisticated glassmorphic design:
// - Gradient transparency (borderTop → borderBottom opacity)
// - Subtle inner glow effect matching input bar aesthetic  
// - Precise positioning from input bar level to screen top
// - All styling constants sourced from DesignTokens.json
//
// VISUAL DESIGN:
// - 1px width with gradient fill
// - Inner glow shadow for premium feel
// - Consistent padding matching input bar spacing
// - Seamlessly integrates with overall glassmorphic theme

struct GlassmorphicSeparator: View {
    private let tokens = DesignTokens.shared
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                // Vertical separator line with glassmorphic effect
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(tokens.glassmorphic.transparency.borderTop),
                                .white.opacity(tokens.glassmorphic.transparency.borderBottom)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: tokens.elements.separators.width)
                    .shadow(
                        color: .white.opacity(tokens.glassmorphic.shadows.innerGlow.opacity),
                        radius: tokens.elements.separators.glowRadius,
                        x: 0,
                        y: 0
                    ) // Subtle inner glow
                    .padding(.bottom, tokens.elements.separators.bottomPadding) // Match input bar padding from bottom
                    .padding(.top, tokens.elements.separators.topPadding) // Match input bar padding from top
            }
        }
        .frame(width: tokens.elements.separators.width)
    }
}

#Preview {
    ContentView()
}
