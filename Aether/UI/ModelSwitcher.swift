//
//  ModelSwitcher.swift
//  Aether
//
//  LLM model selection dropdown for input bar
//
//  BLUEPRINT SECTION: 🚨 UI - ModelSwitcher
//  ========================================
//
//  DESIGN PRINCIPLES:
//  - Clean dropdown interface for model selection
//  - Noir aesthetic matching input bar styling
//  - Minimal footprint in controls row
//
//  RESPONSIBILITIES:
//  - Display current active model name
//  - Provide dropdown with available models
//  - Handle model switching via MessageStore
//

import SwiftUI

struct ModelSwitcher: View {
    @EnvironmentObject var messageStore: MessageStore
    @State private var showDropdown = false
    
    private let tokens = DesignTokens.shared
    
    // Get available models from LLMManager
    private var availableModels: [String] {
        let models = messageStore.llmManager.getAvailableModels()
        return models
    }
    
    var body: some View {
        let content = buildContent()
        
        return content
            .onTapGesture {
                // Close dropdown when tapping outside
                if showDropdown {
                    showDropdown = false
                }
            }
            .onKeyPress(keys: [.escape]) { keyPress in
                if showDropdown {
                    showDropdown = false
                    return .handled
                }
                return .ignored
            }
    }
    
    @ViewBuilder
    private func buildContent() -> some View {
        ZStack {
            if showDropdown {
                buildDropdown()
            } else {
                buildButton()
            }
        }
    }
    
    @ViewBuilder
    private func buildDropdown() -> some View {
        VStack(spacing: 0) {
            ForEach(availableModels, id: \.self) { model in
                buildDropdownItem(model)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    @ViewBuilder
    private func buildDropdownItem(_ model: String) -> some View {
        Button(action: {
            selectModel(model)
        }) {
            HStack {
                Text(getModelDisplayName(model))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                if model == getCurrentModel() {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(model == getCurrentModel() ? 0.15 : 0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func buildButton() -> some View {
        Button(action: {
            showDropdown.toggle()
        }) {
            HStack(spacing: 4) {
                Text(getCurrentModelDisplayName())
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentModel() -> String {
        return messageStore.llmManager.getCurrentModel()
    }
    
    private func getCurrentModelDisplayName() -> String {
        return getModelDisplayName(getCurrentModel())
    }
    
    private func getModelDisplayName(_ model: String) -> String {
        // Remove provider prefix for display (openai:gpt-4.1-mini -> gpt-4.1-mini)
        let parts = model.split(separator: ":")
        if parts.count == 2 {
            return String(parts[1]).lowercased()
        }
        return model.lowercased()
    }
    
    private func selectModel(_ model: String) {
        showDropdown = false
        messageStore.llmManager.switchModel(to: model)
    }
}

#Preview {
    ModelSwitcher()
        .padding()
        .background(Color.black)
}