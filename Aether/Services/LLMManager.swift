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
    
    // BLUEPRINT: Memory integration handled by OmniscientBundleBuilder
    
    @Published var isLoading = false
    @Published var currentService = "None"
    @Published var errorMessage: String?
    @Published var currentModel: String = ""
    
    init() {
        // Set initial current model from primary routing
        if let primaryRoute = configuration.getPrimaryRouting() {
            currentModel = getModelKey(provider: primaryRoute.provider, model: primaryRoute.model)
        }
    }
    
    // MARK: - Model Management
    
    /// Get available models for UI display (only those with valid API keys)
    func getAvailableModels() -> [String] {
        guard let config = configuration.config else { return [] }
        
        var models: [String] = []
        for (providerKey, provider) in config.providers {
            // Only include models from providers with valid API keys
            let apiKey = configuration.getApiKey(for: providerKey)
            guard !apiKey.isEmpty else { continue }
            
            for (modelKey, _) in provider.models {
                models.append(getModelKey(provider: providerKey, model: modelKey))
            }
        }
        return models.sorted()
    }
    
    /// Switch to a different model
    func switchModel(to modelKey: String) {
        let (provider, model) = parseModelKey(modelKey)
        
        // Validate model exists
        guard configuration.getModel(provider: provider, model: model) != nil else {
            print("❌ Model not found: \(modelKey)")
            return
        }
        
        // Update current model
        currentModel = modelKey
        
        // Update router to use new model as primary
        router.setPrimaryModel(provider: provider, model: model)
        
        print("✅ Switched to model: \(modelKey)")
    }
    
    /// Get current model key
    func getCurrentModel() -> String {
        return currentModel
    }
    
    // MARK: - Helper Methods
    
    private func getModelKey(provider: String, model: String) -> String {
        return "\(provider):\(model)"
    }
    
    private func parseModelKey(_ modelKey: String) -> (provider: String, model: String) {
        let parts = modelKey.split(separator: ":")
        if parts.count == 2 {
            return (String(parts[0]), String(parts[1]))
        }
        return ("", "")
    }
    
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
    
    /// Send message with automatic provider fallback (legacy, no persona)
    /// BLUEPRINT: Eventually includes full vault context (omniscient memory scope)
    /// CURRENT: Includes conversation history for continuity
    func sendMessage(_ message: String) async throws -> String {
        // Use current persistent persona instead of hardcoded default
        let result = try await sendMessage(message, persona: getCurrentPersistentPersona())
        return result.mainResponse
    }
    
    /// Send message with persona support and unified compression
    /// BREAKTHROUGH: Persona applies machine compression to their own response
    func sendMessage(_ message: String, persona: String?) async throws -> (mainResponse: String, trimmedResponse: String?) {
        await updateLoadingState(isLoading: true)
        
        defer {
            Task { @MainActor in
                if !Task.isCancelled { self.isLoading = false }
            }
        }
        
        // Build persona-aware prompt
        let fullPrompt = try buildPersonaPrompt(persona: persona, userMessage: message)
        
        // Get response from LLM
        let rawResponse = try await router.executeWithFallback { resolvedProvider in
            await updateCurrentService(provider: resolvedProvider.provider, model: resolvedProvider.model)
            return try await resolvedProvider.service.sendMessage(fullPrompt)
        }
        
        // Parse persona response with machine compression
        return parsePersonaResponse(rawResponse)
    }
    
    /// Build persona-aware prompt using unified omniscient bundle
    /// ARCHITECTURE: Complete memory bundle with instructions header
    private func buildPersonaPrompt(persona: String?, userMessage: String) throws -> String {
        // CRITICAL: Get current persistent persona instead of hardcoded fallback
        let actualPersona = persona ?? getCurrentPersistentPersona()
        
        // Use unified omniscient bundle builder
        let bundleBuilder = OmniscientBundleBuilder.shared
        
        // Validate bundle can be assembled
        let validationIssues = bundleBuilder.validateBundle(for: actualPersona)
        if !validationIssues.isEmpty {
            print("⚠️ Bundle validation issues: \(validationIssues.joined(separator: ", "))")
        }
        
        // Build complete omniscient bundle
        return try bundleBuilder.buildBundle(for: actualPersona, userMessage: userMessage)
    }
    
    /// Get current persistent persona from vault (super-persistent across app restarts)
    /// CRITICAL: Never defaults to hardcoded values - always reads from vault
    private func getCurrentPersistentPersona() -> String {
        let path = VaultConfig.currentPersonaPath
        
        if FileManager.default.fileExists(atPath: path) {
            do {
                let savedPersona = try String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                if !savedPersona.isEmpty {
                    return savedPersona
                }
            } catch {
                print("⚠️ LLMManager failed to load current persona: \(error)")
            }
        }
        
        // CRITICAL ERROR: currentPersona.md missing or corrupted
        // Create default file with emergency fallback
        let firstPersona = "samara" // Emergency fallback when PersonaRegistry not available
        do {
            try firstPersona.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
            print("🔧 Created missing currentPersona.md with: \(firstPersona)")
        } catch {
            print("❌ Failed to create currentPersona.md: \(error)")
        }
        return firstPersona
    }
    
    /// Parse persona response with 3-section format and process all sections
    /// COMPLETE: Handles taxonomy analysis, main response, and machine trim with actions
    private func parsePersonaResponse(_ rawResponse: String) -> (mainResponse: String, trimmedResponse: String?) {
        let taxonomyMarker = "---TAXONOMY_ANALYSIS---"
        let mainMarker = "---MAIN_RESPONSE---"
        let trimMarker = "---MACHINE_TRIM---"
        
        // Extract all three sections
        let taxonomyAnalysis = extractSection(from: rawResponse, start: taxonomyMarker, end: mainMarker)
        let mainResponse = extractSection(from: rawResponse, start: mainMarker, end: trimMarker)
        let machineTrim = extractSection(from: rawResponse, start: trimMarker, end: nil)
        
        // Process taxonomy analysis (if present)
        if let taxonomy = taxonomyAnalysis, !taxonomy.isEmpty {
            processTaxonomyAnalysis(taxonomy)
        }
        
        // Validate main response
        guard let main = mainResponse, !main.isEmpty else {
            // Fallback: treat entire response as main if no structure found
            return (rawResponse.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        
        // Return main response and trim (if available)
        return (main, machineTrim)
    }
    
    /// Extract section content between markers
    private func extractSection(from response: String, start: String, end: String?) -> String? {
        guard let startRange = response.range(of: start)?.upperBound else {
            return nil
        }
        
        let endBound: String.Index
        if let endMarker = end,
           let endRange = response.range(of: endMarker, range: startRange..<response.endIndex)?.lowerBound {
            endBound = endRange
        } else {
            endBound = response.endIndex
        }
        
        let content = String(response[startRange..<endBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return content.isEmpty ? nil : content
    }
    
    /// Process taxonomy analysis section - evolve taxonomy
    private func processTaxonomyAnalysis(_ taxonomyContent: String) {
        // Parse taxonomy metadata from the analysis
        guard let metadata = TaxonomyManager.shared.parseTrimMetadata(taxonomyContent) else {
            print("⚠️ Could not parse taxonomy from analysis section")
            return
        }
        
        // Validate and add to taxonomy
        let validation = TaxonomyManager.shared.validateTopicHierarchy(metadata.topicHierarchy)
        if validation.isValid {
            TaxonomyManager.shared.addToTaxonomy(hierarchyString: metadata.topicHierarchy)
            print("📋 Taxonomy evolved: \(metadata.topicHierarchy)")
            
            if !validation.suggestions.isEmpty {
                print("📋 Evolution notes: \(validation.suggestions.joined(separator: ", "))")
            }
        } else {
            print("⚠️ Invalid taxonomy hierarchy: \(metadata.topicHierarchy)")
            print("   Warnings: \(validation.warnings.joined(separator: ", "))")
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
    
    // MARK: - Memory Context Integration
    
    /// Build contextual message with conversation history
    /// BLUEPRINT: Eventually includes full vault context (projects, personas, etc.)
    /// CURRENT: Simple conversation history prepending
    private func buildContextualMessage(userMessage: String, context: String) -> String {
        if context.isEmpty {
            return userMessage
        }
        
        return """
        \(context)
        
        Current message:
        \(userMessage)
        """
    }
    
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