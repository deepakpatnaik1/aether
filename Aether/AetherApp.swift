//
//  AetherApp.swift
//  Aether
//
//  Created by Deepak Patnaik on 12.07.25.
//

import SwiftUI

@main
struct AetherApp: App {
    
    // Initialize global screenshot capture on app launch
    private let screenshotCapture = GlobalScreenshotCapture.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(screenshotCapture)
        }
        .defaultSize(width: 400, height: 600)
    }
}
