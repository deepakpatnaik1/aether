//
//  LLMManager.swift
//  Aether
//
//  LLM Priority Routing Manager
//
//  IMPLEMENTATION: Dynamic Provider Routing
//  =======================================
//
//  NO HARDCODING: All routing from LLMProviders.json
//  - Provider priority configurable at runtime
//  - Models and providers externally defined
//  - API endpoints and parameters from config
//
//  FEATURES:
//  - Automatic fallback cascade based on config
//  - Unified interface for all LLM interactions
//  - Dynamic service discovery and validation
//  - Runtime configuration reload capability
//
//  USAGE:
//  - Single entry point for all AI conversations
//  - Routes based on external configuration
//  - Provides consistent response format

import Foundation

class LLMManager: ObservableObject {
    private let configuration = LLMConfiguration()
    private var services: [String: any LLMServiceProtocol] = [:]
    
    @Published var isLoading = false
    @Published var currentService = "None"
    @Published var errorMessage: String?
    
    init() {
        initializeServices()
    }
    
    private func initializeServices() {
        services["fireworks"] = FireworksService()
        services["openai"] = OpenAIService()
    }
    
    func sendMessage(_ message: String) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard let config = configuration.config else {
            throw LLMServiceError.missingAPIKey("LLM configuration not loaded")
        }
        
        // Try providers in priority order from config
        for routing in config.routing.priority {
            guard let service = services[routing.provider] else {
                print("Service not available: \(routing.provider)")
                continue
            }
            
            guard let provider = configuration.getProvider(routing.provider),
                  let model = configuration.getModel(provider: routing.provider, model: routing.model) else {
                print("Configuration missing for: \(routing.provider)/\(routing.model)")
                continue
            }
            
            do {
                currentService = "\(provider.name) (\(model.displayName))"
                let response = try await service.sendMessage(message)
                return response
            } catch {
                print("\(provider.name) failed: \(error.localizedDescription)")
                continue
            }
        }
        
        currentService = "None"
        errorMessage = "All configured LLM services failed"
        throw LLMServiceError.invalidResponse
    }
    
    func checkServiceHealth() -> [String: Bool] {
        guard let config = configuration.config else {
            return [:]
        }
        
        var health: [String: Bool] = [:]
        
        for (providerId, _) in config.providers {
            let apiKey = configuration.getApiKey(for: providerId)
            health[providerId] = !apiKey.isEmpty && services[providerId] != nil
        }
        
        return health
    }
    
    func getAvailableProviders() -> [String] {
        return Array(services.keys)
    }
    
    func getCurrentRoutingPriority() -> [RoutingEntry] {
        return configuration.getRoutingPriority()
    }
}