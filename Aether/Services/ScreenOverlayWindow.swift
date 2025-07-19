//
//  ScreenOverlayWindow.swift
//  Aether
//
//  Screen overlay window for crosshair cursor and rectangle selection
//
//  FEATURES:
//  - Full-screen overlay covering all displays
//  - Crosshair cursor for precise selection
//  - Rectangle selection with mouse drag
//  - Visual feedback during selection
//  - Escape key to cancel

import SwiftUI
import Cocoa

protocol ScreenOverlayDelegate: AnyObject {
    func screenOverlayDidSelectRegion(_ rect: CGRect)
    func screenOverlayDidCancel()
}

class ScreenOverlayWindow: NSWindow {
    
    weak var overlayDelegate: ScreenOverlayDelegate?
    private var selectionView: ScreenSelectionView?
    
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        setupWindow()
    }
    
    convenience init() {
        // Create window covering all screens
        let screenFrame = NSScreen.screensUnion
        self.init(
            contentRect: screenFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
    }
    
    private func setupWindow() {
        // Window configuration
        self.level = .screenSaver + 1 // Above all other windows
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Create selection view
        selectionView = ScreenSelectionView()
        selectionView?.overlayDelegate = self
        
        // Set up content view - avoid layout recursion
        if let selectionView = selectionView {
            let hostingView = NSHostingView(rootView: selectionView)
            
            // Defer layout to avoid recursion
            DispatchQueue.main.async {
                hostingView.frame = self.frame
                hostingView.autoresizingMask = [.width, .height]
                self.contentView = hostingView
                
                // Set up cursor after layout is complete
                NSCursor.crosshair.set()
            }
        }
    }
    
    func showOverlay() {
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()
        
        // Ensure we capture all events
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideOverlay() {
        self.orderOut(nil)
        NSCursor.arrow.set() // Reset cursor
    }
    
    // Handle escape key to cancel
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            overlayDelegate?.screenOverlayDidCancel()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

// MARK: - Screen Selection View

struct ScreenSelectionView: View {
    @State private var selectionRect: CGRect = .zero
    @State private var isDragging = false
    @State private var startPoint: CGPoint = .zero
    
    weak var overlayDelegate: ScreenOverlayDelegate?
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea(.all)
            
            // Selection rectangle
            if isDragging {
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .background(Color.clear)
                    .frame(
                        width: abs(selectionRect.width),
                        height: abs(selectionRect.height)
                    )
                    .position(
                        x: selectionRect.midX,
                        y: selectionRect.midY
                    )
            }
            
            // Instructions
            VStack {
                Text("Click and drag to select area")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                
                Text("Press ESC to cancel")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 50)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        startPoint = value.startLocation
                        isDragging = true
                    }
                    
                    let currentPoint = value.location
                    
                    selectionRect = CGRect(
                        x: min(startPoint.x, currentPoint.x),
                        y: min(startPoint.y, currentPoint.y),
                        width: abs(currentPoint.x - startPoint.x),
                        height: abs(currentPoint.y - startPoint.y)
                    )
                }
                .onEnded { value in
                    if isDragging && selectionRect.width > 10 && selectionRect.height > 10 {
                        overlayDelegate?.screenOverlayDidSelectRegion(selectionRect)
                    } else {
                        overlayDelegate?.screenOverlayDidCancel()
                    }
                    
                    isDragging = false
                    selectionRect = .zero
                }
        )
    }
}

// MARK: - Screen Selection Delegate

extension ScreenOverlayWindow: ScreenOverlayDelegate {
    func screenOverlayDidSelectRegion(_ rect: CGRect) {
        overlayDelegate?.screenOverlayDidSelectRegion(rect)
    }
    
    func screenOverlayDidCancel() {
        overlayDelegate?.screenOverlayDidCancel()
    }
}

// MARK: - NSScreen Extension

extension NSScreen {
    static var screensUnion: NSRect {
        return NSScreen.screens.reduce(NSRect.zero) { union, screen in
            return union.union(screen.frame)
        }
    }
}