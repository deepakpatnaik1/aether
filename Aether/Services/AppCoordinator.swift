//
//  AppCoordinator.swift
//  Aether
//
//  Centralized application coordination and dependency management
//
//  BLUEPRINT SECTION: 🚨 Services - Application Coordination
//  ========================================================
//
//  DESIGN PRINCIPLES:
//  - Separation of Concerns: Coordinates services without containing business logic
//  - Dependency Injection: Manages service lifecycle and dependencies
//  - Event-Driven: Connects event-driven components
//
//  RESPONSIBILITIES:
//  - Create and manage service instances
//  - Wire up event-driven communication
//  - Provide clean dependency injection for UI
//  - Handle application lifecycle coordination

import Foundation
import SwiftUI
import Combine

@MainActor
class AppCoordinator: ObservableObject {
    // Core services
    let personaRegistry = PersonaRegistry()
    let messageStore: MessageStore
    let focusManager = FocusManager()
    let textMeasurementService = TextMeasurementService()
    let keyboardHandler = KeyboardHandler()
    
    // Derived services (depend on core services)
    private(set) var scrollCoordinator: ScrollCoordinator!
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize MessageStore with PersonaRegistry dependency
        messageStore = MessageStore(personaRegistry: personaRegistry)
        
        // PersonaRegistry integration removed - OmniscientBundleBuilder handles memory loading directly
        
        setupDerivedServices()
        wireEventHandling()
        setupObservableObjectForwarding()
    }
    
    // MARK: - Service Setup
    
    private func setupDerivedServices() {
        // Create services that depend on other services
        scrollCoordinator = ScrollCoordinator(messageStore: messageStore)
    }
    
    private func setupObservableObjectForwarding() {
        // Forward nested ObservableObject changes to trigger SwiftUI updates
        // ThreePaneManager removed - Blueprint 5.0 eliminates 3-pane architecture
    }
    
    private func wireEventHandling() {
        // Wire keyboard events to scroll coordinator
        keyboardHandler.navigationPublisher
            .sink { [weak self] event in
                self?.handleNavigationEvent(event)
            }
            .store(in: &cancellables)
        
        // Window event handling removed - Blueprint 5.0 eliminates 3-pane architecture
        // Future: Add sidebar-related window event handling here
        
        // Wire keyboard events to focus manager
        keyboardHandler.focusPublisher
            .sink { [weak self] event in
                self?.handleFocusEvent(event)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Event Handling
    
    private func handleNavigationEvent(_ event: NavigationEvent) {
        switch event {
        case .navigate(let direction):
            switch direction {
            case .up:
                scrollCoordinator.navigateUp()
            case .down:
                scrollCoordinator.navigateDown()
            }
        case .smoothScroll(let direction):
            switch direction {
            case .up:
                scrollCoordinator.smoothScrollUp()
            case .down:
                scrollCoordinator.smoothScrollDown()
            }
        }
    }
    
    // Window event handling removed - Blueprint 5.0 eliminates 3-pane architecture
    // Future: Add sidebar-related window event handling here
    
    private func handleFocusEvent(_ event: FocusEvent) {
        switch event {
        case .restoreAfterOperation:
            focusManager.restoreFocusAfterOperation()
        case .restoreAfterWindowOperation:
            focusManager.restoreFocusAfterWindowOperation()
        }
    }
}