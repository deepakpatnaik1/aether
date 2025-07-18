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
    
    // Turn-based navigation
    @Published var currentTurnIndex: Int = -1
    @Published var isInTurnMode: Bool = false
    @Published var visibleMessageIndices: Set<Int> = Set()
    private var conversationTurns: [(bossIndex: Int, personaIndex: Int)] = []
    
    private let messageStore: MessageStore
    private var cancellables = Set<AnyCancellable>()
    private var scrollProxy: ScrollViewProxy?
    
    init(messageStore: MessageStore) {
        self.messageStore = messageStore
        
        // Initialize visible indices to show all messages
        visibleMessageIndices = Set(0..<messageStore.messages.count)
        
        setupMessageMonitoring()
    }
    
    func setScrollProxy(_ proxy: ScrollViewProxy) {
        self.scrollProxy = proxy
    }
    
    // MARK: - Navigation Interface
    
    func navigateUp() {
        guard !conversationTurns.isEmpty else { return }
        
        DispatchQueue.main.async {
            // Enter turn mode if not already in it
            if !self.isInTurnMode {
                self.isInTurnMode = true
                self.currentTurnIndex = self.conversationTurns.count - 1 // Start with latest turn
            } else {
                // Navigate to previous turn
                if self.currentTurnIndex > 0 {
                    self.currentTurnIndex -= 1
                }
            }
            
            // Update visible indices in next run loop to avoid publishing warnings
            DispatchQueue.main.async {
                self.updateVisibleIndices()
            }
        }
    }
    
    func navigateDown() {
        guard !conversationTurns.isEmpty else { return }
        
        DispatchQueue.main.async {
            // Enter turn mode if not already in it
            if !self.isInTurnMode {
                self.isInTurnMode = true
                self.currentTurnIndex = 0 // Start with earliest turn
            } else {
                // Navigate to next turn
                if self.currentTurnIndex < self.conversationTurns.count - 1 {
                    self.currentTurnIndex += 1
                }
            }
            
            // Update visible indices in next run loop to avoid publishing warnings
            DispatchQueue.main.async {
                self.updateVisibleIndices()
            }
        }
    }
    
    func smoothScrollUp() {
        performSmoothScroll(direction: .up)
    }
    
    func smoothScrollDown() {
        performSmoothScroll(direction: .down)
    }
    
    // MARK: - Turn Mode Interface
    
    func exitTurnMode() {
        DispatchQueue.main.async {
            self.isInTurnMode = false
            self.currentTurnIndex = -1
            self.currentMessageIndex = -1
            
            // Update visible indices in next run loop to avoid publishing warnings
            DispatchQueue.main.async {
                self.updateVisibleIndices()
                
                // Auto-scroll to latest message when exiting turn mode
                let latestIndex = self.messageStore.messages.count - 1
                self.autoScrollTargetIndex = latestIndex
                self.shouldAutoScroll = true
            }
        }
    }
    
    private func updateVisibleIndices() {
        let messageCount = messageStore.messages.count
        if isInTurnMode && currentTurnIndex >= 0 && currentTurnIndex < conversationTurns.count {
            let turn = conversationTurns[currentTurnIndex]
            visibleMessageIndices = Set([turn.bossIndex, turn.personaIndex])
        } else {
            // Show all indices if not in turn mode
            visibleMessageIndices = Set(0..<messageCount)
        }
    }
    
    // MARK: - Auto-scroll Interface
    
    func scrollToLatestMessage() {
        guard !messageStore.messages.isEmpty else { return }
        
        let latestIndex = messageStore.messages.count - 1
        DispatchQueue.main.async {
            self.autoScrollTargetIndex = latestIndex
            self.shouldAutoScroll = true
            self.currentMessageIndex = -1
        }
    }
    
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
            .sink { [weak self] messages in
                self?.handleMessageUpdate(messages)
            }
            .store(in: &cancellables)
    }
    
    private func handleMessageUpdate(_ messages: [ChatMessage]) {
        guard !messages.isEmpty else { 
            // If messages are empty, ensure visible indices are also empty
            DispatchQueue.main.async {
                self.visibleMessageIndices = Set()
            }
            return 
        }
        
        // Update conversation turns
        buildConversationTurns(from: messages)
        
        // Update visible indices after rebuilding turns
        DispatchQueue.main.async {
            self.updateVisibleIndices()
            
            // Auto-scroll to latest message whenever messages change (only if not in turn mode)
            if !self.isInTurnMode {
                let latestIndex = messages.count - 1
                DispatchQueue.main.async {
                    self.autoScrollTargetIndex = latestIndex
                    self.shouldAutoScroll = true
                    self.currentMessageIndex = -1 // Reset navigation state
                }
            }
        }
    }
    
    // MARK: - Turn Detection Logic
    
    private func buildConversationTurns(from messages: [ChatMessage]) {
        var turns: [(bossIndex: Int, personaIndex: Int)] = []
        
        for i in 0..<messages.count - 1 {
            let currentMessage = messages[i]
            let nextMessage = messages[i + 1]
            
            // Look for Boss (User) → Persona (AI) pairs
            if currentMessage.author == "User" && nextMessage.author == "AI" {
                turns.append((bossIndex: i, personaIndex: i + 1))
            }
        }
        
        conversationTurns = turns
    }
    
    private func performSmoothScroll(direction: SmoothScrollDirection) {
        let messageCount = messageStore.messages.count
        guard messageCount > 0 else { return }
        
        // Initialize smooth scroll index if needed
        if smoothScrollIndex == -1 {
            DispatchQueue.main.async {
                self.smoothScrollIndex = max(0, self.currentMessageIndex >= 0 ? self.currentMessageIndex : messageCount - 1)
            }
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