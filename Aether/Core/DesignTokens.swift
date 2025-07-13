//
//  DesignTokens.swift
//  Aether
//
//  Design system constants loader
//

import Foundation

struct DesignTokens: Codable {
    let typography: Typography
    let layout: Layout
    let glassmorphic: Glassmorphic
    let elements: Elements
    let animations: Animations
    let pane: Pane
    let background: Background
    
    struct Typography: Codable {
        let bodyFont: String
        let codeFont: String
    }
    
    struct Layout: Codable {
        let padding: [String: Double]
        let margins: [String: Double]
        let sizing: [String: Double]
    }
    
    struct Glassmorphic: Codable {
        let transparency: Transparency
        let gradients: Gradients
        let shadows: Shadows
        
        struct Transparency: Codable {
            let inputBackground: Double
            let borderTop: Double
            let borderBottom: Double
            let placeholder: Double
            let controls: Double
        }
        
        struct Gradients: Codable {
            let borderColors: [String]
            let borderOpacities: [Double]
        }
        
        struct Shadows: Codable {
            let innerGlow: ShadowSpec
            let outerShadow: ShadowSpec
            let greenGlow: GreenGlow
            
            struct ShadowSpec: Codable {
                let color: String
                let opacity: Double
                let radius: Double
                let x: Double
                let y: Double
            }
            
            struct GreenGlow: Codable {
                let radius1: Double
                let radius2: Double
                let opacity: Double
            }
        }
    }
    
    struct Elements: Codable {
        let inputBar: InputBar
        let scrollback: Scrollback
        let buttons: Buttons
        let panes: Panes
        let separators: Separators
        
        struct InputBar: Codable {
            let cornerRadius: Double
            let padding: Double
            let textPadding: Double
            let topPadding: Double
            let bottomPadding: Double
            let minHeight: Double
            let placeholderText: String
            let fontSize: Double
            let placeholderPaddingHorizontal: Double
            let controlsSpacing: Double
            let defaultTextHeight: Double
        }
        
        struct Scrollback: Codable {
            let bodyFontSize: Double
            let authorFontSize: Double
            let highlight: Highlight
            
            struct Highlight: Codable {
                let fillOpacity: Double
                let borderOpacityMultiplier: Double
                let shadowOpacityMultiplier: Double
                let shadowRadiusMultiplier: Double
                let borderWidth: Double
                let shadowOffsetY: Double
            }
        }
        
        struct Buttons: Codable {
            let plusSize: Double
            let sendSize: Double
            let indicatorSize: Double
        }
        
        struct Panes: Codable {
            let spacing: Double
            let debugSpacing: Double
            let borderRadius: Double
            let borderOpacity: Double
            let borderWidth: Double
            let topPadding: Double
            let textOpacity: Double
        }
        
        struct Separators: Codable {
            let width: Double
            let glowRadius: Double
            let topPadding: Double
            let bottomPadding: Double
        }
    }
    
    struct Animations: Codable {
        let paneTransition: PaneTransition
        let window: Window
        let messageNavigation: MessageNavigation
        
        struct PaneTransition: Codable {
            let response: Double
            let dampingFraction: Double
            let blendDuration: Double
        }
        
        struct Window: Codable {
            let animationDuration: Double
        }
        
        struct MessageNavigation: Codable {
            let scrollDuration: Double
            let smoothScrollIncrement: Double
            let smoothScrollDuration: Double
        }
    }
    
    struct Pane: Codable {
        let widthFraction: Double
        let fallbackWidth: Double
        let windowSizes: WindowSizes
        
        struct WindowSizes: Codable {
            let oneThird: Double
            let twoThirds: Double
            let full: Double
        }
    }
    
    struct Background: Codable {
        let primary: Primary
        
        struct Primary: Codable {
            let red: Double
            let green: Double
            let blue: Double
        }
    }
    
    static let shared: DesignTokens = {
        guard let url = Bundle.main.url(forResource: "DesignTokens", withExtension: "json") else {
            print("❌ Could not find DesignTokens.json in bundle")
            fatalError("Could not find DesignTokens.json in bundle")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("❌ Could not read DesignTokens.json data")
            fatalError("Could not read DesignTokens.json data")
        }
        
        do {
            let tokens = try JSONDecoder().decode(DesignTokens.self, from: data)
            print("✅ DesignTokens loaded successfully")
            return tokens
        } catch {
            print("❌ Could not decode DesignTokens.json: \(error)")
            fatalError("Could not decode DesignTokens.json: \(error)")
        }
    }()
}