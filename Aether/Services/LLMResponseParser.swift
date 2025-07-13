//
//  LLMResponseParser.swift
//  Aether
//
//  Response parsing utilities for OpenAI-compatible LLM APIs
//
//  BLUEPRINT SECTION: 🚨 Services - Shared Response Processing
//  ==========================================================
//
//  DESIGN PRINCIPLES:
//  - No Redundancy: Eliminates duplicated parsing logic across LLM services
//  - Modularity: Clean response parsing with consistent error handling
//  - Separation of Concerns: Pure parsing logic, no business logic
//  - Reliability: Robust JSON parsing with informative error messages
//
//  RESPONSIBILITIES:
//  - Parse non-streaming chat completion responses
//  - Parse streaming Server-Sent Events (SSE) data
//  - Extract content from OpenAI-compatible response formats
//  - Provide consistent error handling for malformed responses
//
//  USAGE:
//  - FireworksService uses for Llama API response parsing
//  - OpenAIService uses for GPT API response parsing
//  - Future: Any OpenAI-compatible service can reuse

import Foundation

struct LLMResponseParser {
    
    // MARK: - Non-Streaming Response Parsing
    
    /// Parse complete chat completion response from OpenAI-compatible API
    static func parseCompletionResponse(_ data: Data) throws -> String {
        guard let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ResponseParsingError.invalidJSON("Failed to parse response as JSON")
        }
        
        guard let choices = responseJSON["choices"] as? [[String: Any]] else {
            throw ResponseParsingError.missingField("Missing 'choices' array in response")
        }
        
        guard let firstChoice = choices.first else {
            throw ResponseParsingError.missingField("Empty 'choices' array in response")
        }
        
        guard let message = firstChoice["message"] as? [String: Any] else {
            throw ResponseParsingError.missingField("Missing 'message' object in first choice")
        }
        
        guard let content = message["content"] as? String else {
            throw ResponseParsingError.missingField("Missing 'content' string in message")
        }
        
        return content
    }
    
    // MARK: - Streaming Response Parsing
    
    /// Parse Server-Sent Event line and extract content delta
    static func parseStreamingLine(_ line: String) -> String? {
        // Check for data: prefix
        guard line.hasPrefix("data: ") else { return nil }
        
        let data = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for stream termination
        if data == "[DONE]" { return nil }
        
        // Skip empty data
        if data.isEmpty { return nil }
        
        // Parse JSON delta
        return parseStreamingDelta(data)
    }
    
    /// Parse streaming delta from SSE data chunk
    private static func parseStreamingDelta(_ data: String) -> String? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let delta = firstChoice["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }
        
        return content
    }
    
    // MARK: - Response Validation
    
    /// Validate HTTP response status and headers
    static func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ResponseParsingError.invalidResponse("Response is not HTTP")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ResponseParsingError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Error Context Extraction
    
    /// Extract error details from API error response
    static func parseErrorResponse(_ data: Data) -> String {
        guard let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = errorJSON["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return "Unknown API error"
        }
        
        // Include error type if available
        if let type = error["type"] as? String {
            return "\(type): \(message)"
        }
        
        return message
    }
    
    // MARK: - Stream Processing Utilities
    
    /// Process async byte stream into parsed content chunks
    static func processStreamingResponse(_ bytes: URLSession.AsyncBytes) -> AsyncStream<String> {
        return AsyncStream(String.self) { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        if let content = parseStreamingLine(line) {
                            continuation.yield(content)
                        }
                        
                        // Check for termination signal
                        if line.hasPrefix("data: [DONE]") {
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Debugging Utilities
    
    /// Pretty print response JSON for debugging
    static func debugPrintResponse(_ data: Data) {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print("📄 API Response:\n\(prettyString)")
        } else {
            print("📄 Raw Response: \(String(data: data, encoding: .utf8) ?? "Invalid UTF-8")")
        }
    }
}

// MARK: - Response Parsing Errors

enum ResponseParsingError: Error, LocalizedError {
    case invalidJSON(String)
    case missingField(String)
    case invalidResponse(String)
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON(let details):
            return "Invalid JSON response: \(details)"
        case .missingField(let field):
            return "Missing required field: \(field)"
        case .invalidResponse(let details):
            return "Invalid response: \(details)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}