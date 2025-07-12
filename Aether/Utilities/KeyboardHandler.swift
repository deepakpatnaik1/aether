//
//  KeyboardHandler.swift
//  Aether
//
//  Local keyboard shortcuts when app is active
//

import SwiftUI

class KeyboardHandler: ObservableObject {
    
    private weak var threePaneManager: ThreePaneManager?
    
    init(threePaneManager: ThreePaneManager) {
        self.threePaneManager = threePaneManager
        print("✅ Local keyboard handler initialized")
    }
    
    // MARK: - Key Event Handling
    @MainActor
    func handleKeyPress(key: String, modifiers: EventModifiers) {
        // Check for Ctrl+§ (section sign)
        if key == "§" && modifiers.contains(.control) {
            handleCtrlSectionPressed()
        }
    }
    
    @MainActor
    private func handleCtrlSectionPressed() {
        print("🎯 Ctrl+§ detected! Cycling window size...")
        
        // Cycle window size immediately
        threePaneManager?.cycleWindowSize()
        
        // Handle app activation (focus rightmost pane)
        threePaneManager?.handleAppActivation()
    }
}