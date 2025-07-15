//
//  VaultLoader.swift
//  Aether
//
//  Loads and maintains vault content in memory
//
//  BLUEPRINT SECTION: 🚨 MemoryIndex - VaultLoader
//  ==============================================
//
//  BLUEPRINT VISION: Monitors vault filesystem, loads markdown files, handles hot-reload
//  CURRENT IMPLEMENTATION: Conversation persistence + Boss profile loading for omniscient memory
//  ACHIEVEMENTS TODAY: ✅ Boss profile integration, ✅ Superjournal directory creation
//  FUTURE: Full vault monitoring, file watching, memory deduplication, intelligent consolidation
//
//  RESPONSIBILITIES:
//  - Load conversation history from vault
//  - Save new messages to persistent storage
//  - Handle directory creation as needed
//  - Foundation for future vault monitoring

import Foundation

class VaultLoader: ObservableObject {
    
    static let shared = VaultLoader()
    
    private init() {
        // CURRENT: Ensure vault directories exist
        createVaultDirectoriesIfNeeded()
    }
    
    // MARK: - Conversation Persistence (Current Implementation)
    
    /// Load Boss profile from vault
    /// BLUEPRINT: Part of omniscient memory - Boss profile loaded into context
    /// ACHIEVEMENT TODAY: ✅ Successfully integrated Boss identity into AI memory system
    /// PURPOSE: AI understands Boss's role, authority, and relationship with persona team
    func loadBossProfile() -> String {
        let filePath = VaultConfig.bossProfilePath
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("📖 No Boss profile found at \(filePath)")
            return ""
        }
        
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            print("📖 Loaded Boss profile from \(filePath)")
            return content
        } catch {
            print("❌ Failed to load Boss profile: \(error)")
            return ""
        }
    }
    
    /// Load conversation history from vault
    /// BLUEPRINT: Eventually loads all markdown files into structured memory
    /// CURRENT: Simple conversation.md file loading
    func loadConversationHistory() -> [ChatMessage] {
        let filePath = VaultConfig.conversationFilePath
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("📖 No conversation history found at \(filePath)")
            return []
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let messages = try JSONDecoder().decode([ChatMessage].self, from: data)
            print("📖 Loaded \(messages.count) messages from conversation history")
            return messages
        } catch {
            print("❌ Failed to load conversation history: \(error)")
            return []
        }
    }
    
    /// Save conversation history to vault
    /// BLUEPRINT: Eventually handles complex markdown file operations
    /// CURRENT: Simple JSON serialization to conversation.md
    func saveConversationHistory(_ messages: [ChatMessage]) {
        let filePath = VaultConfig.conversationFilePath
        
        do {
            let data = try JSONEncoder().encode(messages)
            try data.write(to: URL(fileURLWithPath: filePath))
            print("💾 Saved \(messages.count) messages to conversation history")
        } catch {
            print("❌ Failed to save conversation history: \(error)")
        }
    }
    
    // MARK: - Vault Management
    
    /// Create vault directory structure if it doesn't exist
    /// BLUEPRINT: Full aetherVault/ folder structure
    /// ACHIEVEMENT TODAY: ✅ Added superjournal/ directory for complete audit trail
    /// ENSURES: All required vault folders exist for memory and file operations
    private func createVaultDirectoriesIfNeeded() {
        let paths = [
            VaultConfig.vaultRoot,
            VaultConfig.journalPath,
            VaultConfig.projectsPath,
            VaultConfig.superJournalPath,
            VaultConfig.trashPath
        ]
        
        for path in paths {
            if !FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                    print("📁 Created vault directory: \(path)")
                } catch {
                    print("❌ Failed to create vault directory \(path): \(error)")
                }
            }
        }
    }
    
    // MARK: - Future Blueprint Implementation
    
    // TODO: Monitor vault filesystem for changes
    // TODO: Load markdown files into structured memory  
    // TODO: Handle file watching and hot-reload
    // TODO: Manage memory deduplication and intelligent consolidation
    // TODO: Never truncate or delete — only organize and consolidate
}