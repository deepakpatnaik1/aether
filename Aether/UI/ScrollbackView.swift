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
    @State private var scrollPosition = ScrollPosition()
    
    private let tokens = DesignTokens.shared
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(getVisibleMessages().enumerated()), id: \.element.message.id) { displayIndex, messageData in
                        let index = messageData.originalIndex
                        let message = messageData.message
                        let showAuthor = shouldShowAuthor(for: displayIndex, in: getVisibleMessages())
                        
                        VStack(alignment: .leading, spacing: 0) {
                            if showAuthor {
                                let displayName = getDisplayName(for: message)
                                authorLabelColoredBorder(displayName: displayName, message: message, displayIndex: displayIndex)
                            }
                            
                            MessageBubbleView(message: message, showAuthor: false)
                                .id("message-\(displayIndex)")
                                .background(
                                    scrollCoordinator.currentMessageIndex == index ? 
                                    MessageHighlight() : nil
                                )
                                .padding(.bottom, isLastMessageFromSpeaker(at: displayIndex, in: getVisibleMessages()) ? 4 : 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, tokens.layout.padding["scrollback"] ?? 20)
                .padding(.top, tokens.layout.padding["top"] ?? 20)
            }
            .scrollIndicators(.hidden)
            .focusable(true)
            .scrollTargetLayout()
            .onChange(of: scrollCoordinator.currentMessageIndex) { _, newIndex in
                if newIndex >= 0 && newIndex < messageStore.messages.count {
                    withAnimation(.easeInOut(duration: tokens.animations.messageNavigation.scrollDuration)) {
                        proxy.scrollTo("message-\(newIndex)", anchor: .top)
                    }
                }
            }
            .onChange(of: messageStore.messages.count) { oldCount, newCount in
                // When messages first load, scroll to bottom
                if oldCount == 0 && newCount > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        let visibleMessages = getVisibleMessages()
                        if !visibleMessages.isEmpty {
                            let targetDisplayIndex = visibleMessages.count - 1
                            proxy.scrollTo("message-\(targetDisplayIndex)", anchor: .top)
                        }
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
                    
                    // Use .bottom anchor for latest message to show it at bottom of view
                    let anchor: UnitPoint = (targetIndex == messageStore.messages.count - 1) ? .bottom : .top
                    
                    withAnimation(.easeInOut(duration: duration)) {
                        proxy.scrollTo("message-\(targetIndex)", anchor: anchor)
                    }
                    scrollCoordinator.clearAutoScrollRequest()
                }
            }
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
    
    // MARK: - Message Filtering Logic
    
    private struct MessageData {
        let message: ChatMessage
        let originalIndex: Int
    }
    
    private func getVisibleMessages() -> [MessageData] {
        let visibleIndices = scrollCoordinator.visibleMessageIndices
        
        return messageStore.messages.enumerated().compactMap { index, message in
            if visibleIndices.contains(index) {
                return MessageData(message: message, originalIndex: index)
            }
            return nil
        }
    }
    
    // MARK: - Speaker Grouping Logic
    
    private func shouldShowAuthor(for index: Int, in messages: [MessageData]) -> Bool {
        guard index < messages.count else { return false }
        
        if index == 0 { return true }
        
        let currentMessage = messages[index].message
        let previousMessage = messages[index - 1].message
        
        return currentMessage.author != previousMessage.author
    }
    
    private func isLastMessageFromSpeaker(at index: Int, in messages: [MessageData]) -> Bool {
        guard index < messages.count else { return true }
        
        if index == messages.count - 1 { return true }
        
        let currentMessage = messages[index].message
        let nextMessage = messages[index + 1].message
        
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
    
    // MARK: - Author Label Styling Approaches
    
    /// Approach 1: Minimal Badge Style - Clean rounded pill with subtle color accent
    @ViewBuilder
    private func authorLabelMinimalBadge(displayName: String, message: ChatMessage, displayIndex: Int) -> some View {
        let accentColor = getPersonaAccentColor(for: message)
        
        Text(displayName)
            .font(.custom(tokens.typography.bodyFont, size: tokens.elements.scrollback.authorFontSize))
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: tokens.elements.scrollback.authorLabel.minimalBadge.cornerRadius)
                    .fill(Color.white.opacity(tokens.elements.scrollback.authorLabel.minimalBadge.backgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: tokens.elements.scrollback.authorLabel.minimalBadge.cornerRadius)
                            .stroke(accentColor.opacity(0.3), lineWidth: 0.5)
                    )
            )
            .padding(.top, displayIndex == 0 ? 0 : 4)
            .padding(.bottom, 4)
            .padding(.leading, 8)
    }
    
    /// Approach 2: Typographic Only - Pure elegant text, no background
    @ViewBuilder
    private func authorLabelTypographicOnly(displayName: String, message: ChatMessage, displayIndex: Int) -> some View {
        let accentColor = getPersonaAccentColor(for: message)
        
        Text(displayName)
            .font(.custom(tokens.typography.bodyFont, size: tokens.elements.scrollback.authorFontSize))
            .foregroundColor(accentColor.opacity(0.8))
            .fontWeight(.medium)
            .padding(.top, displayIndex == 0 ? 0 : 4)
            .padding(.bottom, 4)
            .padding(.leading, 8)
    }
    
    /// Approach 3: Colored Border Accent - Thin left accent border per persona with horizontal separator line
    @ViewBuilder
    private func authorLabelColoredBorder(displayName: String, message: ChatMessage, displayIndex: Int) -> some View {
        let accentColor = getPersonaAccentColor(for: message)
        
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(accentColor)
                        .frame(width: tokens.elements.scrollback.authorLabel.coloredBorder.borderWidth)
                    
                    Text(displayName)
                        .font(.system(size: tokens.elements.scrollback.authorFontSize))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: tokens.elements.scrollback.authorLabel.coloredBorder.cornerRadius)
                                .fill(Color.white.opacity(tokens.elements.scrollback.authorLabel.coloredBorder.backgroundColor))
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: tokens.elements.scrollback.authorLabel.coloredBorder.cornerRadius))
                
                // Horizontal separator line with soft fade
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.0),
                                accentColor.opacity(0.3),
                                accentColor.opacity(0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .shadow(
                        color: accentColor.opacity(0.2),
                        radius: 0.5,
                        x: 0,
                        y: 0
                    )
                    .padding(.leading, 112)
            }
        }
        .padding(.top, displayIndex == 0 ? 0 : 4)
        .padding(.bottom, 4)
        .padding(.leading, 8)
    }
    
    /// Approach 4: Soft Color Fill - Gentle colored backgrounds
    @ViewBuilder
    private func authorLabelSoftColorFill(displayName: String, message: ChatMessage, displayIndex: Int) -> some View {
        let accentColor = getPersonaAccentColor(for: message)
        
        Text(displayName)
            .font(.custom(tokens.typography.bodyFont, size: tokens.elements.scrollback.authorFontSize))
            .foregroundColor(.white.opacity(0.95))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: tokens.elements.scrollback.authorLabel.softColorFill.cornerRadius)
                    .fill(accentColor.opacity(tokens.elements.scrollback.authorLabel.softColorFill.fillOpacity))
            )
            .padding(.top, displayIndex == 0 ? 0 : 4)
            .padding(.bottom, 4)
            .padding(.leading, 8)
    }
    
    /// Helper function to get persona-specific accent colors
    private func getPersonaAccentColor(for message: ChatMessage) -> Color {
        let personaKey: String
        
        if message.author == "User" {
            personaKey = "boss"
        } else if let personaId = message.persona {
            personaKey = personaId.lowercased()
        } else if message.author == "AI" {
            personaKey = "claude"
        } else {
            personaKey = "boss"
        }
        
        guard let colorData = tokens.elements.scrollback.authorLabel.minimalBadge.accentColors[personaKey] else {
            return Color.white
        }
        
        return Color(
            red: colorData.red,
            green: colorData.green,
            blue: colorData.blue
        )
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