//
//  OpenAIService.swift
//  Aether
//
//  OpenAI GPT-4o service implementation for production chat
//
//  BLUEPRINT SECTION: 🚨 Services - OpenAIService
//  ===============================================
//
//  DESIGN PRINCIPLES:
//  - No Hardcoding: All configuration from LLMProviders.json
//  - Modularity: Clean HTTP request handling with shared components
//  - Separation of Concerns: Configuration, request building, response parsing separated
//  - No Redundancy: Shares HTTPRequestBuilder and LLMResponseParser with FireworksService
//
//  OPENAI SPECIALIZATION:
//  - Powers GPT-4o model for reliable production responses
//  - Primary fallback when Fireworks unavailable
//  - Future: Will serve as general conversation backbone
//
//  CURRENT SCOPE: Basic chat interface
//  - Non-streaming responses for reliability
//  - Streaming infrastructure ready but disabled due to chunking issues

import Foundation

class OpenAIService: ObservableObject, LLMServiceProtocol {
    private let configuration = LLMConfiguration()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Configuration
    
    /// Get OpenAI provider and model configuration
    private func getProviderConfig() -> (provider: LLMProvider, model: LLMModel)? {
        guard let provider = configuration.getProvider("openai"),
              let model = configuration.getModel(provider: "openai", model: "gpt-4.1-mini") else {
            return nil
        }
        return (provider, model)
    }
    
    /// Validate API key availability
    private func validateConfiguration() throws -> (LLMProvider, LLMModel, String) {
        guard let (provider, model) = getProviderConfig() else {
            throw LLMServiceError.missingAPIKey("OpenAI configuration not loaded")
        }
        
        let apiKey = configuration.getApiKey(for: "openai")
        guard !apiKey.isEmpty else {
            throw LLMServiceError.missingAPIKey("OpenAI API key not configured")
        }
        
        return (provider, model, apiKey)
    }
    
    // MARK: - Request Building
    
    /// Build HTTP request for OpenAI API using shared infrastructure
    private func buildRequest(provider: LLMProvider, model: LLMModel, apiKey: String, message: String, streaming: Bool = false) throws -> URLRequest {
        return try HTTPRequestBuilder.buildChatCompletionRequest(
            baseURL: provider.baseURL,
            apiKey: apiKey,
            model: model,
            message: message,
            streaming: streaming
        )
    }
    
    // MARK: - LLMServiceProtocol Implementation
    
    /// Send message to OpenAI API and return complete response
    func sendMessage(_ message: String) async throws -> String {
        let (provider, model, apiKey) = try validateConfiguration()
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        let request = try buildRequest(provider: provider, model: model, apiKey: apiKey, message: message)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try LLMResponseParser.validateHTTPResponse(response)
        return try LLMResponseParser.parseCompletionResponse(data)
    }
    
    /// Stream message response from OpenAI API (infrastructure ready, currently disabled)
    func streamMessage(_ message: String) async throws -> AsyncStream<String> {
        let (provider, model, apiKey) = try validateConfiguration()
        
        return AsyncStream(String.self) { continuation in
            Task {
                do {
                    await MainActor.run {
                        isLoading = true
                        errorMessage = nil
                    }
                    
                    let request = try buildRequest(provider: provider, model: model, apiKey: apiKey, message: message, streaming: true)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    try LLMResponseParser.validateHTTPResponse(response)
                    
                    // Use shared streaming parser
                    let contentStream = LLMResponseParser.processStreamingResponse(bytes)
                    for await content in contentStream {
                        continuation.yield(content)
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish()
                }
                
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}