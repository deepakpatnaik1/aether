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
    
    // BLUEPRINT: Memory integration for omniscient context
    private let memoryIndex = ContextMemoryIndex.shared
    
    // PERSONA SYSTEM: PersonaRegistry dependency for behavioral rules
    private var personaRegistry: PersonaRegistry?
    
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
    
    /// Send message with automatic provider fallback (legacy, no persona)
    /// BLUEPRINT: Eventually includes full vault context (omniscient memory scope)
    /// CURRENT: Includes conversation history for continuity
    func sendMessage(_ message: String) async throws -> String {
        // Default to "aether" persona for backward compatibility
        let result = try await sendMessage(message, persona: "aether")
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
    
    /// Build persona-aware prompt with compression instructions
    /// ARCHITECTURE: Persona responds authentically, then applies machine compression to own work
    private func buildPersonaPrompt(persona: String?, userMessage: String) throws -> String {
        // Get conversation context from memory
        let conversationContext = memoryIndex.getConversationContext()
        
        // Load persona behavioral rules (if specified)
        let personaRules = getPersonaBehavioralRules(for: persona)
        
        // Load machine compression methodology
        let compressionRules = try loadCompressionRules()
        
        // Build unified prompt where persona compresses their own response
        return """
        \(conversationContext.isEmpty ? "" : "CONVERSATION CONTEXT:\n\(conversationContext)\n\n")
        
        \(personaRules.isEmpty ? "" : "PERSONA BEHAVIORAL RULES:\n\(personaRules)\n\n")
        
        USER MESSAGE:
        \(userMessage)
        
        RESPONSE INSTRUCTIONS:
        
        You must complete TWO SEPARATE tasks:
        
        STEP 1: Respond authentically as the persona
        - Follow your cognitive role and thinking lens completely
        - Give your natural response with complete personality
        - This is your authentic voice responding to Boss
        
        STEP 2: Apply machine compression (completely separate task)
        - Compress the ENTIRE conversation turn (Boss's message + your response from Step 1)
        - Use the compression methodology provided below
        - This is archival work, not response work
        
        Format your response EXACTLY as shown:
        
        ---MAIN_RESPONSE---
        [Your complete, authentic response as the persona - full personality, natural length]
        
        ---MACHINE_TRIM---
        [Compress the complete conversation turn (Boss message + your main response above) using methodology below]
        
        COMPRESSION METHODOLOGY:
        \(compressionRules)
        
        CRITICAL: Step 1 and Step 2 are completely separate. Your main response should be authentic and natural. The compression is a separate archival task applied to the complete conversational exchange.
        """
    }
    
    /// Inject PersonaRegistry dependency
    func setPersonaRegistry(_ registry: PersonaRegistry) {
        self.personaRegistry = registry
    }
    
    /// Load persona behavioral rules from PersonaRegistry
    private func getPersonaBehavioralRules(for persona: String?) -> String {
        guard let persona = persona,
              let registry = personaRegistry else { return "" }
        
        // Load behavioral rules from PersonaRegistry
        return registry.behaviorRules(for: persona) ?? ""
    }
    
    /// Load machine compression methodology from vault tools
    /// ROBUST: Handles missing compression file gracefully
    private func loadCompressionRules() throws -> String {
        let compressionPath = "\(VaultConfig.vaultRoot)/playbook/tools/machine-trim.md"
        
        do {
            let content = try String(contentsOfFile: compressionPath, encoding: .utf8)
            print("✅ Loaded machine compression methodology")
            return content
        } catch {
            print("❌ Failed to load compression methodology: \(error)")
            // Fallback to basic compression instructions
            return """
            Basic compression instructions:
            1. Preserve speaker identity and key points
            2. Remove filler words and redundancy
            3. Maintain semantic meaning
            4. Format as structured dialogue
            """
        }
    }
    
    /// Parse persona response with machine compression into main response and trimmed version
    /// ROBUST: Handles various response formats and edge cases
    private func parsePersonaResponse(_ rawResponse: String) -> (mainResponse: String, trimmedResponse: String?) {
        let mainMarker = "---MAIN_RESPONSE---"
        let trimMarker = "---MACHINE_TRIM---"
        
        // Find main response marker
        guard let mainStart = rawResponse.range(of: mainMarker)?.upperBound else {
            // No structured response - return as main response only
            print("⚠️ No structured response markers found - using raw response")
            return (rawResponse.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        
        // Find trim marker
        if let trimStart = rawResponse.range(of: trimMarker)?.upperBound {
            // Both sections present - extract each cleanly
            let mainEnd = rawResponse.range(of: trimMarker, range: mainStart..<rawResponse.endIndex)?.lowerBound ?? rawResponse.endIndex
            
            let mainResponse = String(rawResponse[mainStart..<mainEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let trimmedResponse = String(rawResponse[trimStart...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate both sections have content
            guard !mainResponse.isEmpty else {
                print("⚠️ Main response section is empty")
                return (rawResponse.trimmingCharacters(in: .whitespacesAndNewlines), nil)
            }
            
            guard !trimmedResponse.isEmpty else {
                print("⚠️ Trimmed response section is empty")
                return (mainResponse, nil)
            }
            
            print("✅ Successfully parsed persona response with machine compression")
            return (mainResponse, trimmedResponse)
            
        } else {
            // Only main response marker found
            let mainResponse = String(rawResponse[mainStart...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("⚠️ Only main response found - no trim section")
            return (mainResponse, nil)
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