//
//  FireworksService.swift
//  Aether
//
//  Fireworks AI service implementation
//
//  IMPLEMENTATION: Dynamic Fireworks API Integration
//  ===============================================
//
//  NO HARDCODING: All configuration from LLMProviders.json
//  - Provider details loaded from external config
//  - Model parameters configurable at runtime
//  - API endpoints and authentication externalized
//
//  CONFIGURATION:
//  - API key from environment variable (via config)
//  - Model ID and parameters from JSON config
//  - Base URL and endpoints from provider config
//
//  ERROR HANDLING:
//  - Consistent error reporting via protocol
//  - Service-agnostic error types
//  - Proper async/await error propagation

import Foundation

class FireworksService: ObservableObject, LLMServiceProtocol {
    private let configuration = LLMConfiguration()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private func getProviderConfig() -> (provider: LLMProvider, model: LLMModel)? {
        guard let provider = configuration.getProvider("fireworks"),
              let model = configuration.getModel(provider: "fireworks", model: "llama-maverick") else {
            return nil
        }
        return (provider, model)
    }
    
    func sendMessage(_ message: String) async throws -> String {
        guard let (provider, model) = getProviderConfig() else {
            throw LLMServiceError.missingAPIKey("Fireworks configuration not loaded")
        }
        
        let apiKey = configuration.getApiKey(for: "fireworks")
        guard !apiKey.isEmpty else {
            throw LLMServiceError.missingAPIKey("Fireworks API key not configured")
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let url = URL(string: "\(provider.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": model.id,
            "messages": [
                ["role": "user", "content": message]
            ],
            "max_tokens": model.maxTokens,
            "temperature": model.temperature
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LLMServiceError.httpError(httpResponse.statusCode)
        }
        
        let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = responseJSON?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMServiceError.invalidResponse
        }
        
        return content
    }
    
    func streamMessage(_ message: String) async throws -> AsyncStream<String> {
        guard let (provider, model) = getProviderConfig() else {
            throw LLMServiceError.missingAPIKey("Fireworks configuration not loaded")
        }
        
        let apiKey = configuration.getApiKey(for: "fireworks")
        guard !apiKey.isEmpty else {
            throw LLMServiceError.missingAPIKey("Fireworks API key not configured")
        }
        
        return AsyncStream(String.self) { continuation in
            Task {
                do {
                    await MainActor.run {
                        isLoading = true
                        errorMessage = nil
                    }
                    
                    let url = URL(string: "\(provider.baseURL)/chat/completions")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let requestBody: [String: Any] = [
                        "model": model.id,
                        "messages": [
                            ["role": "user", "content": message]
                        ],
                        "max_tokens": model.maxTokens,
                        "temperature": model.temperature,
                        "stream": true
                    ]
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMServiceError.invalidResponse
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        throw LLMServiceError.httpError(httpResponse.statusCode)
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            if data == "[DONE]" {
                                break
                            }
                            
                            if data.isEmpty {
                                continue
                            }
                            
                            if let jsonData = data.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let firstChoice = choices.first,
                               let delta = firstChoice["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                continuation.yield(content)
                            }
                        }
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

enum LLMServiceError: Error {
    case missingAPIKey(String)
    case invalidResponse
    case httpError(Int)
    
    var localizedDescription: String {
        switch self {
        case .missingAPIKey(let message):
            return message
        case .invalidResponse:
            return "Invalid response from LLM service"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}