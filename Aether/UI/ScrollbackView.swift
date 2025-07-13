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
    @EnvironmentObject var scrollCoordinator: ScrollCoordinator
    @State private var scrollProxy: ScrollViewProxy?
    
    private let tokens = DesignTokens.shared
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(messageStore.messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubbleView(message: message)
                            .id("message-\(index)")
                            .background(
                                scrollCoordinator.currentMessageIndex == index ? 
                                MessageHighlight() : nil
                            )
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