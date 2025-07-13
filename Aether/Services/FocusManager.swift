//
//  FocusManager.swift
//  Aether
//
//  Centralized focus management service
//
//  BLUEPRINT SECTION: 🚨 Services - Focus Management
//  ================================================
//
//  DESIGN PRINCIPLES:
//  - Separation of Concerns: Focus logic isolated from UI components
//  - Single Responsibility: Manages only focus state and restoration
//  - Event-Driven: Uses publishers for decoupled communication
//
//  RESPONSIBILITIES:
//  - Track application focus state
//  - Coordinate input focus restoration
//  - Handle focus events from keyboard navigation
//  - Provide clean interface for focus management

import Foundation
import SwiftUI
import Combine

class FocusManager: ObservableObject {
    @Published private(set) var appIsActive: Bool = true
    @Published var shouldFocusInput: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupAppFocusMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Request input focus restoration
    func requestInputFocus() {
        if appIsActive {
            shouldFocusInput = true
        }
    }
    
    /// Clear focus request (called by UI when focus is achieved)
    func clearFocusRequest() {
        shouldFocusInput = false
    }
    
    /// Handle focus restoration after UI operations
    func restoreFocusAfterOperation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.requestInputFocus()
        }
    }
    
    /// Handle focus restoration after window operations
    func restoreFocusAfterWindowOperation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.requestInputFocus()
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupAppFocusMonitoring() {
        // Monitor app activation
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.appIsActive = true
                self?.requestInputFocus()
            }
            .store(in: &cancellables)
        
        // Monitor app deactivation
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                self?.appIsActive = false
                self?.clearFocusRequest()
            }
            .store(in: &cancellables)
    }
}