//
//  ThreePaneManager.swift
//  Aether
//
//  Manages 3-pane architecture with proper context isolation/sharing
//
//  COGNITIVE ARCHITECTURE: Three-Channel Processing System
//  ======================================================
//
//  Implements the core 3-pane cognitive model:
//  - Main thread: Primary conversation flow with persistent context
//  - Quick asides: Parallel processing channels (3-4 turns max)
//  - Context sharing: All personas aware across all panes
//
//  WINDOW MANAGEMENT:
//  - Dynamic sizing: 1/3 → 2/3 → full → 2/3 → 1/3 cycle
//  - Fixed screen-relative positioning prevents UI artifacts
//  - Smooth spring animations with proper physics
//  - Automatic focus management (rightmost pane on activation)
//
//  PANE ORCHESTRATION:
//  - Visibility logic: Progressive pane revelation
//  - Active pane tracking with automatic switching
//  - Memory consolidation when aside panes close
//  - Bidirectional cycling with direction tracking
//
//  DESIGN PRINCIPLES:
//  - Pure business logic: No UI rendering concerns
//  - Design token integration: All constants externalized
//  - ObservableObject pattern: Reactive state management
//  - Single responsibility: Window and pane logic only
//

import SwiftUI
import Combine
import AppKit

@MainActor
class ThreePaneManager: ObservableObject {
    
    // MARK: - Window Size States
    enum WindowSize: CaseIterable {
        case oneThird
        case twoThirds
        case full
        
        var widthFraction: Double {
            let tokens = DesignTokens.shared.pane.windowSizes
            switch self {
            case .oneThird: return tokens.oneThird
            case .twoThirds: return tokens.twoThirds
            case .full: return tokens.full
            }
        }
        
        var visiblePaneCount: Int {
            switch self {
            case .oneThird: return 1
            case .twoThirds: return 2
            case .full: return 3
            }
        }
    }
    
    // MARK: - Published Properties
    @Published var currentWindowSize: WindowSize = .oneThird
    @Published var activePaneIndex: Int = 0 // 0, 1, or 2
    @Published var openPanes: [Bool] = [true, false, false] // Which panes are open
    
    // MARK: - Private Properties
    private var cycleDirection: Int = 1 // 1 for forward, -1 for backward
    
    // MARK: - Computed Properties
    var visiblePaneCount: Int {
        currentWindowSize.visiblePaneCount
    }
    
    var shouldShowPane2: Bool {
        visiblePaneCount >= 2
    }
    
    var shouldShowPane3: Bool {
        visiblePaneCount >= 3
    }
    
    var paneWidth: CGFloat {
        guard let screen = NSScreen.main else { 
            return DesignTokens.shared.pane.fallbackWidth 
        }
        return screen.visibleFrame.width * DesignTokens.shared.pane.widthFraction
    }
    
    // MARK: - Window Sizing Cycle
    func cycleWindowSize() {
        let allCases = WindowSize.allCases
        let currentIndex = allCases.firstIndex(of: currentWindowSize) ?? 0
        
        let nextIndex: Int
        if cycleDirection == 1 {
            // Forward cycle: 1/3 → 2/3 → full
            if currentIndex < allCases.count - 1 {
                nextIndex = currentIndex + 1
            } else {
                // At full, reverse direction
                cycleDirection = -1
                nextIndex = currentIndex - 1
            }
        } else {
            // Backward cycle: full → 2/3 → 1/3
            if currentIndex > 0 {
                nextIndex = currentIndex - 1
            } else {
                // At 1/3, reverse direction
                cycleDirection = 1
                nextIndex = currentIndex + 1
            }
        }
        
        // Defer updates to avoid publishing during view update
        DispatchQueue.main.async {
            let tokens = DesignTokens.shared.animations.paneTransition
            
            // Update pane visibility and window size together
            withAnimation(.spring(response: tokens.response, dampingFraction: tokens.dampingFraction, blendDuration: tokens.blendDuration)) {
                self.currentWindowSize = allCases[nextIndex]
                self.updatePaneVisibility()
                self.resizeWindow()
            }
            
            // Ensure app stays focused during pane transitions
            self.maintainAppFocus()
        }
    }
    
    // MARK: - Window Management
    private func resizeWindow() {
        guard let screen = NSScreen.main else { return }
        guard let window = NSApp.windows.first else { return }
        
        let screenFrame = screen.visibleFrame
        let targetWidth: CGFloat
        
        // Calculate target width based on current window size
        let paneWidthFraction = DesignTokens.shared.pane.widthFraction
        switch currentWindowSize {
        case .oneThird:
            targetWidth = screenFrame.width * paneWidthFraction
        case .twoThirds:
            targetWidth = screenFrame.width * (paneWidthFraction * 2.0)
        case .full:
            targetWidth = screenFrame.width * 1.0
        }
        
        let windowHeight = screenFrame.height // Full screen height
        
        // Position window on left side of screen
        let newFrame = NSRect(
            x: screenFrame.minX,
            y: screenFrame.minY,
            width: targetWidth,
            height: windowHeight
        )
        
        window.setFrame(newFrame, display: true, animate: true)
        
        // Ensure window maintains focus after resize to prevent keyboard shortcut loss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    // MARK: - Focus Management
    //
    // FOCUS BUG FIX: Window Resize Focus Loss Prevention
    // ================================================
    //
    // PROBLEM: During pane transitions, window.setFrame() can cause the app to lose focus,
    // making keyboard shortcuts (Ctrl+§) stop working until user clicks back into the app.
    //
    // SOLUTION: Dual-layer focus restoration:
    // 1. maintainAppFocus() - Ensures app stays active during transitions
    // 2. window.makeKeyAndOrderFront() - Ensures window retains key status after resize
    //
    // TIMING: Small delays prevent focus commands from being ignored during animation
    
    private func maintainAppFocus() {
        // Ensure the app stays active and focused during transitions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // MARK: - Pane Management
    private func updatePaneVisibility() {
        // Main pane (0) is always open
        openPanes[0] = true
        
        // Pane 1 opens when we have 2+ visible panes
        openPanes[1] = visiblePaneCount >= 2
        
        // Pane 2 opens when we have 3 visible panes
        openPanes[2] = visiblePaneCount >= 3
        
        // Set active pane to rightmost visible pane
        activePaneIndex = visiblePaneCount - 1
    }
    
    func setActivePane(_ index: Int) {
        guard index >= 0 && index < visiblePaneCount else { return }
        activePaneIndex = index
    }
    
    // MARK: - App Lifecycle
    func handleAppActivation() {
        DispatchQueue.main.async {
            // Set focus to rightmost pane when app becomes active
            self.setActivePane(self.visiblePaneCount - 1)
            // Ensure window is properly sized on activation
            self.resizeWindow()
        }
    }
    
    // MARK: - Initial Setup
    func setupInitialWindowSize() {
        // Set initial window size immediately on app launch
        resizeWindow()
    }
}