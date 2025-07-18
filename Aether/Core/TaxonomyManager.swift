//
//  TaxonomyManager.swift
//  Aether
//
//  Core taxonomy management for self-consistent tag taxonomy system
//
//  BLUEPRINT SECTION: 🚨 Core - Self-Consistent Tag Taxonomy System
//  ===============================================================
//
//  BLUEPRINT VISION: Self-organizing semantic index that grows intelligently with conversation history
//  CURRENT IMPLEMENTATION: Core taxonomy management with real-time validation and evolution
//  ACHIEVEMENTS TODAY: ✅ Complete taxonomy management system with structured metadata
//
//  RESPONSIBILITIES:
//  - Load and parse taxonomy.json from tools directory
//  - Validate new categories against existing patterns
//  - Manage taxonomy evolution and consistency
//  - Provide clean API for VaultWriter integration
//  - Support omniscient memory bundle preparation
//
//  DESIGN PRINCIPLES:
//  ✅ "Self-organizing semantic index" - taxonomy grows naturally from conversation patterns
//  ✅ "Semantic consistency" - validation ensures coherent knowledge architecture
//  ✅ "Living taxonomy" - evolves while maintaining structural integrity
//  ✅ Option A Implementation - taxonomy included in omniscient bundle, processed by VaultWriter
//
//  MAJOR ACHIEVEMENT: Enables future-scale semantic retrieval without database complexity

import Foundation

// MARK: - Taxonomy Data Models

struct Taxonomy: Codable {
    var topics: [String: TopicCategory]
    var relationships: [String]
    var contexts: [String]
    var dependencies: [String]
    
    // Initialize with default structure
    init() {
        self.topics = [:]
        self.relationships = ["boss-persona", "tone-shift", "trust-building", "conflict-resolution"]
        self.contexts = ["project-planning", "problem-solving", "knowledge-sharing", "decision-making"]
        self.dependencies = ["builds_on", "clarifies", "challenges", "resolves"]
    }
}

struct TopicCategory: Codable {
    var subcategories: [String: [String]]
    
    init() {
        self.subcategories = [:]
    }
}

struct TaxonomyValidationResult {
    let isValid: Bool
    let validatedHierarchy: String
    let suggestions: [String]
    let warnings: [String]
}

struct TrimMetadata {
    let topicHierarchy: String
    let keywords: [String]
    let dependencies: [String]
    let sentiment: String?
    let contextDeltas: [String]
}

// MARK: - TaxonomyManager Class

class TaxonomyManager: ObservableObject {
    
    static let shared = TaxonomyManager()
    private var taxonomy: Taxonomy
    private let taxonomyFilePath: String
    
    private init() {
        self.taxonomyFilePath = "\(VaultConfig.vaultRoot)/playbook/tools/taxonomy.json"
        self.taxonomy = Taxonomy()
        loadTaxonomy()
    }
    
    // MARK: - Core Taxonomy Operations
    
    /// Load taxonomy from JSON file
    /// BLUEPRINT: "Query existing taxonomy first" - loads current state for validation
    private func loadTaxonomy() {
        guard FileManager.default.fileExists(atPath: taxonomyFilePath) else {
            print("📋 Taxonomy file not found, creating default structure")
            createDefaultTaxonomy()
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: taxonomyFilePath))
            self.taxonomy = try JSONDecoder().decode(Taxonomy.self, from: data)
            print("📋 Taxonomy loaded successfully with \(taxonomy.topics.count) topic categories")
        } catch {
            print("❌ Failed to load taxonomy: \(error), using default structure")
            createDefaultTaxonomy()
        }
    }
    
    /// Save taxonomy to JSON file
    /// BLUEPRINT: "System learns and evolves taxonomy automatically" - persists changes
    private func saveTaxonomy() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(taxonomy)
            try data.write(to: URL(fileURLWithPath: taxonomyFilePath))
            print("📋 Taxonomy saved successfully")
        } catch {
            print("❌ Failed to save taxonomy: \(error)")
        }
    }
    
    /// Create default taxonomy structure
    private func createDefaultTaxonomy() {
        taxonomy = Taxonomy()
        
        // Initialize with seed categories from existing examples
        taxonomy.topics["technology"] = TopicCategory()
        taxonomy.topics["technology"]?.subcategories["ai"] = ["language-models", "training", "inference"]
        taxonomy.topics["technology"]?.subcategories["development"] = ["architecture", "debugging", "testing"]
        taxonomy.topics["technology"]?.subcategories["web-development"] = ["css-frameworks", "javascript", "react"]
        taxonomy.topics["technology"]?.subcategories["javascript"] = ["module-systems", "bundling", "compatibility"]
        taxonomy.topics["technology"]?.subcategories["programming-languages"] = ["rust", "swift", "python"]
        
        taxonomy.topics["philosophy"] = TopicCategory()
        taxonomy.topics["philosophy"]?.subcategories["ethics"] = ["decision-making", "responsibility", "consequences"]
        taxonomy.topics["philosophy"]?.subcategories["epistemology"] = ["knowledge", "belief", "truth"]
        
        taxonomy.topics["daily"] = TopicCategory()
        taxonomy.topics["daily"]?.subcategories["food"] = ["vegetables", "cooking", "nutrition", "ingredients"]
        taxonomy.topics["daily"]?.subcategories["health"] = ["exercise", "wellness", "medical"]
        
        taxonomy.topics["personal"] = TopicCategory()
        taxonomy.topics["personal"]?.subcategories["communication"] = ["symbols", "identity", "signature"]
        taxonomy.topics["personal"]?.subcategories["insights"] = ["independence", "breakthroughs", "realizations"]
        
        saveTaxonomy()
    }
    
    // MARK: - Validation and Consistency
    
    /// Validate topic hierarchy against existing taxonomy
    /// BLUEPRINT: "Validation ensures tags follow consistent patterns"
    /// OPTION A: Called by VaultWriter before sending to LLM
    func validateTopicHierarchy(_ hierarchyString: String) -> TaxonomyValidationResult {
        let components = hierarchyString.components(separatedBy: "/")
        var suggestions: [String] = []
        var warnings: [String] = []
        
        guard components.count >= 2 && components.count <= 3 else {
            warnings.append("Hierarchy must have 2-3 levels: category/subcategory/specific")
            return TaxonomyValidationResult(isValid: false, validatedHierarchy: hierarchyString, suggestions: suggestions, warnings: warnings)
        }
        
        let category = components[0]
        let subcategory = components[1]
        let specific = components.count > 2 ? components[2] : nil
        
        // Check if category exists
        if !taxonomy.topics.keys.contains(category) {
            suggestions.append("New category '\(category)' will be created")
        }
        
        // Check if subcategory exists
        if let existingCategory = taxonomy.topics[category],
           !existingCategory.subcategories.keys.contains(subcategory) {
            suggestions.append("New subcategory '\(subcategory)' will be created under '\(category)'")
        }
        
        // Check if specific exists
        if let specific = specific,
           let existingCategory = taxonomy.topics[category],
           let existingSubcategory = existingCategory.subcategories[subcategory],
           !existingSubcategory.contains(specific) {
            suggestions.append("New specific term '\(specific)' will be added to '\(category)/\(subcategory)'")
        }
        
        // Check for semantic duplicates
        let duplicateWarnings = checkForSemanticDuplicates(category: category, subcategory: subcategory, specific: specific)
        warnings.append(contentsOf: duplicateWarnings)
        
        return TaxonomyValidationResult(isValid: true, validatedHierarchy: hierarchyString, suggestions: suggestions, warnings: warnings)
    }
    
    /// Check for semantic duplicates in taxonomy
    private func checkForSemanticDuplicates(category: String, subcategory: String, specific: String?) -> [String] {
        var warnings: [String] = []
        
        // Check for similar category names
        for existingCategory in taxonomy.topics.keys {
            if existingCategory != category && areSemanticallyRelated(category, existingCategory) {
                warnings.append("Category '\(category)' is semantically similar to existing '\(existingCategory)'")
            }
        }
        
        // Check for similar subcategory names across categories
        for (existingCategory, topicCategory) in taxonomy.topics {
            for existingSubcategory in topicCategory.subcategories.keys {
                if existingSubcategory != subcategory && areSemanticallyRelated(subcategory, existingSubcategory) {
                    warnings.append("Subcategory '\(subcategory)' is similar to existing '\(existingSubcategory)' in '\(existingCategory)'")
                }
            }
        }
        
        return warnings
    }
    
    /// Simple semantic similarity check
    private func areSemanticallyRelated(_ term1: String, _ term2: String) -> Bool {
        let normalized1 = term1.lowercased().replacingOccurrences(of: "-", with: "")
        let normalized2 = term2.lowercased().replacingOccurrences(of: "-", with: "")
        
        // Check for exact matches after normalization
        if normalized1 == normalized2 { return true }
        
        // Check for substring relationships
        if normalized1.contains(normalized2) || normalized2.contains(normalized1) { return true }
        
        // Check for common abbreviations
        let abbreviations = [
            ("technology", "tech"),
            ("development", "dev"),
            ("javascript", "js"),
            ("artificial-intelligence", "ai")
        ]
        
        for (full, abbrev) in abbreviations {
            if (normalized1 == full && normalized2 == abbrev) || (normalized1 == abbrev && normalized2 == full) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Taxonomy Evolution
    
    /// Add new hierarchy to taxonomy
    /// BLUEPRINT: "New categories emerge naturally from conversation patterns"
    /// OPTION A: Called by VaultWriter after processing LLM response
    func addToTaxonomy(hierarchyString: String) {
        let components = hierarchyString.components(separatedBy: "/")
        guard components.count >= 2 && components.count <= 3 else { return }
        
        let category = components[0]
        let subcategory = components[1]
        let specific = components.count > 2 ? components[2] : nil
        
        // Ensure category exists
        if taxonomy.topics[category] == nil {
            taxonomy.topics[category] = TopicCategory()
        }
        
        // Ensure subcategory exists
        if taxonomy.topics[category]?.subcategories[subcategory] == nil {
            taxonomy.topics[category]?.subcategories[subcategory] = []
        }
        
        // Add specific term if provided
        if let specific = specific {
            if let existingTerms = taxonomy.topics[category]?.subcategories[subcategory],
               !existingTerms.contains(specific) {
                taxonomy.topics[category]?.subcategories[subcategory]?.append(specific)
            }
        }
        
        saveTaxonomy()
    }
    
    /// Validate keywords against existing patterns
    /// BLUEPRINT: "Structured keyword extraction for future relevance matching"
    func validateKeywords(_ keywords: [String]) -> [String] {
        return keywords.map { keyword in
            let normalized = keyword.lowercased().replacingOccurrences(of: "_", with: "-")
            // Future enhancement: Check against existing keyword patterns
            return normalized
        }
    }
    
    /// Validate dependencies against known types
    /// BLUEPRINT: "Cross-turn dependency tracking"
    func validateDependencies(_ dependencies: [String]) -> [String] {
        return dependencies.filter { dependency in
            let components = dependency.components(separatedBy: ":")
            guard components.count == 2 else { return false }
            
            let dependencyType = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            return taxonomy.dependencies.contains(dependencyType)
        }
    }
    
    // MARK: - Omniscient Memory Integration
    
    /// Get taxonomy context for omniscient memory bundle
    /// BLUEPRINT: "Option A - include current taxonomy in omniscient bundle sent to LLM"
    /// USAGE: Called by VaultWriter or LLMManager before sending to LLM
    func getTaxonomyContext() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(taxonomy),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "Current taxonomy structure unavailable"
        }
        
        return """
        CURRENT TAXONOMY STRUCTURE:
        
        \(jsonString)
        
        TAXONOMY USAGE RULES:
        - Use existing categories when possible
        - Follow hierarchy format: category/subcategory/specific
        - Maximum 3 levels deep
        - Use lowercase with hyphens for compound terms
        - Avoid semantic duplicates
        
        NEW CATEGORY CREATION:
        - Only create new categories if existing ones don't fit
        - Follow established naming patterns
        - Cluster related concepts under logical parents
        """
    }
    
    /// Parse trim metadata from LLM response
    /// BLUEPRINT: "Real-time validation during trim operations"
    /// USAGE: Called by VaultWriter to process LLM trim response
    func parseTrimMetadata(_ trimContent: String) -> TrimMetadata? {
        let lines = trimContent.components(separatedBy: .newlines)
        
        var topicHierarchy = ""
        var keywords: [String] = []
        var dependencies: [String] = []
        var sentiment: String? = nil
        var contextDeltas: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("topic_hierarchy:") {
                topicHierarchy = String(trimmedLine.dropFirst(16)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmedLine.hasPrefix("keywords:") {
                let keywordString = String(trimmedLine.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
                keywords = parseArrayFromString(keywordString)
            } else if trimmedLine.hasPrefix("dependencies:") {
                let dependencyString = String(trimmedLine.dropFirst(13)).trimmingCharacters(in: .whitespacesAndNewlines)
                dependencies = parseArrayFromString(dependencyString)
            } else if trimmedLine.hasPrefix("sentiment:") {
                sentiment = String(trimmedLine.dropFirst(10)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmedLine.hasPrefix("context_deltas:") {
                // Parse context deltas (multiline format)
                // Future enhancement: Parse structured context deltas
                contextDeltas = []
            }
        }
        
        guard !topicHierarchy.isEmpty else { return nil }
        
        return TrimMetadata(
            topicHierarchy: topicHierarchy,
            keywords: keywords,
            dependencies: dependencies,
            sentiment: sentiment?.isEmpty == false ? sentiment : nil,
            contextDeltas: contextDeltas
        )
    }
    
    /// Parse array format from string like "[item1, item2, item3]"
    private func parseArrayFromString(_ input: String) -> [String] {
        let cleaned = input.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return cleaned.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    // MARK: - Statistics and Analytics
    
    /// Get taxonomy statistics for monitoring
    /// BLUEPRINT: "Quality metrics - consistency score, coverage analysis"
    func getTaxonomyStats() -> [String: Any] {
        let totalCategories = taxonomy.topics.count
        let totalSubcategories = taxonomy.topics.values.reduce(0) { $0 + $1.subcategories.count }
        let totalSpecificTerms = taxonomy.topics.values.reduce(0) { total, category in
            total + category.subcategories.values.reduce(0) { $0 + $1.count }
        }
        
        return [
            "totalCategories": totalCategories,
            "totalSubcategories": totalSubcategories,
            "totalSpecificTerms": totalSpecificTerms,
            "relationshipTypes": taxonomy.relationships.count,
            "contextTypes": taxonomy.contexts.count,
            "dependencyTypes": taxonomy.dependencies.count
        ]
    }
    
    /// Get taxonomy as formatted string for debugging
    func getTaxonomyDescription() -> String {
        var description = "TAXONOMY STRUCTURE:\n\n"
        
        for (category, topicCategory) in taxonomy.topics.sorted(by: { $0.key < $1.key }) {
            description += "📁 \(category)\n"
            for (subcategory, terms) in topicCategory.subcategories.sorted(by: { $0.key < $1.key }) {
                description += "  📂 \(subcategory)\n"
                for term in terms.sorted() {
                    description += "    📄 \(term)\n"
                }
            }
            description += "\n"
        }
        
        return description
    }
    
    // MARK: - Future Enhancements
    
    // TODO: Semantic similarity analysis using vector embeddings
    // TODO: Automatic category merging for semantically similar terms
    // TODO: Usage frequency tracking for taxonomy optimization
    // TODO: Temporal patterns in taxonomy evolution
    // TODO: Integration with ContextMemoryIndex for retrieval optimization
}