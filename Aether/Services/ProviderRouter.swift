//
//  ProviderRouter.swift
//  Aether
//
//  Routes AI requests to different providers with automatic fallback

import Foundation

class ProviderRouter {
    private let configuration: LLMConfiguration
    private let services: [String: any LLMServiceProtocol]
    private var overridePrimaryModel: RoutingEntry?
    
    init(configuration: LLMConfiguration, services: [String: any LLMServiceProtocol]) {
        self.configuration = configuration
        self.services = services
    }
    
    // MARK: - Model Switching
    
    /// Set primary model override for routing
    func setPrimaryModel(provider: String, model: String) {
        overridePrimaryModel = RoutingEntry(provider: provider, model: model)
    }
    
    /// Get effective routing priority (with override if set)
    private func getEffectiveRoutingPriority() -> [RoutingEntry] {
        guard let override = overridePrimaryModel else {
            return configuration.getRoutingPriority()
        }
        
        // Put override first, then rest of configured routing
        var priority = configuration.getRoutingPriority()
        priority.removeAll { $0.provider == override.provider && $0.model == override.model }
        return [override] + priority
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
    
    // MARK: - Claude Code Special Routing
    
    /// Execute operation with Claude Code special routing logic
    func executeWithPersonaRouting<T>(
        persona: String,
        selectedModel: String?,
        operation: (ResolvedProvider) async throws -> T
    ) async throws -> T {
        
        // BIDIRECTIONAL BINDING RULE 1: Claude persona always uses Claude Code
        if persona.lowercased() == "claude" {
            let claudeCodeRouting = RoutingEntry(provider: "claude-code", model: "claude-code-sonnet")
            let resolvedProvider = try resolveProvider(claudeCodeRouting)
            return try await operation(resolvedProvider)
        }
        
        // BIDIRECTIONAL BINDING RULE 2: Claude Code model only allows Claude persona
        if selectedModel == "claude-code" && persona.lowercased() != "claude" {
            throw ProviderRoutingError.personaModelMismatch("Claude Code model can only be used with Claude persona")
        }
        
        // BIDIRECTIONAL BINDING RULE 3: Auto-select Claude Code when Claude summoned
        if selectedModel == "claude-code" {
            let claudeCodeRouting = RoutingEntry(provider: "claude-code", model: "claude-code-sonnet")
            let resolvedProvider = try resolveProvider(claudeCodeRouting)
            return try await operation(resolvedProvider)
        }
        
        // Standard routing for all other personas
        return try await executeWithFallback(operation: operation)
    }
    
    /// Execute operation with automatic provider fallback
    func executeWithFallback<T>(
        operation: (ResolvedProvider) async throws -> T
    ) async throws -> T {
        
        guard configuration.config != nil else {
            throw ProviderRoutingError.configurationNotLoaded
        }
        
        var lastError: Error?
        
        // Try each provider in effective priority order (with override if set)
        for routing in getEffectiveRoutingPriority() {
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
    case personaModelMismatch(String)
    
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
        case .personaModelMismatch(let message):
            return message
        }
    }
}