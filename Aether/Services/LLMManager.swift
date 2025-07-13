//
//  LLMManager.swift
//  Aether
//
//  LLM provider routing coordinator for unified chat interface
//
//  BLUEPRINT SECTION: 🚨 Services - ModelRouter (Dynamic Provider Routing)
//  =======================================================================
//
//  DESIGN PRINCIPLES:
//  - No Hardcoding: All routing from LLMProviders.json configuration
//  - Separation of Concerns: Routing logic separate from individual services
//  - Modularity: Service discovery and provider coordination abstracted
//  - No Redundancy: Common routing logic unified between streaming/non-streaming
//
//  RESPONSIBILITIES:
//  - Coordinate requests across multiple LLM providers
//  - Handle automatic fallback cascade based on external configuration
//  - Manage service state and error handling
//  - Provide unified interface for MessageStore
//
//  CURRENT SCOPE: Basic User ↔ AI routing
//  - OpenAI primary, Fireworks fallback
//  - Future: Will route different personas to different models

import Foundation

class LLMManager: ObservableObject {
    private let configuration = LLMConfiguration()
    private lazy var services: [String: any LLMServiceProtocol] = createServices()
    private lazy var router: ProviderRouter = ProviderRouter(configuration: configuration, services: services)
    
    @Published var isLoading = false
    @Published var currentService = "None"
    @Published var errorMessage: String?
    
    // MARK: - Service Discovery
    
    /// Create service instances based on configuration
    private func createServices() -> [String: any LLMServiceProtocol] {
        var serviceMap: [String: any LLMServiceProtocol] = [:]
        
        // Initialize services for configured providers
        if configuration.getProvider("fireworks") != nil {
            serviceMap["fireworks"] = FireworksService()
        }
        if configuration.getProvider("openai") != nil {
            serviceMap["openai"] = OpenAIService()
        }
        
        return serviceMap
    }
    
    // MARK: - Routing Coordination
    
    /// Send message with automatic provider fallback
    func sendMessage(_ message: String) async throws -> String {
        await updateLoadingState(isLoading: true)
        
        defer {
            Task { @MainActor in
                if !Task.isCancelled { self.isLoading = false }
            }
        }
        
        return try await router.executeWithFallback { resolvedProvider in
            await updateCurrentService(provider: resolvedProvider.provider, model: resolvedProvider.model)
            return try await resolvedProvider.service.sendMessage(message)
        }
    }
    
    /// Stream message with automatic provider fallback
    func streamMessage(_ message: String) async throws -> AsyncStream<String> {
        await updateLoadingState(isLoading: true)
        
        return try await router.executeWithFallback { resolvedProvider in
            await updateCurrentService(provider: resolvedProvider.provider, model: resolvedProvider.model)
            let stream = try await resolvedProvider.service.streamMessage(message)
            
            // Clean up loading state when stream completes
            Task {
                for await _ in stream { }
                await MainActor.run { self.isLoading = false }
            }
            
            return stream
        }
    }
    
    // MARK: - Router Integration
    
    // MARK: - State Management
    
    /// Update loading state and current service on main thread
    @MainActor
    private func updateLoadingState(isLoading: Bool, error: String? = nil) {
        self.isLoading = isLoading
        if let error = error {
            self.errorMessage = error
            self.currentService = "None"
        } else {
            self.errorMessage = nil
        }
    }
    
    /// Update current service display name on main thread
    @MainActor
    private func updateCurrentService(provider: LLMProvider, model: LLMModel) {
        currentService = "\(provider.name) (\(model.displayName))"
    }
    
    // MARK: - Service Health
    
    /// Check health status of all configured providers
    func checkServiceHealth() -> [String: ProviderHealth] {
        return router.checkServiceHealth()
    }
    
    /// Get list of available provider IDs
    func getAvailableProviders() -> [String] {
        return router.getAvailableProviders()
    }
    
    /// Get current routing priority from configuration
    func getCurrentRoutingPriority() -> [RoutingEntry] {
        return router.getRoutingPriority()
    }
    
    /// Check if specific provider is available
    func isProviderAvailable(_ providerId: String) -> Bool {
        return router.isProviderAvailable(providerId)
    }
    
    /// Get provider display name for UI
    func getProviderDisplayName(_ providerId: String) -> String {
        return router.getProviderDisplayName(providerId)
    }
}