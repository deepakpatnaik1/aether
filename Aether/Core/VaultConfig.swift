//
//  VaultConfig.swift
//  Aether
//
//  Configurable vault location and paths
//
//  BLUEPRINT SECTION: 🚨 Core - VaultConfig
//  =======================================
//
//  BLUEPRINT VISION: Full configurable vault system with aetherVault/ structure
//  CURRENT IMPLEMENTATION: Complete vault path management for memory and file operations
//  ACHIEVEMENTS TODAY: Added Boss profile integration and superjournal auto-save paths
//
//  RESPONSIBILITIES:
//  - Single source of truth for all vault paths
//  - Enable relocation and flexibility
//  - Support full aetherVault folder structure (journal/, projects/, superjournal/, trash/)
//  - Boss profile path management for persona integration
//  - Superjournal path management for complete audit trail
//
//  SEPARATION OF CONCERNS:
//  ✅ This file ONLY manages paths - no file I/O, no business logic
//  ✅ Other components reference these paths for consistent vault structure
//  ✅ Single point of configuration for vault location changes

import Foundation

struct VaultConfig {
    // BLUEPRINT: Configurable vault location, not hardcoded
    // CURRENT: Simple hardcoded path for proof of concept
    static let vaultRoot: String = {
        return "/Users/d.patnaik/code/Aether/aetherVault"
    }()
    
    // BLUEPRINT FOLDER STRUCTURE: Complete aetherVault/ hierarchy
    
    /// Journal folder for Samara's trimmed conversation memories
    /// BLUEPRINT: "Semantic memory trims - Turn-YYYY-MM-DD-HHMM.md"
    /// FUTURE: Will contain compressed, searchable conversation history
    static let journalPath: String = {
        return "\(vaultRoot)/journal"
    }()
    
    /// Projects folder for project-specific memory and documentation
    /// BLUEPRINT: "Project-specific memory and documentation organized by project name"
    /// FUTURE: Contains project context, decisions, progress integrated with omniscient memory
    static let projectsPath: String = {
        return "\(vaultRoot)/projects"
    }()
    
    /// Superjournal folder for complete uncompressed audit logs
    /// BLUEPRINT: "FullTurn-YYYY-MM-DD-HHMM.md — Complete uncompressed logs for deep recall and debugging"
    /// ACHIEVEMENT TODAY: ✅ Fully implemented with auto-save functionality
    static let superJournalPath: String = {
        return "\(vaultRoot)/superjournal"
    }()
    
    /// Trash folder for non-destructive deletion
    /// BLUEPRINT: "Deleted-YYYY-MM-DD-filename.md — Safe, reversible deletion"
    /// FUTURE: Maintains data integrity with soft deletion system
    static let trashPath: String = {
        return "\(vaultRoot)/trash"
    }()
    
    // MEMORY SYSTEM FILES
    
    /// Conversation history file for UI persistence
    /// CURRENT: Simple JSON serialization of ChatMessage array
    /// NOTE: This is for UI conversation restoration, real memory comes from vault files
    static let conversationFilePath: String = {
        return "\(journalPath)/conversation.md"
    }()
    
    /// Boss profile for persona integration and omniscient memory
    /// BLUEPRINT: "Boss profile (boss.md)" - part of omniscient memory scope
    /// ACHIEVEMENT TODAY: ✅ Successfully integrated into memory context
    static let bossProfilePath: String = {
        return "\(vaultRoot)/playbook/boss/Boss.md"
    }()
    
    /// Temporary notes file (proof of concept)
    /// NOTE: Can be removed when full VaultWriter command system is complete
    static let notesFilePath: String = {
        return "/Users/d.patnaik/code/Aether/aether_notes.md"
    }()
}