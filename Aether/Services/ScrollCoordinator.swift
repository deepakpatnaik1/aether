//
//  ScrollCoordinator.swift
//  Aether
//
//  Centralized scroll management and navigation service
//
//  BLUEPRINT SECTION: 🚨 Services - Scroll Management
//  =================================================
//
//  DESIGN PRINCIPLES:
//  - Separation of Concerns: Scroll logic isolated from UI components
//  - Single Responsibility: Manages only scroll behavior and navigation
//  - Event-Driven: Uses publishers for decoupled communication
//
//  RESPONSIBILITIES:
//  - Handle message navigation events
//  - Coordinate auto-scroll behavior
//  - Manage scroll state and positioning
//  - Provide clean interface for scroll operations

import Foundation
import SwiftUI
import Combine

class ScrollCoordinator: ObservableObject {
    @Published var currentMessageIndex: Int = -1
    @Published var smoothScrollIndex: Int = -1
    @Published var shouldAutoScroll: Bool = false
    @Published var autoScrollTargetIndex: Int = 0
    
    private let messageStore: MessageStore
    private var cancellables = Set<AnyCancellable>()
    private var scrollProxy: ScrollViewProxy?
    
    init(messageStore: MessageStore) {
        self.messageStore = messageStore
        setupMessageMonitoring()
    }
    
    func setScrollProxy(_ proxy: ScrollViewProxy) {
        self.scrollProxy = proxy
    }
    
    // MARK: - Navigation Interface
    
    func navigateUp() {
        let messageCount = messageStore.messages.count
        guard messageCount > 0 else { return }
        
        DispatchQueue.main.async {
            if self.currentMessageIndex <= 0 {
                self.currentMessageIndex = 0
            } else {
                self.currentMessageIndex -= 1
            }
        }
    }
    
    func navigateDown() {
        let messageCount = messageStore.messages.count
        guard messageCount > 0 else { return }
        
        DispatchQueue.main.async {
            if self.currentMessageIndex >= messageCount - 1 {
                self.currentMessageIndex = messageCount - 1
            } else if self.currentMessageIndex == -1 {
                self.currentMessageIndex = 0
            } else {
                self.currentMessageIndex += 1
            }
        }
    }
    
    func smoothScrollUp() {
        performSmoothScroll(direction: .up)
    }
    
    func smoothScrollDown() {
        performSmoothScroll(direction: .down)
    }
    
    // MARK: - Auto-scroll Interface
    
    func requestAutoScrollToUserQuestion() {
        let messageCount = messageStore.messages.count
        guard messageCount >= 2 else { return }
        
        let userMessageIndex = messageCount - 2
        let userMessage = messageStore.messages[userMessageIndex]
        
        guard userMessage.author == "User" else { return }
        
        DispatchQueue.main.async {
            self.autoScrollTargetIndex = userMessageIndex
            self.shouldAutoScroll = true
            
            // Reset navigation state
            self.smoothScrollIndex = userMessageIndex
            self.currentMessageIndex = -1
        }
    }
    
    func clearAutoScrollRequest() {
        DispatchQueue.main.async {
            self.shouldAutoScroll = false
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupMessageMonitoring() {
        // Monitor message changes for auto-scroll triggers
        messageStore.$messages
            .dropFirst() // Skip initial empty state
            .sink { [weak self] messages in
                self?.handleMessageUpdate(messages)
            }
            .store(in: &cancellables)
    }
    
    private func handleMessageUpdate(_ messages: [ChatMessage]) {
        guard !messages.isEmpty && messages.count >= 2 else { return }
        
        let lastMessage = messages.last!
        if lastMessage.author == "AI" && !lastMessage.content.isEmpty {
            // Check if this is a new AI response (not an update to existing)
            if messages.count > 1 {
                let previousMessage = messages[messages.count - 2]
                if previousMessage.author == "User" {
                    // New AI response completed - trigger auto-scroll
                    requestAutoScrollToUserQuestion()
                }
            }
        }
    }
    
    private func performSmoothScroll(direction: SmoothScrollDirection) {
        let messageCount = messageStore.messages.count
        guard messageCount > 0 else { return }
        
        // Initialize smooth scroll index if needed
        if smoothScrollIndex == -1 {
            smoothScrollIndex = max(0, currentMessageIndex >= 0 ? currentMessageIndex : messageCount - 1)
        }
        
        let scrollStep = 2 // Approximately 2 messages = ~100pt
        
        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = max(0, smoothScrollIndex - scrollStep)
        case .down:
            targetIndex = min(messageCount - 1, smoothScrollIndex + scrollStep)
        }
        
        DispatchQueue.main.async {
            self.smoothScrollIndex = targetIndex
            
            // Trigger smooth scroll
            self.autoScrollTargetIndex = targetIndex
            self.shouldAutoScroll = true
        }
    }
    
    private enum SmoothScrollDirection {
        case up, down
    }
}