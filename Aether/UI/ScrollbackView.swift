//
//  ScrollbackView.swift
//  Aether
//
//  Clean message display focused on UI presentation
//
//  BLUEPRINT SECTION: 🚨 UI - ScrollbackView
//  ========================================
//
//  DESIGN PRINCIPLES:
//  - Separation of Concerns: Pure UI component, business logic in services
//  - Single Responsibility: Handles only message display and scrolling presentation
//  - Service Integration: Uses ScrollCoordinator for scroll management
//
//  RESPONSIBILITIES:
//  - Render team-style unified message flow
//  - Handle scroll animations and positioning
//  - Coordinate with scroll service for navigation
//  - Provide clean message viewing experience

import SwiftUI

struct ScrollbackView: View {
    @EnvironmentObject var messageStore: MessageStore
    @EnvironmentObject var personaRegistry: PersonaRegistry
    @EnvironmentObject var scrollCoordinator: ScrollCoordinator
    @State private var scrollProxy: ScrollViewProxy?
    
    private let tokens = DesignTokens.shared
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(messageStore.messages.enumerated()), id: \.element.id) { index, message in
                        let showAuthor = shouldShowAuthor(for: index)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            if showAuthor {
                                Text(getDisplayName(for: message))
                                    .font(.custom(tokens.typography.bodyFont, size: tokens.elements.scrollback.authorFontSize))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.black.opacity(tokens.glassmorphic.transparency.inputBackground))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                .white.opacity(tokens.glassmorphic.transparency.borderTop),
                                                                .white.opacity(tokens.glassmorphic.transparency.borderBottom)
                                                            ],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        ),
                                                        lineWidth: 0.5
                                                    )
                                            )
                                            .shadow(
                                                color: .white.opacity(tokens.glassmorphic.shadows.innerGlow.opacity),
                                                radius: tokens.glassmorphic.shadows.innerGlow.radius / 2,
                                                x: 0,
                                                y: -1
                                            )
                                    )
                                    .padding(.top, index == 0 ? 0 : 4)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 8) // Align text inside container with message body text
                            }
                            
                            MessageBubbleView(message: message, showAuthor: false)
                                .id("message-\(index)")
                                .background(
                                    scrollCoordinator.currentMessageIndex == index ? 
                                    MessageHighlight() : nil
                                )
                                .padding(.bottom, isLastMessageFromSpeaker(at: index) ? 4 : 2)
                        }
                    }
                }
                .padding(.horizontal, tokens.layout.padding["scrollback"] ?? 20)
                .padding(.top, tokens.layout.padding["top"] ?? 20)
            }
            .scrollIndicators(.hidden)
            .onChange(of: scrollCoordinator.currentMessageIndex) { _, newIndex in
                if newIndex >= 0 && newIndex < messageStore.messages.count {
                    withAnimation(.easeInOut(duration: tokens.animations.messageNavigation.scrollDuration)) {
                        proxy.scrollTo("message-\(newIndex)", anchor: .top)
                    }
                }
            }
            .onReceive(messageStore.navigationPublisher) { direction in
                handleNavigation(direction)
            }
            .onAppear {
                scrollProxy = proxy
                scrollCoordinator.setScrollProxy(proxy)
            }
            .onReceive(scrollCoordinator.$shouldAutoScroll) { shouldScroll in
                if shouldScroll {
                    let targetIndex = scrollCoordinator.autoScrollTargetIndex
                    let duration = tokens.animations.messageNavigation.scrollDuration
                    withAnimation(.easeInOut(duration: duration)) {
                        proxy.scrollTo("message-\(targetIndex)", anchor: .top)
                    }
                    scrollCoordinator.clearAutoScrollRequest()
                }
            }
        }
        .onAppear {
            print("📱 ScrollbackView appeared with \(messageStore.messages.count) messages")
        }
    }
    
    // MARK: - Navigation Handling
    
    private func handleNavigation(_ direction: MessageStore.NavigationDirection) {
        switch direction {
        case .up:
            scrollCoordinator.navigateUp()
        case .down:
            scrollCoordinator.navigateDown()
        case .smoothUp:
            scrollCoordinator.smoothScrollUp()
        case .smoothDown:
            scrollCoordinator.smoothScrollDown()
        }
    }
    
    // MARK: - Speaker Grouping Logic
    
    private func shouldShowAuthor(for index: Int) -> Bool {
        guard index < messageStore.messages.count else { return false }
        
        if index == 0 { return true }
        
        let currentMessage = messageStore.messages[index]
        let previousMessage = messageStore.messages[index - 1]
        
        return currentMessage.author != previousMessage.author
    }
    
    private func isLastMessageFromSpeaker(at index: Int) -> Bool {
        guard index < messageStore.messages.count else { return true }
        
        if index == messageStore.messages.count - 1 { return true }
        
        let currentMessage = messageStore.messages[index]
        let nextMessage = messageStore.messages[index + 1]
        
        return currentMessage.author != nextMessage.author
    }
    
    // MARK: - Persona Display Logic
    
    /// Returns appropriate display name for message sender using PersonaRegistry
    private func getDisplayName(for message: ChatMessage) -> String {
        // Handle Boss messages (User author)
        if message.author == "User" {
            return "Boss"
        }
        
        // Handle existing AI messages - "AI" author with no persona becomes "Aether" (origin story)
        if message.author == "AI" && message.persona == nil {
            return "Aether"
        }
        
        // Handle new persona messages - use PersonaRegistry for lookup
        if let personaId = message.persona {
            let displayName = personaRegistry.displayName(for: personaId)
            
            // If PersonaRegistry returns "Unknown", fall back to capitalized persona ID
            if displayName == "Unknown" {
                return personaId.capitalized
            }
            return displayName
        }
        
        // Fallback for unknown cases
        return "Unknown"
    }
}

// MARK: - Message Highlight Component

private struct MessageHighlight: View {
    private let tokens = DesignTokens.shared
    
    var body: some View {
        RoundedRectangle(cornerRadius: tokens.elements.inputBar.cornerRadius)
            .fill(Color.white.opacity(tokens.elements.scrollback.highlight.fillOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: tokens.elements.inputBar.cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(tokens.glassmorphic.transparency.borderTop * tokens.elements.scrollback.highlight.borderOpacityMultiplier),
                                .white.opacity(tokens.glassmorphic.transparency.borderBottom * tokens.elements.scrollback.highlight.borderOpacityMultiplier)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: .white.opacity(tokens.glassmorphic.shadows.innerGlow.opacity * tokens.elements.scrollback.highlight.shadowOpacityMultiplier),
                radius: tokens.glassmorphic.shadows.innerGlow.radius,
                x: 0,
                y: 0
            )
    }
}