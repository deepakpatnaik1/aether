//
//  PersonaRegistry.swift
//  Aether
//
//  Source of Truth for All Persona Metadata
//
//  BLUEPRINT SECTION: 🚨 Core - PersonaRegistry
//  =======================================
//
//  BLUEPRINT VISION: Dynamic persona discovery and metadata management
//  CURRENT IMPLEMENTATION: Complete persona data layer with frontmatter parsing
//  ACHIEVEMENTS TODAY: Full persona folder scanning and behavioral rule loading
//
//  RESPONSIBILITIES:
//  - Traverse aetherVault/playbook/personas/ folders dynamically
//  - Parse [PersonaName].md files with YAML frontmatter (name, avatar)
//  - Load all folder content as unified behavior rules blob
//  - Provide lookup functions for UI and business logic layers
//  - Handle file reading errors gracefully
//
//  SEPARATION OF CONCERNS:
//  ✅ Pure data layer - no UI dependencies or business logic
//  ✅ Other components consume persona data via lookup functions
//  ✅ File watching handled by VaultLoader, not PersonaRegistry

import Foundation
import Combine

// MARK: - Data Models

struct PersonaData {
    let id: String
    let name: String
    let avatar: String
    let behaviorRules: String
    let model: String? // Optional model preference
    
    // Note: behaviorRules contains complete omniscient context (boss + tools + journal + persona)
}

// MARK: - PersonaRegistry

class PersonaRegistry: ObservableObject {
    @Published private(set) var personas: [String: PersonaData] = [:]
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var loadError: String?
    
    // BLUEPRINT: Personas folder path
    private var personasPath: String {
        return "\(VaultConfig.vaultRoot)/playbook/personas"
    }
    
    // MARK: - Initialization
    
    init() {
        loadPersonas()
    }
    
    // MARK: - Core Loading Functions
    
    func loadPersonas() {
        isLoaded = false
        loadError = nil
        
        do {
            let discoveredPersonas = try scanPersonaFolders()
            
            DispatchQueue.main.async {
                self.personas = discoveredPersonas
                self.isLoaded = true
                self.loadError = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.loadError = "Failed to load personas: \(error.localizedDescription)"
                self.isLoaded = false
            }
        }
    }
    
    private func scanPersonaFolders() throws -> [String: PersonaData] {
        let fileManager = FileManager.default
        var discoveredPersonas: [String: PersonaData] = [:]
        
        // Check if personas directory exists
        guard fileManager.fileExists(atPath: personasPath) else {
            throw PersonaError.personasFolderNotFound
        }
        
        // Get all subdirectories in personas folder
        let personaFolders = try fileManager.contentsOfDirectory(atPath: personasPath)
            .filter { item in
                var isDirectory: ObjCBool = false
                let fullPath = "\(personasPath)/\(item)"
                return fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue
            }
        
        // Process each persona folder
        for folderName in personaFolders {
            do {
                let personaData = try parsePersonaFolder(folderName: folderName)
                discoveredPersonas[personaData.id] = personaData
            } catch {
                // Log error but continue processing other personas
                print("❌ Error loading persona \(folderName): \(error)")
            }
        }
        
        return discoveredPersonas
    }
    
    private func parsePersonaFolder(folderName: String) throws -> PersonaData {
        let folderPath = "\(personasPath)/\(folderName)"
        let personaFilePath = "\(folderPath)/\(folderName).md"
        
        // Check if main persona file exists
        guard FileManager.default.fileExists(atPath: personaFilePath) else {
            throw PersonaError.personaFileNotFound(folderName)
        }
        
        // Read main persona file for frontmatter
        let personaContent = try String(contentsOfFile: personaFilePath, encoding: .utf8)
        let (frontmatter, _) = try parsePersonaFile(content: personaContent)
        
        // Build omniscient context: boss + tools + journal + persona
        let omniscientContext = try buildOmniscientContext(personaFolderPath: folderPath)
        
        // Create PersonaData with complete omniscient context
        let personaId = folderName.lowercased()
        return PersonaData(
            id: personaId,
            name: frontmatter.name,
            avatar: frontmatter.avatar,
            behaviorRules: omniscientContext,
            model: frontmatter.model
        )
    }
    
    private func parsePersonaFile(content: String) throws -> (frontmatter: PersonaFrontmatter, behaviorRules: String) {
        let lines = content.components(separatedBy: .newlines)
        
        // Look for frontmatter delimiters
        guard let firstDelimiter = lines.firstIndex(of: "---"),
              let secondDelimiter = lines.dropFirst(firstDelimiter + 1).firstIndex(of: "---") else {
            throw PersonaError.invalidFrontmatter
        }
        
        let adjustedSecondDelimiter = secondDelimiter + firstDelimiter + 1
        
        // Extract frontmatter and content
        let frontmatterLines = Array(lines[(firstDelimiter + 1)..<adjustedSecondDelimiter])
        let contentLines = Array(lines[(adjustedSecondDelimiter + 1)...])
        
        let frontmatter = try parseFrontmatter(frontmatterLines)
        let behaviorRules = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (frontmatter, behaviorRules)
    }
    
    private func parseFrontmatter(_ lines: [String]) throws -> PersonaFrontmatter {
        var name: String?
        var avatar: String?
        var model: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let components = trimmed.components(separatedBy: ":")
            guard components.count >= 2 else { continue }
            
            let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = components[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
            
            switch key {
            case "name":
                name = value
            case "avatar":
                avatar = value
            case "model":
                model = value
            default:
                break
            }
        }
        
        guard let personaName = name, let personaAvatar = avatar else {
            throw PersonaError.missingRequiredFrontmatter
        }
        
        return PersonaFrontmatter(name: personaName, avatar: personaAvatar, model: model)
    }
    
    /// Load ALL .md files in persona folder and concatenate into single blob
    /// FLEXIBILITY: Boss can organize folder content however makes sense - system sends everything to LLM
    private func loadAllFolderContent(folderPath: String) throws -> String {
        let fileManager = FileManager.default
        var allContent: [String] = []
        
        // Get all .md files in the folder
        let allFiles = try fileManager.contentsOfDirectory(atPath: folderPath)
        let markdownFiles = allFiles.filter { $0.hasSuffix(".md") }.sorted()
        
        // Read each .md file and concatenate
        for fileName in markdownFiles {
            let filePath = "\(folderPath)/\(fileName)"
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                allContent.append("--- FILE: \(fileName) ---")
                allContent.append(content)
                allContent.append("") // Empty line separator
            } catch {
                print("Warning: Could not read file \(fileName): \(error)")
            }
        }
        
        // Handle empty folder case gracefully
        if allContent.isEmpty {
            return "# No content files found in persona folder"
        }
        
        return allContent.joined(separator: "\n")
    }
    
    /// Build omniscient context from boss, tools, journal, and persona folders
    /// OMNISCIENT ARCHITECTURE: Every persona gets complete vault context
    private func buildOmniscientContext(personaFolderPath: String) throws -> String {
        var contextSections: [String] = []
        
        // 1. BOSS CONTEXT - Who Boss is, preferences, current projects
        let bossPath = "\(VaultConfig.vaultRoot)/playbook/boss"
        do {
            let bossContent = try loadAllFolderContent(folderPath: bossPath)
            if !bossContent.isEmpty {
                contextSections.append("=== BOSS CONTEXT ===")
                contextSections.append(bossContent)
                contextSections.append("")
            }
        } catch {
            // Boss folder not found or empty
        }
        
        // 2. TOOLS CONTEXT - Available methodologies and tools
        let toolsPath = "\(VaultConfig.vaultRoot)/playbook/tools"
        do {
            let toolsContent = try loadAllFolderContent(folderPath: toolsPath)
            if !toolsContent.isEmpty {
                contextSections.append("=== TOOLS CONTEXT ===")
                contextSections.append(toolsContent)
                contextSections.append("")
            }
        } catch {
            // Tools folder not found or empty
        }
        
        // 3. JOURNAL CONTEXT - Complete conversation history (semantic memory)
        let journalPath = "\(VaultConfig.vaultRoot)/journal"
        do {
            let journalContent = try loadAllFolderContent(folderPath: journalPath)
            if !journalContent.isEmpty {
                contextSections.append("=== CONVERSATION HISTORY ===")
                contextSections.append(journalContent)
                contextSections.append("")
            }
        } catch {
            // Journal folder not found or empty
        }
        
        // 4. PERSONA CONTEXT - Specific cognitive strategy
        let personaContent = try loadAllFolderContent(folderPath: personaFolderPath)
        contextSections.append("=== PERSONA COGNITIVE STRATEGY ===")
        contextSections.append(personaContent)
        
        return contextSections.joined(separator: "\n")
    }
    
    // MARK: - Lookup Functions
    
    func displayName(for personaId: String) -> String {
        return personas[personaId]?.name ?? "Unknown"
    }
    
    func avatar(for personaId: String) -> String {
        return personas[personaId]?.avatar ?? "❓"
    }
    
    func model(for personaId: String) -> String? {
        return personas[personaId]?.model
    }
    
    func behaviorRules(for personaId: String) -> String? {
        return personas[personaId]?.behaviorRules
    }
    
    /// Check if persona exists in registry
    func personaExists(_ personaId: String) -> Bool {
        return personas[personaId] != nil
    }
    
    func allPersonaIds() -> [String] {
        return Array(personas.keys).sorted()
    }
    
    // MARK: - Reload Support
    
    func reloadPersonas() {
        loadPersonas()
    }
}

// MARK: - Supporting Types

private struct PersonaFrontmatter {
    let name: String
    let avatar: String
    let model: String?
}

private enum PersonaError: LocalizedError {
    case personasFolderNotFound
    case personaFileNotFound(String)
    case invalidFrontmatter
    case missingRequiredFrontmatter
    
    var errorDescription: String? {
        switch self {
        case .personasFolderNotFound:
            return "Personas folder not found at expected location"
        case .personaFileNotFound(let folderName):
            return "Persona file not found for \(folderName)"
        case .invalidFrontmatter:
            return "Invalid frontmatter format"
        case .missingRequiredFrontmatter:
            return "Missing required frontmatter fields (name, avatar)"
        }
    }
}