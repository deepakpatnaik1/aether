//
//  InputBarView.swift
//  Aether
//
//  Glassmorphic input bar with auto-focus and spring physics
//

import SwiftUI
import AppKit

struct InputBarView: View {
    @State private var inputText: String = ""
    @State private var textHeight: CGFloat
    @State private var debounceTimer: Timer?
    @FocusState private var isInputFocused: Bool
    
    private let tokens = DesignTokens.shared
    
    init() {
        _textHeight = State(initialValue: tokens.elements.inputBar.defaultTextHeight)
    }
    
    var body: some View {
        // Input Container - Glassmorphic design
        VStack(spacing: 0) {
            // Expandable text area with placeholder
            ZStack(alignment: .topLeading) {
                // Placeholder text
                if inputText.isEmpty {
                    Text(tokens.elements.inputBar.placeholderText)
                        .font(.custom(tokens.typography.bodyFont, size: tokens.elements.inputBar.fontSize))
                        .foregroundColor(.white.opacity(tokens.glassmorphic.transparency.placeholder))
                        .padding(.horizontal, tokens.elements.inputBar.placeholderPaddingHorizontal)
                        .padding(.top, tokens.elements.inputBar.topPadding)
                }
                
                TextEditor(text: $inputText)
                    .font(.custom(tokens.typography.bodyFont, size: 12))
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .scrollContentBackground(.hidden)
                    .frame(height: textHeight)
                    .padding(.horizontal, tokens.elements.inputBar.textPadding)
                    .padding(.top, tokens.elements.inputBar.topPadding)
            }
            .onChange(of: inputText) { oldValue, newValue in
                // Calculate dynamic height based on text content with debouncing
                debouncedUpdateTextHeight(for: newValue)
            }
            
            // Bottom controls row - seamlessly connected
            HStack(spacing: tokens.elements.inputBar.controlsSpacing) {
                // Plus button
                Button(action: {
                    // TODO: Add attachment functionality
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(tokens.glassmorphic.transparency.controls))
                        .frame(width: tokens.elements.buttons.plusSize, height: tokens.elements.buttons.plusSize)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Send button (appears when text is entered)
                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: {
                        sendMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: tokens.elements.buttons.sendSize, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Green glowing indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: tokens.elements.buttons.indicatorSize, height: tokens.elements.buttons.indicatorSize)
                    .shadow(color: .green, radius: tokens.glassmorphic.shadows.greenGlow.radius1, x: 0, y: 0)
                    .shadow(color: .green.opacity(tokens.glassmorphic.shadows.greenGlow.opacity), radius: tokens.glassmorphic.shadows.greenGlow.radius2, x: 0, y: 0)
            }
            .padding(.horizontal, tokens.elements.inputBar.textPadding)
            .padding(.bottom, tokens.elements.inputBar.bottomPadding)
            .padding(.top, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: tokens.elements.inputBar.cornerRadius)
                .fill(Color.black.opacity(tokens.glassmorphic.transparency.inputBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: tokens.elements.inputBar.cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(tokens.glassmorphic.transparency.borderTop),
                                    .white.opacity(tokens.glassmorphic.transparency.borderBottom)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .white.opacity(tokens.glassmorphic.shadows.innerGlow.opacity),
                    radius: tokens.glassmorphic.shadows.innerGlow.radius,
                    x: tokens.glassmorphic.shadows.innerGlow.x,
                    y: tokens.glassmorphic.shadows.innerGlow.y
                ) // Inner glow
                .shadow(
                    color: .black.opacity(tokens.glassmorphic.shadows.outerShadow.opacity),
                    radius: tokens.glassmorphic.shadows.outerShadow.radius,
                    x: tokens.glassmorphic.shadows.outerShadow.x,
                    y: tokens.glassmorphic.shadows.outerShadow.y
                ) // Outer shadow
        )
        .padding(.all, tokens.elements.inputBar.padding) // Symmetrical padding for floating canvas effect
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // TODO: Implement message sending
        print("Sending message: \(inputText)")
        
        // Clear input
        inputText = ""
    }
    
    private func debouncedUpdateTextHeight(for text: String) {
        // Cancel existing timer
        debounceTimer?.invalidate()
        
        // Set new timer with shorter delay for responsive feel
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
            updateTextHeight(for: text)
        }
    }
    
    private func updateTextHeight(for text: String) {
        let font = NSFont(name: tokens.typography.bodyFont, size: 12) ?? NSFont.systemFont(ofSize: 12)
        
        // Calculate available width more precisely
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        let paneWidth = screenWidth * tokens.pane.widthFraction
        let availableWidth: CGFloat = paneWidth - 32 - 32 // Container padding + text padding
        
        // Use the actual text or a single character for measurement
        let measureText = text.isEmpty ? "Ag" : text
        
        let attributedString = NSAttributedString(
            string: measureText,
            attributes: [
                .font: font,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineBreakMode = .byWordWrapping
                    return style
                }()
            ]
        )
        
        // Calculate bounding rect
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        
        let calculatedHeight = ceil(boundingRect.height)
        let maxHeight = calculateMaximumCanvasHeight()
        let newHeight = max(tokens.elements.inputBar.minHeight, min(maxHeight, calculatedHeight + 4)) // Add small buffer
        
        // Only animate if height actually changed to avoid unnecessary updates
        if abs(textHeight - newHeight) > 1 {
            let springTokens = tokens.animations.paneTransition
            withAnimation(.spring(response: springTokens.response * 1.5, dampingFraction: springTokens.dampingFraction, blendDuration: springTokens.blendDuration)) {
                textHeight = newHeight
            }
        }
    }
    
    private func calculateMaximumCanvasHeight() -> CGFloat {
        // Get the current window height
        guard let window = NSApplication.shared.windows.first else { return 800 }
        let windowHeight = window.frame.height
        
        // Calculate exact spacing for perfect floating canvas symmetry
        let titleBarHeight: CGFloat = 28 // macOS title bar height
        let containerPadding: CGFloat = tokens.elements.inputBar.padding // Container padding (all sides)
        let controlsRowHeight: CGFloat = 32 // Bottom controls row height
        let textInternalPadding: CGFloat = 24 // Text area internal padding (top + bottom)
        
        // Available height = window height - title bar - (2 * container padding) - controls - text padding
        let availableHeight = windowHeight - titleBarHeight - (containerPadding * 2) - controlsRowHeight - textInternalPadding
        
        // Use almost all available height for true journal canvas experience
        return max(200, availableHeight)
    }
}