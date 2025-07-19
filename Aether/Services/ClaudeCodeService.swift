//
//  ClaudeCodeService.swift
//  Aether
//
//  Connects to Claude Code API for authentic Claude persona responses

import Foundation

class ClaudeCodeService: ObservableObject, LLMServiceProtocol {
    private let configuration = LLMConfiguration()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Configuration
    
    /// Get Claude Code provider and model configuration
    private func getProviderConfig() -> (provider: LLMProvider, model: LLMModel)? {
        guard let provider = configuration.getProvider("claude-code"),
              let model = configuration.getModel(provider: "claude-code", model: "claude-code-sonnet") else {
            return nil
        }
        return (provider, model)
    }
    
    /// Validate API key availability
    private func validateConfiguration() throws -> (LLMProvider, LLMModel, String) {
        guard let (provider, model) = getProviderConfig() else {
            throw LLMServiceError.missingAPIKey("Claude Code configuration not loaded")
        }
        
        let apiKey = configuration.getApiKey(for: "claude-code")
        guard !apiKey.isEmpty else {
            throw LLMServiceError.missingAPIKey("Claude Code API key not configured")
        }
        
        return (provider, model, apiKey)
    }
    
    // MARK: - Request Building
    
    /// Build HTTP request for Claude Code API using shared infrastructure
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
    
    /// Send message to Claude Code API and return complete response
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
    
    /// Stream message response from Claude Code API
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