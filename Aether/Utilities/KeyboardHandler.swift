//
//  KeyboardHandler.swift
//  Aether
//
//  Event-driven keyboard shortcut coordination
//
//  BLUEPRINT SECTION: 🚨 Utilities - Keyboard Management
//  ====================================================
//
//  DESIGN PRINCIPLES:
//  - Separation of Concerns: Input detection only, no business logic
//  - Event-Driven: Publishes events rather than direct method calls
//  - Single Responsibility: Handles only keyboard input coordination
//
//  RESPONSIBILITIES:
//  - Detect keyboard input events
//  - Publish navigation and window events
//  - Coordinate with focus management
//  - Provide clean interface for keyboard shortcuts

import SwiftUI
import Combine

class KeyboardHandler: ObservableObject {
    
    // Event publishers for decoupled communication
    private let navigationSubject = PassthroughSubject<NavigationEvent, Never>()
    private let windowSubject = PassthroughSubject<WindowEvent, Never>()
    private let focusSubject = PassthroughSubject<FocusEvent, Never>()
    
    var navigationPublisher: AnyPublisher<NavigationEvent, Never> {
        navigationSubject.eraseToAnyPublisher()
    }
    
    var windowPublisher: AnyPublisher<WindowEvent, Never> {
        windowSubject.eraseToAnyPublisher()
    }
    
    var focusPublisher: AnyPublisher<FocusEvent, Never> {
        focusSubject.eraseToAnyPublisher()
    }
    
    init() {
        print("✅ Event-driven keyboard handler initialized")
    }
    
    // MARK: - Key Event Handling
    @MainActor
    func handleKeyPress(key: String, modifiers: EventModifiers) {
        // Window sizing removed - Blueprint 5.0 eliminates 3-pane architecture
        // Future: Add sidebar navigation shortcuts here
    }
    
    @MainActor
    func handleArrowKeys(key: KeyEquivalent, modifiers: EventModifiers) {
        guard modifiers.contains(.option) && (key == .upArrow || key == .downArrow) else { return }
        
        let direction: NavigationDirection = (key == .upArrow) ? .up : .down
        
        if modifiers.contains(.shift) {
            // Shift+Option+Arrow: Smooth scroll
            navigationSubject.send(.smoothScroll(direction))
        } else {
            // Option+Arrow: Message navigation
            navigationSubject.send(.navigate(direction))
        }
        
        // Request focus restoration after navigation
        focusSubject.send(.restoreAfterOperation)
    }
}

// MARK: - Event Types

enum NavigationEvent {
    case navigate(NavigationDirection)
    case smoothScroll(NavigationDirection)
}

enum NavigationDirection {
    case up, down
}

enum WindowEvent {
    // Window sizing removed - Blueprint 5.0 eliminates 3-pane architecture
    // Future: Add sidebar-related window events here
}

enum FocusEvent {
    case restoreAfterOperation
    case restoreAfterWindowOperation
}