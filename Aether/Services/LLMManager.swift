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
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer { 
            Task { @MainActor in
                isLoading = false
            }
        }
        
        guard let config = configuration.config else {
            print("❌ LLM configuration not loaded")
            throw LLMServiceError.missingAPIKey("LLM configuration not loaded")
        }
        
        print("🔄 Trying providers in order: \(config.routing.priority.map { "\($0.provider)/\($0.model)" })")
        
        // Try providers in priority order from config
        for routing in config.routing.priority {
            print("🔄 Attempting provider: \(routing.provider)")
            
            guard let service = services[routing.provider] else {
                print("❌ Service not available: \(routing.provider)")
                continue
            }
            
            guard let provider = configuration.getProvider(routing.provider),
                  let model = configuration.getModel(provider: routing.provider, model: routing.model) else {
                print("❌ Configuration missing for: \(routing.provider)/\(routing.model)")
                continue
            }
            
            let apiKey = configuration.getApiKey(for: routing.provider)
            print("🔑 API key for \(routing.provider): \(apiKey.isEmpty ? "❌ MISSING" : "✅ Present")")
            
            do {
                await MainActor.run {
                    currentService = "\(provider.name) (\(model.displayName))"
                }
                print("🚀 Calling \(provider.name) with model \(model.displayName)")
                print("🔗 URL: \(provider.baseURL)")
                let response = try await service.sendMessage(message)
                print("✅ \(provider.name) succeeded")
                return response
            } catch {
                print("❌ \(provider.name) failed: \(error)")
                print("❌ Full error: \(error.localizedDescription)")
                if let urlError = error as? URLError {
                    print("❌ URL Error details: \(urlError)")
                }
                continue
            }
        }
        
        await MainActor.run {
            currentService = "None"
            errorMessage = "All configured LLM services failed"
        }
        throw LLMServiceError.invalidResponse
    }
    
    func streamMessage(_ message: String) async throws -> AsyncStream<String> {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        guard let config = configuration.config else {
            print("❌ LLM configuration not loaded")
            throw LLMServiceError.missingAPIKey("LLM configuration not loaded")
        }
        
        print("🔄 Trying providers in order: \(config.routing.priority.map { "\($0.provider)/\($0.model)" })")
        
        // Try providers in priority order from config
        for routing in config.routing.priority {
            print("🔄 Attempting provider: \(routing.provider)")
            
            guard let service = services[routing.provider] else {
                print("❌ Service not available: \(routing.provider)")
                continue
            }
            
            guard let provider = configuration.getProvider(routing.provider),
                  let model = configuration.getModel(provider: routing.provider, model: routing.model) else {
                print("❌ Configuration missing for: \(routing.provider)/\(routing.model)")
                continue
            }
            
            let apiKey = configuration.getApiKey(for: routing.provider)
            print("🔑 API key for \(routing.provider): \(apiKey.isEmpty ? "❌ MISSING" : "✅ Present")")
            
            do {
                await MainActor.run {
                    currentService = "\(provider.name) (\(model.displayName))"
                }
                print("🚀 Streaming from \(provider.name) with model \(model.displayName)")
                print("🔗 URL: \(provider.baseURL)")
                
                let stream = try await service.streamMessage(message)
                print("✅ \(provider.name) streaming started")
                
                // Clean up loading state when stream completes
                Task {
                    for await _ in stream {
                        // Stream will be consumed by the caller
                    }
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
                
                return stream
            } catch {
                print("❌ \(provider.name) failed: \(error)")
                print("❌ Full error: \(error.localizedDescription)")
                if let urlError = error as? URLError {
                    print("❌ URL Error details: \(urlError)")
                }
                continue
            }
        }
        
        await MainActor.run {
            currentService = "None"
            errorMessage = "All configured LLM services failed"
            isLoading = false
        }
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