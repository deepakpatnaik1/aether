//
//  FireworksService.swift
//  Aether
//
//  Fireworks AI service implementation for high-context LLM requests
//
//  BLUEPRINT SECTION: 🚨 Services - FireworksService
//  ================================================
//
//  DESIGN PRINCIPLES:
//  - No Hardcoding: All configuration from LLMProviders.json
//  - Modularity: Clean HTTP request handling with focused methods
//  - Separation of Concerns: Configuration, request building, response parsing separated
//  - No Redundancy: Shared patterns with OpenAIService minimized through clear structure
//
//  FIREWORKS SPECIALIZATION:
//  - Powers Llama 4 Maverick model with 1M token context window
//  - High-performance inference for omniscient memory architecture
//  - Future: Will power Vanessa, Gunnar, Vlad, Samara personas
//
//  CURRENT SCOPE: Basic chat interface
//  - Non-streaming responses for reliability
//  - Streaming infrastructure ready but disabled due to chunking issues

import Foundation

class FireworksService: ObservableObject, LLMServiceProtocol {
    private let configuration = LLMConfiguration()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Configuration
    
    /// Get Fireworks provider and model configuration
    private func getProviderConfig() -> (provider: LLMProvider, model: LLMModel)? {
        guard let provider = configuration.getProvider("fireworks"),
              let model = configuration.getModel(provider: "fireworks", model: "llama-maverick") else {
            return nil
        }
        return (provider, model)
    }
    
    /// Validate API key availability
    private func validateConfiguration() throws -> (LLMProvider, LLMModel, String) {
        guard let (provider, model) = getProviderConfig() else {
            throw LLMServiceError.missingAPIKey("Fireworks configuration not loaded")
        }
        
        let apiKey = configuration.getApiKey(for: "fireworks")
        guard !apiKey.isEmpty else {
            throw LLMServiceError.missingAPIKey("Fireworks API key not configured")
        }
        
        return (provider, model, apiKey)
    }
    
    // MARK: - Request Building
    
    /// Build HTTP request for Fireworks API using shared infrastructure
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
    
    /// Send message to Fireworks API and return complete response
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
    
    /// Stream message response from Fireworks API (infrastructure ready, currently disabled)
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

// MARK: - Service Error Types

enum LLMServiceError: Error {
    case missingAPIKey(String)
    case invalidResponse
    case httpError(Int)
    case requestError(Error)
    case parsingError(Error)
    
    var localizedDescription: String {
        switch self {
        case .missingAPIKey(let message):
            return message
        case .invalidResponse:
            return "Invalid response from LLM service"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .requestError(let error):
            return "Request error: \(error.localizedDescription)"
        case .parsingError(let error):
            return "Parsing error: \(error.localizedDescription)"
        }
    }
}