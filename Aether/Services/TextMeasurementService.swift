//
//  TextMeasurementService.swift
//  Aether
//
//  Text measurement and layout calculation service
//
//  BLUEPRINT SECTION: 🚨 Services - Text Measurement
//  ================================================
//
//  DESIGN PRINCIPLES:
//  - Separation of Concerns: Text calculations isolated from UI components
//  - Single Responsibility: Manages only text measurement and sizing
//  - Reusability: Can be used by multiple UI components
//
//  RESPONSIBILITIES:
//  - Calculate text height for dynamic input sizing
//  - Handle word wrapping calculations
//  - Provide window-aware layout calculations
//  - Handle paste vs typing detection

import Foundation
import SwiftUI
import AppKit

class TextMeasurementService: ObservableObject {
    private let tokens = DesignTokens.shared
    
    // MARK: - Text Height Calculation
    
    func calculateTextHeight(for text: String, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else {
            return tokens.elements.inputBar.minHeight
        }
        
        // Create NSTextView for accurate measurement
        let textView = NSTextView()
        textView.font = NSFont(name: tokens.typography.bodyFont, size: 12) ?? NSFont.systemFont(ofSize: 12)
        textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? .zero
        
        let measuredHeight = usedRect.height + tokens.elements.inputBar.topPadding * 2
        let constrainedHeight = min(measuredHeight, calculateMaxHeight())
        
        return max(constrainedHeight, tokens.elements.inputBar.minHeight)
    }
    
    func calculateMaxHeight() -> CGFloat {
        guard let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            return 400 // Fallback max height
        }
        
        let windowHeight = window.frame.height
        let maxInputHeight = windowHeight * 0.4 // 40% of window height
        
        return min(maxInputHeight, 600) // Absolute max height
    }
    
    // MARK: - Text Change Analysis
    
    func detectPasteOperation(oldText: String, newText: String) -> Bool {
        let textDelta = abs(newText.count - oldText.count)
        return textDelta > 10 // Arbitrary threshold for paste detection
    }
    
    func shouldUseSlowAnimation(oldText: String, newText: String) -> Bool {
        return detectPasteOperation(oldText: oldText, newText: newText)
    }
    
    // MARK: - Animation Timing
    
    func getAnimationTiming(for changeType: TextChangeType) -> (response: Double, dampingFraction: Double, blendDuration: Double) {
        let springTokens = tokens.animations.paneTransition
        
        switch changeType {
        case .clear:
            return (
                springTokens.response * 0.5,
                springTokens.dampingFraction,
                springTokens.blendDuration * 0.3
            )
        case .paste:
            return (
                springTokens.response * 1.5,
                springTokens.dampingFraction * 0.8,
                springTokens.blendDuration * 1.2
            )
        case .typing:
            return (
                springTokens.response * 0.8,
                springTokens.dampingFraction,
                springTokens.blendDuration * 0.5
            )
        }
    }
    
    enum TextChangeType {
        case clear, paste, typing
    }
}