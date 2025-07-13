//
//  ProviderRouter.swift
//  Aether
//
//  LLM provider routing and fallback coordination
//
//  BLUEPRINT SECTION: 🚨 Services - ModelRouter (Provider Routing Logic)
//  =====================================================================
//
//  DESIGN PRINCIPLES:
//  - Separation of Concerns: Pure routing logic, no state management or UI concerns
//  - No Hardcoding: All routing decisions based on external LLMProviders.json
//  - Modularity: Clean, testable routing that can be used by any coordinator
//  - No Redundancy: Single source of truth for provider fallback logic
//
//  RESPONSIBILITIES:
//  - Resolve provider configurations from routing entries
//  - Validate provider availability and API keys
//  - Execute provider fallback cascade based on external configuration
//  - Provide service health checking for UI indicators
//
//  USAGE:
//  - LLMManager uses for coordinating provider requests
//  - Future: PersonaRegistry will use for persona-specific routing
//  - Future: Slash commands will use for runtime model switching

import Foundation

class ProviderRouter {
    private let configuration: LLMConfiguration
    private let services: [String: any LLMServiceProtocol]
    
    init(configuration: LLMConfiguration, services: [String: any LLMServiceProtocol]) {
        self.configuration = configuration
        self.services = services
    }
    
    // MARK: - Provider Resolution
    
    /// Resolve and validate provider for routing entry
    func resolveProvider(_ routing: RoutingEntry) throws -> ResolvedProvider {
        guard let service = services[routing.provider] else {
            throw ProviderRoutingError.serviceUnavailable(routing.provider)
        }
        
        guard let provider = configuration.getProvider(routing.provider),
              let model = configuration.getModel(provider: routing.provider, model: routing.model) else {
            throw ProviderRoutingError.configurationMissing("\(routing.provider)/\(routing.model)")
        }
        
        let apiKey = configuration.getApiKey(for: routing.provider)
        guard !apiKey.isEmpty else {
            throw ProviderRoutingError.apiKeyMissing(routing.provider)
        }
        
        return ResolvedProvider(
            service: service,
            provider: provider,
            model: model,
            apiKey: apiKey
        )
    }
    
    // MARK: - Routing Execution
    
    /// Execute operation with automatic provider fallback
    func executeWithFallback<T>(
        operation: (ResolvedProvider) async throws -> T
    ) async throws -> T {
        
        guard let config = configuration.config else {
            throw ProviderRoutingError.configurationNotLoaded
        }
        
        var lastError: Error?
        
        // Try each provider in configured priority order
        for routing in config.routing.priority {
            do {
                let resolvedProvider = try resolveProvider(routing)
                let result = try await operation(resolvedProvider)
                return result
                
            } catch {
                print("❌ \(routing.provider) failed: \(error.localizedDescription)")
                lastError = error
                continue
            }
        }
        
        // All providers failed
        throw ProviderRoutingError.allProvidersFailed(lastError)
    }
    
    // MARK: - Service Health
    
    /// Check health status of all configured providers
    func checkServiceHealth() -> [String: ProviderHealth] {
        guard let config = configuration.config else {
            return [:]
        }
        
        var health: [String: ProviderHealth] = [:]
        
        for (providerId, provider) in config.providers {
            let hasService = services[providerId] != nil
            let hasApiKey = !configuration.getApiKey(for: providerId).isEmpty
            let hasConfiguration = configuration.getProvider(providerId) != nil
            
            let status: ProviderHealthStatus
            if hasService && hasApiKey && hasConfiguration {
                status = .healthy
            } else if hasConfiguration {
                status = .misconfigured
            } else {
                status = .unavailable
            }
            
            health[providerId] = ProviderHealth(
                status: status,
                hasService: hasService,
                hasApiKey: hasApiKey,
                hasConfiguration: hasConfiguration,
                providerName: provider.name
            )
        }
        
        return health
    }
    
    // MARK: - Configuration Access
    
    /// Get current routing priority from configuration
    func getRoutingPriority() -> [RoutingEntry] {
        return configuration.getRoutingPriority()
    }
    
    /// Get available provider IDs
    func getAvailableProviders() -> [String] {
        return Array(services.keys)
    }
    
    /// Get provider display name for UI
    func getProviderDisplayName(_ providerId: String) -> String {
        return configuration.getProvider(providerId)?.name ?? providerId
    }
    
    // MARK: - Runtime Configuration
    
    /// Check if specific provider is available and configured
    func isProviderAvailable(_ providerId: String) -> Bool {
        guard let _ = configuration.getProvider(providerId),
              services[providerId] != nil else {
            return false
        }
        
        let apiKey = configuration.getApiKey(for: providerId)
        return !apiKey.isEmpty
    }
    
    /// Get fallback behavior from configuration
    func getFallbackBehavior() -> String {
        return configuration.config?.routing.fallbackBehavior ?? "cascade"
    }
}

// MARK: - Data Structures

/// Resolved provider with all required components
struct ResolvedProvider {
    let service: any LLMServiceProtocol
    let provider: LLMProvider
    let model: LLMModel
    let apiKey: String
    
    /// Display name for UI
    var displayName: String {
        return "\(provider.name) (\(model.displayName))"
    }
}

/// Provider health status information
struct ProviderHealth {
    let status: ProviderHealthStatus
    let hasService: Bool
    let hasApiKey: Bool
    let hasConfiguration: Bool
    let providerName: String
}

enum ProviderHealthStatus {
    case healthy
    case misconfigured
    case unavailable
    
    var description: String {
        switch self {
        case .healthy:
            return "Ready"
        case .misconfigured:
            return "Configuration Error"
        case .unavailable:
            return "Unavailable"
        }
    }
}

// MARK: - Provider Routing Errors

enum ProviderRoutingError: Error, LocalizedError {
    case configurationNotLoaded
    case serviceUnavailable(String)
    case configurationMissing(String)
    case apiKeyMissing(String)
    case allProvidersFailed(Error?)
    
    var errorDescription: String? {
        switch self {
        case .configurationNotLoaded:
            return "LLM configuration not loaded"
        case .serviceUnavailable(let provider):
            return "Service not available: \(provider)"
        case .configurationMissing(let details):
            return "Configuration missing for: \(details)"
        case .apiKeyMissing(let provider):
            return "API key missing for: \(provider)"
        case .allProvidersFailed(let lastError):
            if let error = lastError {
                return "All configured LLM services failed. Last error: \(error.localizedDescription)"
            } else {
                return "All configured LLM services failed"
            }
        }
    }
}