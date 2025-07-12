//
//  LLMServiceProtocol.swift
//  Aether
//
//  Unified interface for all LLM service implementations
//
//  IMPLEMENTATION: Service Abstraction Layer
//  ========================================
//
//  DESIGN PRINCIPLE: Services are interchangeable
//  - All LLM services implement same interface
//  - Provider-agnostic routing via ModelRouter
//  - Dynamic service discovery and swapping
//
//  INTERFACE REQUIREMENTS:
//  - Async message sending with error handling
//  - Observable loading states for UI binding
//  - Consistent error reporting across providers
//
//  USAGE:
//  - LLMManager routes to any conforming service
//  - New providers added by implementing protocol
//  - No changes needed to routing or UI layers

import Foundation

protocol LLMServiceProtocol: ObservableObject {
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    
    func sendMessage(_ message: String) async throws -> String
    func streamMessage(_ message: String) async throws -> AsyncStream<String>
}