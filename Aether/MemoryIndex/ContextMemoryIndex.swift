//
//  ContextMemoryIndex.swift
//  Aether
//
//  Semantic Memory Consolidation Engine — High-Context Omniscient Architecture
//
//  BLUEPRINT SECTION: 🚨 MemoryIndex - ContextMemoryIndex
//  ====================================================
//
//  BLUEPRINT VISION: Loads entire vault by default, compiles full working memory across all .md sources
//  CURRENT IMPLEMENTATION: Boss profile + conversation history provider for LLM omniscient context
//  ACHIEVEMENTS TODAY: ✅ Boss profile integration for persona-aware conversations
//  FUTURE: Full omniscient memory scope with semantic consolidation, Samara's threader role
//
//  RESPONSIBILITIES:
//  - Provide conversation context for LLM requests
//  - Load and organize memory for AI responses
//  - Foundation for future semantic consolidation
//
//  DESIGN PRINCIPLE:
//  "The system assumes omniscient memory scope. Memory is never lost — only intelligently consolidated."

import Foundation

class ContextMemoryIndex: ObservableObject {
    
    static let shared = ContextMemoryIndex()
    
    private let vaultLoader = VaultLoader.shared
    
    private init() {}
    
    // MARK: - Memory Context (Current Implementation)
    
    /// Get conversation context for LLM requests
    /// BLUEPRINT: Eventually compiles full working memory across all .md sources (journal/, projects/, persona definitions, boss profile, strategic documents)
    /// ACHIEVEMENT TODAY: ✅ Boss profile integration - AI now understands Boss's role and authority
    /// CURRENT: Boss profile + conversation history formatted for omniscient context
    func getConversationContext() -> String {
        let bossProfile = vaultLoader.loadBossProfile()
        let messages = vaultLoader.loadConversationHistory()
        
        var contextParts: [String] = []
        
        // BLUEPRINT: Boss profile is part of omniscient memory
        // ACHIEVEMENT: ✅ Boss identity now loaded into every LLM context
        if !bossProfile.isEmpty {
            contextParts.append("""
            Boss Profile:
            
            \(bossProfile)
            """)
        }
        
        // Include conversation history if available
        if !messages.isEmpty {
            let conversationText = messages.map { message in
                "\(message.author): \(message.content)"
            }.joined(separator: "\n\n")
            
            contextParts.append("""
            Previous conversation:
            
            \(conversationText)
            """)
        }
        
        return contextParts.joined(separator: "\n\n---\n\n")
    }
    
    /// Get full conversation history as ChatMessage array
    /// CURRENT: Direct pass-through to VaultLoader
    /// BLUEPRINT: Eventually includes all vault sources with intelligent consolidation
    func getConversationHistory() -> [ChatMessage] {
        return vaultLoader.loadConversationHistory()
    }
    
    // MARK: - Memory Persistence
    
    /// Save conversation state to vault
    /// CURRENT: Simple pass-through to VaultLoader
    /// BLUEPRINT: Eventually triggers semantic consolidation when memory grows large
    func saveConversationHistory(_ messages: [ChatMessage]) {
        vaultLoader.saveConversationHistory(messages)
    }
    
    // MARK: - Future Blueprint Implementation
    
    // TODO: Load entire vault by default (omniscient memory scope)
    // TODO: Compile full working memory across all .md sources:
    //       - Trimmed conversation history (journal/)
    //       - Project files (projects/)
    //       - Persona definitions (playbook/persona/)
    //       - Boss profile (boss.md)
    //       - Strategic documents
    // TODO: Samara's Threader Role:
    //       - Trigger semantic consolidation when memory grows large
    //       - Collapse resolved topics into single compact .md files
    //       - Reduce 7 interwoven trims → 1 consolidated narrative
    //       - Remove dead-end decisions and conversational detours
    //       - Structured forgetting, not data loss
    // TODO: Never truncate or delete — only consolidate intelligently
}