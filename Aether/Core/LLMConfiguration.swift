//
//  LLMConfiguration.swift
//  Aether
//
//  Dynamic LLM provider and model configuration manager
//
//  BLUEPRINT SECTION: 🚨 Services - Dynamic Provider Routing
//  ========================================================
//
//  DESIGN PRINCIPLES:
//  - No Hardcoding: All providers, models, and routing externally configurable
//  - Separation of Concerns: Configuration loading separate from API key resolution
//  - Modularity: New providers/models added without code changes
//  - No Redundancy: Single source of truth for all LLM configuration
//
//  RESPONSIBILITIES:
//  - Load and parse LLMProviders.json configuration
//  - Resolve API keys from environment variables and .env files
//  - Provide lookup functions for routing and service discovery
//  - Maintain configuration state for runtime updates
//
//  USAGE:
//  - LLMManager queries for provider routing decisions
//  - Services use for API endpoints and authentication
//  - Future: PersonaRegistry will use for model assignments

import Foundation

// MARK: - Configuration Data Models

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

// MARK: - Configuration Manager

class LLMConfiguration: ObservableObject {
    @Published var config: LLMProvidersConfig?
    @Published var isLoaded = false
    
    
    init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration Loading
    
    /// Load LLMProviders.json from app bundle
    private func loadConfiguration() {
        guard let url = Bundle.main.url(forResource: "LLMProviders", withExtension: "json") else {
            print("❌ LLMProviders.json not found in app bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            config = try JSONDecoder().decode(LLMProvidersConfig.self, from: data)
            isLoaded = true
            print("✅ LLM configuration loaded successfully")
        } catch {
            print("❌ Failed to decode LLMProviders.json: \(error)")
        }
    }
    
    // MARK: - Configuration Lookup
    
    /// Get provider configuration by ID
    func getProvider(_ providerId: String) -> LLMProvider? {
        return config?.providers[providerId]
    }
    
    /// Get specific model configuration
    func getModel(provider: String, model: String) -> LLMModel? {
        return config?.providers[provider]?.models[model]
    }
    
    /// Get primary routing entry (first in priority list)
    func getPrimaryRouting() -> RoutingEntry? {
        return config?.routing.priority.first
    }
    
    /// Get complete routing priority list
    func getRoutingPriority() -> [RoutingEntry] {
        return config?.routing.priority ?? []
    }
    
    // MARK: - API Key Resolution
    
    /// Resolve API key for provider from environment variables or .env file
    func getApiKey(for provider: String) -> String {
        guard let providerConfig = getProvider(provider) else { 
            return ""
        }
        
        // Primary: Check environment variables
        if let envKey = ProcessInfo.processInfo.environment[providerConfig.apiKeyEnvVar], !envKey.isEmpty {
            return envKey
        }
        
        // Fallback: Load from .env file using dedicated parser
        return EnvFileParser.loadKey(providerConfig.apiKeyEnvVar)
    }
}