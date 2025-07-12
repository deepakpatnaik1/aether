//
//  LLMConfiguration.swift
//  Aether
//
//  Dynamic LLM provider and model configuration
//
//  IMPLEMENTATION: JSON-Based Provider Registry
//  ==========================================
//
//  NO HARDCODING: All providers, models, and routing configurable
//  - Provider details loaded from LLMProviders.json
//  - New providers/models added without code changes
//  - Routing priority externally configurable
//
//  CONFIGURATION STRUCTURE:
//  - Provider metadata (name, baseURL, auth)
//  - Model specifications (ID, limits, parameters)
//  - Routing priority and fallback behavior
//
//  USAGE:
//  - Single source of truth for all LLM configuration
//  - Runtime provider discovery and validation
//  - Dynamic model parameter loading

import Foundation

struct LLMProvider: Codable {
    let name: String
    let baseURL: String
    let apiKeyEnvVar: String
    let models: [String: LLMModel]
}

struct LLMModel: Codable {
    let id: String
    let displayName: String
    let maxTokens: Int
    let temperature: Double
    let contextWindow: Int
}

struct LLMRouting: Codable {
    let priority: [RoutingEntry]
    let fallbackBehavior: String
}

struct RoutingEntry: Codable {
    let provider: String
    let model: String
}

struct LLMProvidersConfig: Codable {
    let providers: [String: LLMProvider]
    let routing: LLMRouting
}

class LLMConfiguration: ObservableObject {
    @Published var config: LLMProvidersConfig?
    @Published var isLoaded = false
    
    init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        guard let url = Bundle.main.url(forResource: "LLMProviders", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load LLMProviders.json")
            return
        }
        
        do {
            config = try JSONDecoder().decode(LLMProvidersConfig.self, from: data)
            isLoaded = true
        } catch {
            print("Failed to decode LLMProviders.json: \(error)")
        }
    }
    
    func getProvider(_ providerId: String) -> LLMProvider? {
        return config?.providers[providerId]
    }
    
    func getModel(provider: String, model: String) -> LLMModel? {
        return config?.providers[provider]?.models[model]
    }
    
    func getPrimaryRouting() -> RoutingEntry? {
        return config?.routing.priority.first
    }
    
    func getRoutingPriority() -> [RoutingEntry] {
        return config?.routing.priority ?? []
    }
    
    func getApiKey(for provider: String) -> String {
        guard let providerConfig = getProvider(provider) else { return "" }
        return ProcessInfo.processInfo.environment[providerConfig.apiKeyEnvVar] ?? ""
    }
}