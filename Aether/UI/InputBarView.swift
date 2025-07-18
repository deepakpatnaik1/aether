//
//  InputBarView.swift
//  Aether
//
//  Text input area where user types messages to AI personas

import SwiftUI
import Combine
import Foundation

struct AttachmentPreview {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let type: AttachmentType
    
    enum AttachmentType {
        case image
        case pdf
        case text
        case other
    }
}

struct InputBarView: View {
    @State private var inputText: String = ""
    @State private var textHeight: CGFloat
    @State private var attachments: [AttachmentPreview] = []
    @State private var showingFilePicker = false
    @FocusState private var isInputFocused: Bool
    @EnvironmentObject var messageStore: MessageStore
    @EnvironmentObject var focusManager: FocusManager
    
    private let tokens = DesignTokens.shared
    
    init() {
        let font = NSFont(name: DesignTokens.shared.typography.bodyFont, size: 12) ?? NSFont.systemFont(ofSize: 12)
        let lineHeight = font.ascender + abs(font.descender) + font.leading
        let singleLineTextHeight = lineHeight
        _textHeight = State(initialValue: singleLineTextHeight)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !attachments.isEmpty {
                attachmentPreviewSection()
            }
            
            ZStack(alignment: .bottomLeading) {
                TextEditor(text: $inputText)
                    .font(.custom(tokens.typography.bodyFont, size: 12))
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .scrollContentBackground(.hidden)
                    .frame(height: textHeight)
                    .padding(.horizontal, tokens.elements.inputBar.textPadding)
                    .padding(.top, tokens.elements.inputBar.topPadding)
                    .padding(.bottom, tokens.elements.inputBar.topPadding)
                    .onKeyPress { keyPress in
                        if keyPress.key == .return && keyPress.modifiers.contains(.command) {
                            sendMessage()
                            return .handled
                        }
                        return .ignored
                    }
            }
            .onChange(of: inputText) { oldValue, newValue in
                handleTextChange(oldValue: oldValue, newValue: newValue)
            }
            
            HStack(spacing: tokens.elements.inputBar.controlsSpacing) {
                Button(action: {
                    showingFilePicker = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(tokens.glassmorphic.transparency.controls))
                        .frame(width: tokens.elements.buttons.plusSize, height: tokens.elements.buttons.plusSize)
                }
                .buttonStyle(PlainButtonStyle())
                
                ModelSwitcher()
                
                Spacer()
                
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
                )
                .shadow(
                    color: .black.opacity(tokens.glassmorphic.shadows.outerShadow.opacity),
                    radius: tokens.glassmorphic.shadows.outerShadow.radius,
                    x: tokens.glassmorphic.shadows.outerShadow.x,
                    y: tokens.glassmorphic.shadows.outerShadow.y
                )
        )
        .padding(.all, tokens.elements.inputBar.padding)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            isInputFocused = true
        }
        .onReceive(focusManager.$shouldFocusInput) { shouldFocus in
            if shouldFocus {
                isInputFocused = true
                focusManager.clearFocusRequest()
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .pdf, .plainText, .item],
            allowsMultipleSelection: true
        ) { result in
            handleFilePickerResult(result)
        }
        .onReceive(NotificationCenter.default.publisher(for: .addScreenshotAttachment)) { notification in
            handleScreenshotNotification(notification)
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageToSend = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        messageStore.sendMessage(messageToSend)
    }
    
    private func handleTextChange(oldValue: String, newValue: String) {
        print("🔍 handleTextChange DEBUG:")
        print("  - Old value: '\(oldValue.prefix(30))...'")
        print("  - New value: '\(newValue.prefix(30))...'")
        print("  - Length changed: \(oldValue.count) -> \(newValue.count)")
        
        // Always use line-based calculation for consistent behavior
        updateTextHeight(for: newValue)
    }
    
    
    
    private func getCurrentLineCount(for text: String) -> Int {
        let font = NSFont(name: tokens.typography.bodyFont, size: 12) ?? NSFont.systemFont(ofSize: 12)
        let contentWidth: CGFloat = tokens.layout.sizing["contentWidth"] ?? 592
        let textFieldWidth = contentWidth - (tokens.elements.inputBar.textPadding * 2) - (tokens.elements.inputBar.padding * 2)
        let availableWidth: CGFloat = textFieldWidth
        
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
        let lineHeight = font.ascender + abs(font.descender) + font.leading
        
        // Calculate actual line count (including word wraps)
        let actualLineCount = getCurrentLineCount(for: text)
        
        // Calculate maximum possible line count before we hit height limit
        let maxHeight = calculateMaximumCanvasHeight()
        let maxLineCount = Int(floor(maxHeight / lineHeight))
        
        // Cap the line count at the maximum - this prevents TextField from even trying to expand beyond this
        let constrainedLineCount = min(actualLineCount, maxLineCount)
        
        // Calculate height based on constrained line count
        let textHeight = CGFloat(constrainedLineCount) * lineHeight
        let newHeight = textHeight
        
        print("🔍 updateTextHeight DEBUG:")
        print("  - Text: '\(text.prefix(50))...'")
        print("  - Actual line count: \(actualLineCount)")
        print("  - Max line count: \(maxLineCount)")
        print("  - Constrained line count: \(constrainedLineCount)")
        print("  - Line height: \(lineHeight)")
        print("  - Calculated text height: \(textHeight)")
        print("  - Max height: \(maxHeight)")
        print("  - New height: \(newHeight)")
        print("  - Current height: \(self.textHeight)")
        print("  - Height difference: \(abs(self.textHeight - newHeight))")
        print("  - Will animate: \(abs(self.textHeight - newHeight) > 2)")
        
        // Update height with animation only if significantly different
        if abs(self.textHeight - newHeight) > 2 {
            let springTokens = tokens.animations.paneTransition
            print("  - ANIMATING height change from \(self.textHeight) to \(newHeight)")
            withAnimation(.spring(response: springTokens.response * 0.5, dampingFraction: springTokens.dampingFraction, blendDuration: springTokens.blendDuration * 0.3)) {
                self.textHeight = newHeight
            }
        } else {
            print("  - DIRECT height change from \(self.textHeight) to \(newHeight)")
            self.textHeight = newHeight
        }
    }
    
    private func calculateMaximumCanvasHeight() -> CGFloat {
        // Get the current window height
        guard let window = NSApplication.shared.windows.first else { return 800 }
        let windowHeight = window.frame.height
        
        // Calculate total input bar chrome (everything except the text area)
        let titleBarHeight: CGFloat = 28 // macOS title bar height
        let containerPadding: CGFloat = tokens.elements.inputBar.padding // Container padding (all sides)
        let controlsRowHeight: CGFloat = 32 // Bottom controls row height
        let textInternalPadding: CGFloat = tokens.elements.inputBar.topPadding + tokens.elements.inputBar.topPadding // Text area internal padding (top + bottom)
        let attachmentHeight: CGFloat = attachments.isEmpty ? 0 : 81 // Attachment preview area height (80 + 1 for divider)
        
        // Total chrome: title bar + container padding (top/bottom) + text internal padding + controls row + attachments
        let totalChrome = titleBarHeight + (containerPadding * 2) + textInternalPadding + controlsRowHeight + attachmentHeight
        
        // Available height for text area to achieve perfect vertical symmetry
        let availableTextHeight = windowHeight - totalChrome
        
        print("🔍 Max height calculation:")
        print("  - Window height: \(windowHeight)")
        print("  - Title bar height: \(titleBarHeight)")
        print("  - Container padding (top/bottom): \(containerPadding * 2)")
        print("  - Text internal padding: \(textInternalPadding)")
        print("  - Controls row height: \(controlsRowHeight)")
        print("  - Attachment height: \(attachmentHeight)")
        print("  - Total chrome: \(totalChrome)")
        print("  - Available text height: \(availableTextHeight)")
        print("  - Final max height: \(max(200, availableTextHeight))")
        
        // Maximum text area height that achieves perfect vertical symmetry
        return max(200, availableTextHeight)
    }
    
    // MARK: - Attachment Preview Section
    
    @ViewBuilder
    private func attachmentPreviewSection() -> some View {
        VStack(spacing: 0) {
            // Attachment preview area with glassmorphic styling
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(attachments, id: \.id) { attachment in
                        attachmentPreviewItem(attachment)
                    }
                }
                .padding(.horizontal, tokens.elements.inputBar.textPadding)
                .padding(.vertical, 8)
            }
            .frame(height: 80)
            
            // Divider line
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, tokens.elements.inputBar.textPadding)
        }
    }
    
    @ViewBuilder
    private func attachmentPreviewItem(_ attachment: AttachmentPreview) -> some View {
        VStack(spacing: 4) {
            // File preview thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .frame(width: 60, height: 45)
                .overlay(
                    Group {
                        switch attachment.type {
                        case .image:
                            AsyncImage(url: attachment.url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "photo")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .pdf:
                            Image(systemName: "doc.pdf")
                                .foregroundColor(.white.opacity(0.8))
                        case .text:
                            Image(systemName: "doc.text")
                                .foregroundColor(.white.opacity(0.8))
                        case .other:
                            Image(systemName: "doc")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                )
                .overlay(
                    // Remove button
                    Button(action: {
                        removeAttachment(attachment)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 16, height: 16)
                    .offset(x: 8, y: -8),
                    alignment: .topTrailing
                )
            
            // File name
            Text(attachment.name)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
                .frame(width: 60)
        }
    }
    
    private func removeAttachment(_ attachment: AttachmentPreview) {
        withAnimation(.easeInOut(duration: 0.2)) {
            attachments.removeAll { $0.id == attachment.id }
        }
    }
    
    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            withAnimation(.easeInOut(duration: 0.3)) {
                for url in urls {
                    let attachment = createAttachmentPreview(from: url)
                    attachments.append(attachment)
                }
            }
        case .failure(let error):
            print("❌ File picker error: \(error.localizedDescription)")
        }
    }
    
    private func createAttachmentPreview(from url: URL) -> AttachmentPreview {
        let name = url.lastPathComponent
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        
        let pathExtension = url.pathExtension.lowercased()
        let type: AttachmentPreview.AttachmentType
        
        switch pathExtension {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp":
            type = .image
        case "pdf":
            type = .pdf
        case "txt", "md", "swift", "py", "js", "html", "css", "json", "xml":
            type = .text
        default:
            type = .other
        }
        
        return AttachmentPreview(
            url: url,
            name: name,
            size: Int64(size),
            type: type
        )
    }
    
    private func handleScreenshotNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let imageURL = userInfo["imageURL"] as? URL else {
            print("❌ Invalid screenshot notification")
            return
        }
        
        print("📸 Received screenshot notification: \(imageURL)")
        
        // Create attachment preview for screenshot
        let attachment = createAttachmentPreview(from: imageURL)
        
        // Add to attachments with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            attachments.append(attachment)
        }
        
        // Focus the input bar
        isInputFocused = true
        
        print("✅ Screenshot added to attachments")
    }
}