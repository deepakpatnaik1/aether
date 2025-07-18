//
//  OmniscientBundleBuilder.swift
//  Aether
//
//  Unified omniscient memory bundle assembly for LLM requests
//
//  BLUEPRINT SECTION: 🚨 Core - Omniscient Memory Bundle
//  ====================================================
//
//  RESPONSIBILITIES:
//  - Single source of truth for omniscient bundle assembly
//  - Load instructions-to-llm.md as header
//  - Assemble boss/ + current_persona/ + tools/ + journal/ folders
//  - Real-time journal loading (not cached)
//  - Provide complete memory context for LLM requests
//
//  DESIGN PRINCIPLES:
//  - Single Source of Truth: One place for bundle assembly
//  - Real-Time Loading: Always fresh journal content
//  - Proper Order: Instructions first, then context, then user message
//  - Fail-Fast: Clear errors when files missing

import Foundation

class OmniscientBundleBuilder: ObservableObject {
    
    static let shared = OmniscientBundleBuilder()
    private let taxonomyManager = TaxonomyManager.shared
    
    private init() {}
    
    // MARK: - Main Bundle Assembly
    
    /// Build complete omniscient bundle for LLM request
    /// ORDER: instructions-to-llm.md → boss/ → current_persona/ → tools/ → journal/
    func buildBundle(for persona: String, userMessage: String) throws -> String {
        var bundleSections: [String] = []
        
        // 1. INSTRUCTIONS (Header)
        let instructions = try loadInstructions()
        bundleSections.append(instructions)
        
        // 2. BOSS CONTEXT
        let bossContext = try loadBossContext()
        if !bossContext.isEmpty {
            bundleSections.append("=== BOSS CONTEXT ===")
            bundleSections.append(bossContext)
        }
        
        // 3. CURRENT PERSONA CONTEXT
        let personaContext = try loadPersonaContext(persona: persona)
        if !personaContext.isEmpty {
            bundleSections.append("=== PERSONA COGNITIVE STRATEGY ===")
            bundleSections.append(personaContext)
        }
        
        // 4. TOOLS CONTEXT
        let toolsContext = try loadToolsContext()
        if !toolsContext.isEmpty {
            bundleSections.append("=== TOOLS CONTEXT ===")
            bundleSections.append(toolsContext)
        }
        
        // 5. JOURNAL CONTEXT (Real-time loading)
        let journalContext = loadJournalContext()
        if !journalContext.isEmpty {
            bundleSections.append("=== CONVERSATION HISTORY ===")
            bundleSections.append(journalContext)
        }
        
        // 6. TAXONOMY CONTEXT
        let taxonomyContext = taxonomyManager.getTaxonomyContext()
        bundleSections.append("=== TAXONOMY STRUCTURE ===")
        bundleSections.append(taxonomyContext)
        
        // 7. USER MESSAGE
        bundleSections.append("=== USER MESSAGE ===")
        bundleSections.append(userMessage)
        
        return bundleSections.joined(separator: "\n\n")
    }
    
    // MARK: - Individual Context Loaders
    
    /// Load instructions-to-llm.md as bundle header
    private func loadInstructions() throws -> String {
        let instructionsPath = "\(VaultConfig.vaultRoot)/playbook/tools/instructions-to-llm.md"
        
        guard FileManager.default.fileExists(atPath: instructionsPath) else {
            throw BundleError.instructionsNotFound
        }
        
        return try String(contentsOfFile: instructionsPath, encoding: .utf8)
    }
    
    /// Load boss context from boss/ folder
    private func loadBossContext() throws -> String {
        let bossPath = "\(VaultConfig.vaultRoot)/playbook/boss"
        return try loadAllMarkdownFiles(from: bossPath, sectionName: "BOSS")
    }
    
    /// Load current persona context from personas/[persona]/ folder
    private func loadPersonaContext(persona: String) throws -> String {
        let personaPath = "\(VaultConfig.vaultRoot)/playbook/personas/\(persona.capitalized)"
        return try loadAllMarkdownFiles(from: personaPath, sectionName: "PERSONA")
    }
    
    /// Load tools context from tools/ folder
    private func loadToolsContext() throws -> String {
        let toolsPath = "\(VaultConfig.vaultRoot)/playbook/tools"
        return try loadAllMarkdownFiles(from: toolsPath, sectionName: "TOOLS")
    }
    
    /// Load journal context from journal/ folder (real-time)
    /// CRITICAL: Always loads fresh content, never cached
    private func loadJournalContext() -> String {
        let journalPath = VaultConfig.journalPath
        
        do {
            return try loadAllMarkdownFiles(from: journalPath, sectionName: "JOURNAL")
        } catch {
            // Journal may be empty (starting fresh) - this is normal
            return ""
        }
    }
    
    // MARK: - File Loading Utilities
    
    /// Load all .md files from a directory and concatenate
    private func loadAllMarkdownFiles(from folderPath: String, sectionName: String) throws -> String {
        guard FileManager.default.fileExists(atPath: folderPath) else {
            // Some folders may not exist yet - return empty rather than error
            return ""
        }
        
        let fileManager = FileManager.default
        let allFiles = try fileManager.contentsOfDirectory(atPath: folderPath)
        let markdownFiles = allFiles.filter { $0.hasSuffix(".md") }.sorted()
        
        guard !markdownFiles.isEmpty else {
            return ""
        }
        
        var allContent: [String] = []
        
        for fileName in markdownFiles {
            let filePath = "\(folderPath)/\(fileName)"
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                allContent.append("--- FILE: \(fileName) ---")
                allContent.append(content)
                allContent.append("") // Empty line separator
            } catch {
                print("⚠️ Could not read file \(fileName): \(error)")
            }
        }
        
        return allContent.joined(separator: "\n")
    }
    
    // MARK: - Bundle Validation
    
    /// Validate that bundle can be assembled for persona
    func validateBundle(for persona: String) -> [String] {
        var issues: [String] = []
        
        // Check instructions
        let instructionsPath = "\(VaultConfig.vaultRoot)/playbook/tools/instructions-to-llm.md"
        if !FileManager.default.fileExists(atPath: instructionsPath) {
            issues.append("Missing instructions-to-llm.md")
        }
        
        // Check persona exists
        let personaPath = "\(VaultConfig.vaultRoot)/playbook/personas/\(persona.capitalized)"
        if !FileManager.default.fileExists(atPath: personaPath) {
            issues.append("Persona folder not found: \(persona)")
        }
        
        // Check persona has content
        let personaFile = "\(personaPath)/\(persona.capitalized).md"
        if !FileManager.default.fileExists(atPath: personaFile) {
            issues.append("Persona file not found: \(persona).md")
        }
        
        return issues
    }
}

// MARK: - Error Types

enum BundleError: LocalizedError {
    case instructionsNotFound
    case personaNotFound(String)
    case invalidPersonaFile(String)
    
    var errorDescription: String? {
        switch self {
        case .instructionsNotFound:
            return "instructions-to-llm.md not found in tools folder"
        case .personaNotFound(let persona):
            return "Persona folder not found: \(persona)"
        case .invalidPersonaFile(let persona):
            return "Invalid persona file: \(persona).md"
        }
    }
}