//
//  LLMManager.swift
//  Aether
//
//  Coordinates AI responses across multiple language model providers

import Foundation

class LLMManager: ObservableObject {
    private let configuration = LLMConfiguration()
    private lazy var services: [String: any LLMServiceProtocol] = createServices()
    private lazy var router: ProviderRouter = ProviderRouter(configuration: configuration, services: services)
    
    @Published var isLoading = false
    @Published var currentService = "None"
    @Published var errorMessage: String?
    @Published var currentModel: String = ""
    
    init() {
        if let primaryRoute = configuration.getPrimaryRouting() {
            currentModel = getModelKey(provider: primaryRoute.provider, model: primaryRoute.model)
        }
    }
    
    // MARK: - Model Management
    
    /// Returns AI models available for user to select
    func getAvailableModels() -> [String] {
        guard let config = configuration.config else { return [] }
        
        var models: [String] = []
        for (providerKey, provider) in config.providers {
            let apiKey = configuration.getApiKey(for: providerKey)
            guard !apiKey.isEmpty else { continue }
            
            for (modelKey, _) in provider.models {
                models.append(getModelKey(provider: providerKey, model: modelKey))
            }
        }
        return models.sorted()
    }
    
    /// Changes which AI model the user is talking to
    func switchModel(to modelKey: String) {
        let (provider, model) = parseModelKey(modelKey)
        
        guard configuration.getModel(provider: provider, model: model) != nil else {
            print("❌ Model not found: \(modelKey)")
            return
        }
        
        currentModel = modelKey
        router.setPrimaryModel(provider: provider, model: model)
        
        print("✅ Switched to model: \(modelKey)")
    }
    
    /// Returns which AI model the user is currently using
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
    
    /// Determines routing behavior for Claude Code integration
    private func parseSelectedModel(_ modelKey: String) -> String? {
        let (provider, model) = parseModelKey(modelKey)
        if provider == "claude-code" {
            return "claude-code"
        }
        return nil
    }
    
    // MARK: - Service Discovery
    
    /// Sets up connections to available AI providers
    private func createServices() -> [String: any LLMServiceProtocol] {
        var serviceMap: [String: any LLMServiceProtocol] = [:]
        
        if configuration.getProvider("fireworks") != nil {
            serviceMap["fireworks"] = FireworksService()
        }
        if configuration.getProvider("openai") != nil {
            serviceMap["openai"] = OpenAIService()
        }
        if configuration.getProvider("claude-code") != nil {
            serviceMap["claude-code"] = ClaudeCodeService()
        }
        
        return serviceMap
    }
    
    // MARK: - Routing Coordination
    
    /// Sends user message and returns AI response
    func sendMessage(_ message: String) async throws -> String {
        let result = try await sendMessage(message, persona: getCurrentPersistentPersona())
        return result.mainResponse
    }
    
    /// Sends message to specific AI persona and returns response with compressed summary
    func sendMessage(_ message: String, persona: String?) async throws -> (mainResponse: String, trimmedResponse: String?) {
        await updateLoadingState(isLoading: true)
        
        defer {
            Task { @MainActor in
                if !Task.isCancelled { self.isLoading = false }
            }
        }
        
        let actualPersona = persona ?? getCurrentPersistentPersona()
        let fullPrompt = try buildPersonaPrompt(persona: persona, userMessage: message)
        
        let rawResponse = try await router.executeWithPersonaRouting(
            persona: actualPersona,
            selectedModel: parseSelectedModel(currentModel)
        ) { resolvedProvider in
            await updateCurrentService(provider: resolvedProvider.provider, model: resolvedProvider.model)
            return try await resolvedProvider.service.sendMessage(fullPrompt)
        }
        
        return parsePersonaResponse(rawResponse)
    }
    
    /// Builds complete context including conversation history and persona instructions
    private func buildPersonaPrompt(persona: String?, userMessage: String) throws -> String {
        let actualPersona = persona ?? getCurrentPersistentPersona()
        let bundleBuilder = OmniscientBundleBuilder.shared
        
        let validationIssues = bundleBuilder.validateBundle(for: actualPersona)
        if !validationIssues.isEmpty {
            print("⚠️ Bundle validation issues: \(validationIssues.joined(separator: ", "))")
        }
        
        return try bundleBuilder.buildBundle(for: actualPersona, userMessage: userMessage)
    }
    
    /// Returns which persona the user was last talking to
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
        
        let firstPersona = "samara"
        do {
            try firstPersona.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
            print("🔧 Created missing currentPersona.md with: \(firstPersona)")
        } catch {
            print("❌ Failed to create currentPersona.md: \(error)")
        }
        return firstPersona
    }
    
    /// Extracts main response and compressed summary from AI output
    private func parsePersonaResponse(_ rawResponse: String) -> (mainResponse: String, trimmedResponse: String?) {
        let taxonomyMarker = "---TAXONOMY_ANALYSIS---"
        let mainMarker = "---MAIN_RESPONSE---"
        let trimMarker = "---MACHINE_TRIM---"
        
        let taxonomyAnalysis = extractSection(from: rawResponse, start: taxonomyMarker, end: mainMarker)
        let mainResponse = extractSection(from: rawResponse, start: mainMarker, end: trimMarker)
        let machineTrim = extractSection(from: rawResponse, start: trimMarker, end: nil)
        
        if let taxonomy = taxonomyAnalysis, !taxonomy.isEmpty {
            processTaxonomyAnalysis(taxonomy)
        }
        
        guard let main = mainResponse, !main.isEmpty else {
            return (rawResponse.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        
        return (main, machineTrim)
    }
    
    /// Finds specific section within AI response
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
    
    /// Updates conversation categorization based on AI analysis
    private func processTaxonomyAnalysis(_ taxonomyContent: String) {
        guard let metadata = TaxonomyManager.shared.parseTrimMetadata(taxonomyContent) else {
            print("⚠️ Could not parse taxonomy from analysis section")
            return
        }
        
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
    
    
    /// Returns AI response as it's being generated word by word
    func streamMessage(_ message: String) async throws -> AsyncStream<String> {
        await updateLoadingState(isLoading: true)
        
        return try await router.executeWithFallback { resolvedProvider in
            await updateCurrentService(provider: resolvedProvider.provider, model: resolvedProvider.model)
            let stream = try await resolvedProvider.service.streamMessage(message)
            
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