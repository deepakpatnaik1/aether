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
    @FocusState private var isInputFocused: Bool
    @EnvironmentObject var messageStore: MessageStore
    
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
                    .scrollDisabled(true)
                    .frame(height: textHeight)
                    .padding(.horizontal, tokens.elements.inputBar.textPadding)
                    .padding(.top, tokens.elements.inputBar.topPadding)
                    .padding(.bottom, tokens.elements.inputBar.topPadding)
                    .onKeyPress(keys: [.return]) { keyPress in
                        if keyPress.modifiers.contains(.command) {
                            sendMessage()
                            return .handled
                        }
                        // Let Enter create new lines (default TextEditor behavior)
                        return .ignored
                    }
            }
            .onChange(of: inputText) { oldValue, newValue in
                handleTextChange(oldValue: oldValue, newValue: newValue)
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
        .overlay(
            // Debug ruler overlay - shows exact container bounds
            Rectangle()
                .stroke(Color.red, lineWidth: 2)
                .overlay(
                    // Corner markers to measure padding
                    VStack {
                        HStack {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Spacer()
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                        }
                        Spacer()
                        HStack {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Spacer()
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                        }
                    }
                )
        )
        .background(
            // Debug background to show padding areas
            Rectangle()
                .fill(Color.blue.opacity(0.2))
        )
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageToSend = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear input immediately for responsive feel
        inputText = ""
        
        // Snap back to compact state
        withAnimation(.easeInOut(duration: 0.2)) {
            textHeight = tokens.elements.inputBar.minHeight
        }
        
        // Send message to MessageStore for processing
        messageStore.sendMessage(messageToSend)
    }
    
    private func handleTextChange(oldValue: String, newValue: String) {
        // Detect paste operation (large text change) vs normal typing
        let textDelta = abs(newValue.count - oldValue.count)
        let isPaste = textDelta > 10 // Arbitrary threshold for paste detection
        
        if isPaste {
            // For paste operations, use fast simple calculation
            handlePasteTextChange(newValue: newValue)
        } else {
            // For normal typing, use precise wrap detection
            let didExpand = shouldExpandForWrap(oldValue: oldValue, newValue: newValue)
            if didExpand {
                // Expand immediately before TextEditor can scroll
                let font = NSFont(name: tokens.typography.bodyFont, size: 12) ?? NSFont.systemFont(ofSize: 12)
                let lineHeight = font.ascender + abs(font.descender) + font.leading
                let currentLines = getCurrentLineCount(for: newValue)
                let estimatedHeight = CGFloat(currentLines) * lineHeight + tokens.elements.inputBar.topPadding * 2
                let maxHeight = calculateMaximumCanvasHeight()
                
                textHeight = min(maxHeight, max(tokens.elements.inputBar.minHeight, estimatedHeight))
            } else {
                // Only do animated precise calculation if we didn't just expand
                updateTextHeight(for: newValue)
            }
        }
    }
    
    private func handlePasteTextChange(newValue: String) {
        // Fast, simple calculation for paste operations
        let font = NSFont(name: tokens.typography.bodyFont, size: 12) ?? NSFont.systemFont(ofSize: 12)
        let lineHeight = font.ascender + abs(font.descender) + font.leading
        
        // Simple line count estimation (count \n + rough word wrapping estimate)
        let explicitLines = newValue.components(separatedBy: .newlines).count
        let estimatedHeight = CGFloat(explicitLines) * lineHeight + tokens.elements.inputBar.topPadding * 2
        let maxHeight = calculateMaximumCanvasHeight()
        
        // Set height immediately without expensive measurement
        textHeight = min(maxHeight, max(tokens.elements.inputBar.minHeight, estimatedHeight))
    }
    
    private func shouldExpandForWrap(oldValue: String, newValue: String) -> Bool {
        // Only check if we added exactly one character (normal typing)
        guard newValue.count == oldValue.count + 1 else { return false }
        
        let font = NSFont(name: tokens.typography.bodyFont, size: 12) ?? NSFont.systemFont(ofSize: 12)
        
        // Calculate available width
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        let paneWidth = screenWidth * tokens.pane.widthFraction
        let availableWidth: CGFloat = paneWidth - 32 - 32 // Container padding + text padding
        
        // Get the height of old vs new text when laid out
        let oldHeight = measureTextHeight(for: oldValue, width: availableWidth, font: font)
        let newHeight = measureTextHeight(for: newValue, width: availableWidth, font: font)
        
        // If the height increased, we wrapped to a new line
        return newHeight > oldHeight
    }
    
    private func getCurrentLineCount(for text: String) -> Int {
        let font = NSFont(name: tokens.typography.bodyFont, size: 12) ?? NSFont.systemFont(ofSize: 12)
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        let paneWidth = screenWidth * tokens.pane.widthFraction
        let availableWidth: CGFloat = paneWidth - 32 - 32
        
        let height = measureTextHeight(for: text, width: availableWidth, font: font)
        let lineHeight = font.ascender + abs(font.descender) + font.leading
        
        return max(1, Int(ceil(height / lineHeight)))
    }
    
    private func measureTextHeight(for text: String, width: CGFloat, font: NSFont) -> CGFloat {
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
        
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        
        return ceil(boundingRect.height)
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
            // Faster, more responsive animation for immediate expansion
            withAnimation(.spring(response: springTokens.response * 0.5, dampingFraction: springTokens.dampingFraction, blendDuration: springTokens.blendDuration * 0.3)) {
                textHeight = newHeight
            }
        }
    }
    
    private func calculateMaximumCanvasHeight() -> CGFloat {
        // Get the current window height
        guard let window = NSApplication.shared.windows.first else { return 800 }
        let windowHeight = window.frame.height
        
        // Calculate spacing for equal margins from title bar (top margin = inputBar.padding from title bar)
        let titleBarHeight: CGFloat = 28 // macOS title bar height
        let containerPadding: CGFloat = tokens.elements.inputBar.padding // Container padding (all sides)
        let controlsRowHeight: CGFloat = 32 // Bottom controls row height
        let textInternalPadding: CGFloat = 24 // Text area internal padding (top + bottom)
        
        // Total container overhead = top margin + container padding + controls + text padding + bottom margin
        let topMarginAdjustment: CGFloat = 2 // Hair width reduction
        let containerOverhead = (containerPadding - topMarginAdjustment) + containerPadding + controlsRowHeight + textInternalPadding + containerPadding
        
        // Available height for text area = window height - title bar - total container overhead
        let availableTextHeight = windowHeight - titleBarHeight - containerOverhead
        
        // Maximum text area height that keeps container positioned correctly
        return max(200, availableTextHeight)
    }
}