//
//  HTTPRequestBuilder.swift
//  Aether
//
//  Reusable HTTP request construction for LLM service APIs
//
//  BLUEPRINT SECTION: 🚨 Services - Shared HTTP Infrastructure
//  ==========================================================
//
//  DESIGN PRINCIPLES:
//  - No Redundancy: Eliminates duplicated HTTP logic across all LLM services
//  - Modularity: Clean, focused request building with standard patterns
//  - Separation of Concerns: Pure HTTP construction, no business logic
//  - No Hardcoding: All endpoints and parameters externally provided
//
//  RESPONSIBILITIES:
//  - Construct HTTP requests for OpenAI-compatible APIs
//  - Handle authentication headers and content types
//  - Build request bodies for chat completions (streaming and non-streaming)
//  - Provide consistent error handling for request construction
//
//  USAGE:
//  - FireworksService uses for Llama API requests
//  - OpenAIService uses for GPT API requests
//  - Future: Any OpenAI-compatible service can reuse

import Foundation

struct HTTPRequestBuilder {
    
    // MARK: - Request Construction
    
    /// Build HTTP request for OpenAI-compatible chat completions API
    static func buildChatCompletionRequest(
        baseURL: String,
        apiKey: String,
        model: LLMModel,
        message: String,
        streaming: Bool = false
    ) throws -> URLRequest {
        
        let url = try buildURL(baseURL: baseURL, endpoint: "/chat/completions")
        var request = URLRequest(url: url)
        
        // HTTP method and headers
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Request body
        let requestBody = buildChatCompletionBody(
            model: model,
            message: message,
            streaming: streaming
        )
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        return request
    }
    
    // MARK: - URL Construction
    
    /// Build complete URL from base URL and endpoint
    private static func buildURL(baseURL: String, endpoint: String) throws -> URL {
        let urlString = baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw HTTPRequestError.invalidURL("Invalid URL: \(urlString)")
        }
        return url
    }
    
    // MARK: - Request Body Construction
    
    /// Build request body for chat completions API
    private static func buildChatCompletionBody(
        model: LLMModel,
        message: String,
        streaming: Bool
    ) -> [String: Any] {
        
        var requestBody: [String: Any] = [
            "model": model.id,
            "messages": [
                ["role": "user", "content": message]
            ],
            "max_tokens": model.maxTokens,
            "temperature": model.temperature
        ]
        
        if streaming {
            requestBody["stream"] = true
        }
        
        return requestBody
    }
    
    // MARK: - Multi-Message Support (Future Extension)
    
    /// Build request body for conversation with multiple messages
    static func buildConversationRequest(
        baseURL: String,
        apiKey: String,
        model: LLMModel,
        messages: [(role: String, content: String)],
        streaming: Bool = false
    ) throws -> URLRequest {
        
        let url = try buildURL(baseURL: baseURL, endpoint: "/chat/completions")
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestBody: [String: Any] = [
            "model": model.id,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": model.maxTokens,
            "temperature": model.temperature
        ]
        
        if streaming {
            requestBody["stream"] = true
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        return request
    }
    
    // MARK: - Request Validation
    
    /// Validate request parameters before construction
    static func validateRequestParameters(
        baseURL: String,
        apiKey: String,
        model: LLMModel,
        message: String
    ) throws {
        
        guard !baseURL.isEmpty else {
            throw HTTPRequestError.missingParameter("Base URL is required")
        }
        
        guard !apiKey.isEmpty else {
            throw HTTPRequestError.missingParameter("API key is required")
        }
        
        guard !model.id.isEmpty else {
            throw HTTPRequestError.missingParameter("Model ID is required")
        }
        
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HTTPRequestError.missingParameter("Message content is required")
        }
    }
}

// MARK: - HTTP Request Errors

enum HTTPRequestError: Error, LocalizedError {
    case invalidURL(String)
    case missingParameter(String)
    case serializationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let details):
            return "Invalid URL: \(details)"
        case .missingParameter(let parameter):
            return "Missing required parameter: \(parameter)"
        case .serializationError(let details):
            return "JSON serialization error: \(details)"
        }
    }
}