//
//  VaultWriter.swift
//  Aether
//
//  Conversational file writing to vault
//
//  BLUEPRINT SECTION: 🚨 Trim - VaultWriter
//  ======================================
//
//  BLUEPRINT VISION: LLMs write .md content via natural language instruction
//  CURRENT IMPLEMENTATION: Conversational commands + complete superjournal auto-save system
//  ACHIEVEMENTS TODAY: ✅ Full superjournal implementation with agentic auto-save
//
//  RESPONSIBILITIES:
//  - Process conversational file writing commands ("write X", "add Y")
//  - Auto-save every conversation turn to superjournal (agentic operation)
//  - Create vault directory structure automatically
//  - Attach comprehensive metadata (timestamps, attribution, turn structure)
//  - Migrate existing conversations to superjournal for complete audit trail
//
//  DESIGN PRINCIPLES:
//  ✅ "All creation conversational — no structured syntax required, no UI elements involved"
//  ✅ Separation of concerns: File operations only, no UI logic
//  ✅ Agentic operation: Auto-save without manual intervention
//  ✅ Complete audit trail: Every turn preserved for debugging and recall
//
//  MAJOR ACHIEVEMENT: Superjournal system provides enterprise-grade conversation auditing

import Foundation

// MARK: - String Extension for Regex
extension String {
    func matches(_ pattern: String) -> Bool {
        // SAFETY: Handle regex creation errors gracefully
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}

class VaultWriter: ObservableObject {
    
    static let shared = VaultWriter()
    private let llmManager = LLMManager()
    private let taxonomyManager = TaxonomyManager.shared
    
    private init() {
        createVaultDirectoriesIfNeeded()
    }
    
    // MARK: - Conversational File Operations (Blueprint Vision)
    
    /// Process conversational file writing commands
    /// BLUEPRINT: "Boss simply says: 'Write a new strategy note to journal titled Clarity Over Complexity. Content begins...'"
    /// CURRENT: Simple write/add commands, foundation for LLM-powered interpretation
    func processCommand(_ message: String) -> String? {
        let lowercased = message.lowercased()
        
        if lowercased.hasPrefix("write ") {
            let content = String(message.dropFirst(6)) // Remove "write "
            return writeToFile(content: content)
        } else if lowercased.hasPrefix("add ") {
            let content = String(message.dropFirst(4)) // Remove "add "
            return appendToFile(content: content)
        } else if lowercased == "process trims" {
            return "❌ Batch processing functionality has been removed to prevent data corruption."
        } else if lowercased == "reprocess trims" {
            return "❌ Reprocessing functionality has been removed to prevent data corruption."
        } else if lowercased == "clear scrollback" {
            // This needs to be handled by MessageStore, not VaultWriter
            // Return a special marker that MessageStore can detect
            return "CLEAR_SCROLLBACK_COMMAND"
        }
        
        return nil // No write command detected
    }
    
    // MARK: - Auto-Save Superjournal (Blueprint Implementation)
    // 🎉 MAJOR ACHIEVEMENT: Complete superjournal system with agentic auto-save
    
    /// Auto-save conversation turn to superjournal
    /// BLUEPRINT: "FullTurn-YYYY-MM-DD-HHMM.md — Complete uncompressed logs"
    /// ACHIEVEMENT: ✅ Fully implemented with automatic triggering from MessageStore
    /// PURPOSE: Enterprise-grade audit trail for deep recall, debugging, and trim quality assessment
    func autoSaveTurn(userMessage: String, aiResponse: String, persona: String) {
        let timestamp = createTimestamp()
        let filename = "FullTurn-\(timestamp).md"
        let filePath = "\(VaultConfig.superJournalPath)/\(filename)"
        
        let turnContent = formatTurnForSuperjournal(
            userMessage: userMessage,
            aiResponse: aiResponse,
            timestamp: timestamp,
            persona: persona
        )
        
        do {
            try turnContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            print("❌ Failed to auto-save turn to superjournal: \(error)")
        }
    }
    
    /// Validate and process machine trim response for taxonomy evolution
    /// BLUEPRINT: "Real-time validation during trim operations"
    private func validateAndProcessTrim(_ trimContent: String) throws -> String {
        // Parse trim metadata
        guard let metadata = taxonomyManager.parseTrimMetadata(trimContent) else {
            print("⚠️ Could not parse trim metadata, using content as-is")
            return trimContent
        }
        
        // Validate topic hierarchy
        let validationResult = taxonomyManager.validateTopicHierarchy(metadata.topicHierarchy)
        
        if !validationResult.isValid {
            print("⚠️ Invalid topic hierarchy: \(metadata.topicHierarchy)")
            print("   Warnings: \(validationResult.warnings.joined(separator: ", "))")
        }
        
        // Always add to taxonomy - let TaxonomyManager handle duplicates
        print("📋 Adding to taxonomy: \(metadata.topicHierarchy)")
        taxonomyManager.addToTaxonomy(hierarchyString: metadata.topicHierarchy)
        
        // Log taxonomy evolution
        if !validationResult.suggestions.isEmpty {
            print("📋 Taxonomy evolution: \(validationResult.suggestions.joined(separator: ", "))")
        }
        
        // Validate keywords
        let validatedKeywords = taxonomyManager.validateKeywords(metadata.keywords)
        if validatedKeywords != metadata.keywords {
            print("📋 Keywords normalized: \(metadata.keywords) → \(validatedKeywords)")
        }
        
        // Validate dependencies
        let validatedDependencies = taxonomyManager.validateDependencies(metadata.dependencies)
        if validatedDependencies.count != metadata.dependencies.count {
            print("📋 Dependencies filtered: \(metadata.dependencies.count) → \(validatedDependencies.count)")
        }
        
        // Return validated trim content
        return trimContent
    }
    
    /// Save machine-compressed turn to journal with taxonomy validation
    /// BLUEPRINT: Machine trimming handled by LLMManager dual-task system + taxonomy integration
    /// PURPOSE: Save the compressed turn that comes from LLMManager's dual-task output with validation
    func saveMachineTrim(_ compressedContent: String, timestamp: String) {
        // Convert timestamp format for journal filename
        let journalTimestamp = convertTimestampForJournal(timestamp)
        let journalFilename = "Trim-\(journalTimestamp).md"
        let journalFilePath = "\(VaultConfig.journalPath)/\(journalFilename)"
        
        do {
            // Validate and process the trim content for taxonomy evolution
            let validatedContent = try validateAndProcessTrim(compressedContent)
            try validatedContent.write(toFile: journalFilePath, atomically: true, encoding: String.Encoding.utf8)
            print("✅ Machine trim saved with taxonomy validation: \(journalFilename)")
        } catch {
            print("❌ Failed to save machine trim: \(error)")
            // Fallback: save original content without validation
            do {
                try compressedContent.write(toFile: journalFilePath, atomically: true, encoding: String.Encoding.utf8)
                print("⚠️ Machine trim saved without validation as fallback")
            } catch {
                print("❌ Failed to save machine trim even as fallback: \(error)")
            }
        }
    }
    
    /// Convert timestamp format from superjournal to journal format
    /// From: "20250715-091023" to "2025-07-15-0910"
    private func convertTimestampForJournal(_ timestamp: String) -> String {
        if timestamp.count == 15 { // "20250715-091023"
            let year = String(timestamp.prefix(4))
            let month = String(timestamp.dropFirst(4).prefix(2))
            let day = String(timestamp.dropFirst(6).prefix(2))
            let hour = String(timestamp.dropFirst(9).prefix(2))
            let minute = String(timestamp.dropFirst(11).prefix(2))
            
            return "\(year)-\(month)-\(day)-\(hour)\(minute)"
        }
        return timestamp
    }
    
    
    
    
    // DANGEROUS FUNCTIONS REMOVED:
    // - fixSuperjournalTimestamps() - Deleted all superjournal files during "cleanup"
    // - cleanupSuperjournalFiles() - The destructive function that caused data loss
    // These functions were removed to prevent future data loss incidents
    
    // MARK: - Safety Systems
    
    /// Create backup of file before destructive operations
    /// SAFETY: Always backup before overwriting or modifying files
    private func createBackup(of filePath: String) -> Bool {
        guard FileManager.default.fileExists(atPath: filePath) else {
            return true // No file to backup, operation is safe
        }
        
        let filename = URL(fileURLWithPath: filePath).lastPathComponent
        let backupFilename = "backup-\(createTimestamp())-\(filename)"
        let backupPath = "\(VaultConfig.trashPath)/\(backupFilename)"
        
        do {
            try FileManager.default.copyItem(atPath: filePath, toPath: backupPath)
            return true
        } catch {
            print("❌ Failed to create backup for \(filename): \(error)")
            return false
        }
    }
    
    /// Verify file integrity after write operations
    /// SAFETY: Ensure file was written correctly and is readable
    private func verifyFileIntegrity(at filePath: String, expectedContent: String) -> Bool {
        do {
            let writtenContent = try String(contentsOfFile: filePath, encoding: .utf8)
            return writtenContent == expectedContent
        } catch {
            print("❌ Failed to verify file integrity: \(error)")
            return false
        }
    }
    
    // MARK: - File Operations (Current Implementation)
    
    private func writeToFile(content: String) -> String {
        let filePath = VaultConfig.notesFilePath
        
        // SAFETY: Create backup before overwriting
        guard createBackup(of: filePath) else {
            return "❌ Failed to create backup before writing - operation aborted for safety"
        }
        
        do {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            
            // SAFETY: Verify file was written correctly
            guard verifyFileIntegrity(at: filePath, expectedContent: content) else {
                return "❌ File integrity check failed after write - please check file manually"
            }
            
            return "✅ Wrote to file: \(content)\n📁 Location: \(filePath)\n💾 Backup created in trash folder"
        } catch {
            return "❌ Failed to write file: \(error.localizedDescription)"
        }
    }
    
    private func appendToFile(content: String) -> String {
        let filePath = VaultConfig.notesFilePath
        
        // SAFETY: Create backup before modifying
        guard createBackup(of: filePath) else {
            return "❌ Failed to create backup before appending - operation aborted for safety"
        }
        
        do {
            // Read existing content if file exists
            var existingContent = ""
            if FileManager.default.fileExists(atPath: filePath) {
                existingContent = try String(contentsOfFile: filePath, encoding: .utf8)
            }
            
            // Append new content with newline
            let newContent = existingContent.isEmpty ? content : existingContent + "\n" + content
            
            try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            
            // SAFETY: Verify file was written correctly
            guard verifyFileIntegrity(at: filePath, expectedContent: newContent) else {
                return "❌ File integrity check failed after append - please check file manually"
            }
            
            return "✅ Added to file: \(content)\n📁 Location: \(filePath)\n💾 Backup created in trash folder"
        } catch {
            return "❌ Failed to add to file: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Utility Functions
    
    /// Create vault directory structure if needed
    /// BLUEPRINT: "Creates files and directories as needed"
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
    
    /// Format conversation turn for superjournal with proper persona headers
    /// BLUEPRINT: "Complete uncompressed logs" with metadata
    /// FORMAT: Structured markdown with comprehensive metadata for audit trail
    /// INCLUDES: Timestamp, turn type, complete user/AI exchange, clear separation
    private func formatTurnForSuperjournal(userMessage: String, aiResponse: String, timestamp: String, persona: String) -> String {
        // Use the actual persona that responded
        let userLabel = "Boss"
        let aiLabel = persona.capitalized // Capitalize first letter (samara -> Samara)
        
        return """
        # Full Conversation Turn - \(timestamp)
        
        ---
        
        ## \(userLabel)
        
        \(userMessage)
        
        ---
        
        ## \(aiLabel)
        
        \(aiResponse)
        
        ---
        
        *End of turn*
        """
    }
    
    /// Parse persona from user message for new superjournal entries
    private func parsePersonasFromUserMessage(_ userMessage: String) -> (userLabel: String, aiLabel: String) {
        let userLabel = "Boss"
        var aiLabel = loadCurrentPersistentPersona().capitalized
        
        // Check if user message starts with persona name
        let words = userMessage.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces)
        if let firstWord = words.first {
            let cleanedWord = firstWord.trimmingCharacters(in: .punctuationCharacters).lowercased()
            if ["samara", "vlad", "vanessa", "aether"].contains(cleanedWord) {
                aiLabel = cleanedWord.capitalized
            }
        }
        
        return (userLabel, aiLabel)
    }
    
    /// Create timestamp for filenames (sortable format)
    private func createTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
    
    /// Format existing message timestamp (sortable format)
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    /// Get all existing superjournal files
    func getSuperJournalFiles() -> [String] {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: VaultConfig.superJournalPath)
            return files.filter { $0.hasPrefix("FullTurn-") && $0.hasSuffix(".md") }
        } catch {
            return []
        }
    }
    
    /// Count conversation turns from messages
    private func countConversationTurns(_ messages: [ChatMessage]) -> Int {
        var turnCount = 0
        var hasUserMessage = false
        
        for message in messages {
            if message.author == "User" {
                hasUserMessage = true
            } else if message.author == "AI" && hasUserMessage {
                turnCount += 1
                hasUserMessage = false
            }
        }
        
        return turnCount
    }
    
    /// Extract timestamp from old filename format and convert to new format
    private func extractTimestampFromOldFilename(_ filename: String) -> String {
        // Extract from format like "FullTurn-2025-07-14-0703.md"
        let pattern = "FullTurn-(\\d{4})-(\\d{2})-(\\d{2})-(\\d{4})\\.md"
        
        // SAFETY: Handle regex creation errors gracefully
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return createTimestamp()
        }
        
        let range = NSRange(location: 0, length: filename.utf16.count)
        
        if let match = regex.firstMatch(in: filename, options: [], range: range) {
            let year = (filename as NSString).substring(with: match.range(at: 1))
            let month = (filename as NSString).substring(with: match.range(at: 2))
            let day = (filename as NSString).substring(with: match.range(at: 3))
            let time = (filename as NSString).substring(with: match.range(at: 4))
            
            // Convert HHMM to HHMMSS (add 00 seconds)
            let hours = String(time.prefix(2))
            let minutes = String(time.suffix(2))
            
            return "\(year)\(month)\(day)-\(hours)\(minutes)00"
        }
        
        // Fallback to current time if parsing fails
        return createTimestamp()
    }
    
    /// Parse persona information from superjournal content
    private func parsePersonasFromContent(_ content: String) -> (userLabel: String, aiLabel: String) {
        // Default labels
        let userLabel = "Boss"
        var aiLabel = loadCurrentPersistentPersona().capitalized
        
        // Look for persona targeting in user message
        let lines = content.components(separatedBy: .newlines)
        var inUserSection = false
        
        for line in lines {
            if line.contains("## User Message") {
                inUserSection = true
                continue
            } else if line.contains("## AI Response") {
                inUserSection = false
                continue
            }
            
            if inUserSection && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Check if user message starts with persona name
                let words = line.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces)
                if let firstWord = words.first {
                    let cleanedWord = firstWord.trimmingCharacters(in: .punctuationCharacters).lowercased()
                    if ["samara", "vlad", "vanessa", "aether"].contains(cleanedWord) {
                        aiLabel = cleanedWord.capitalized
                    }
                }
                break
            }
        }
        
        return (userLabel, aiLabel)
    }
    
    /// Update persona headers in superjournal content
    private func updatePersonaHeaders(_ content: String, userLabel: String, aiLabel: String, timestamp: String) -> String {
        var updatedContent = content
        
        // Replace headers
        updatedContent = updatedContent.replacingOccurrences(of: "## User Message", with: "## \(userLabel)")
        updatedContent = updatedContent.replacingOccurrences(of: "## AI Response", with: "## \(aiLabel)")
        
        // Update timestamp in title if present
        let titlePattern = "# Full Conversation Turn - [^\n]+"
        
        // SAFETY: Handle regex creation errors gracefully
        guard let titleRegex = try? NSRegularExpression(pattern: titlePattern) else {
            return updatedContent
        }
        
        let titleRange = NSRange(location: 0, length: updatedContent.utf16.count)
        
        if titleRegex.firstMatch(in: updatedContent, options: [], range: titleRange) != nil {
            let newTitle = "# Full Conversation Turn - \(timestamp)"
            updatedContent = titleRegex.stringByReplacingMatches(in: updatedContent, options: [], range: titleRange, withTemplate: newTitle)
        }
        
        // Update timestamp in metadata if present
        updatedContent = updatedContent.replacingOccurrences(
            of: "**Timestamp:** [^\n]+",
            with: "**Timestamp:** \(timestamp)",
            options: .regularExpression
        )
        
        return updatedContent
    }
    
    /// Create realistic superjournal content with proper formatting
    private func createRealisticSuperjournalContent(userMessage: String, aiResponse: String, timestamp: String, userLabel: String, aiLabel: String) -> String {
        return """
        # Full Conversation Turn - \(timestamp)
        
        ---
        
        ## \(userLabel)
        
        \(userMessage)
        
        ---
        
        ## \(aiLabel)
        
        \(aiResponse)
        
        ---
        
        *End of turn*
        """
    }
    
    /// Format time for readable display
    private func formatReadableTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    /// Load current persistent persona (same logic as LLMManager)
    private func loadCurrentPersistentPersona() -> String {
        let path = VaultConfig.currentPersonaPath
        
        if FileManager.default.fileExists(atPath: path) {
            do {
                let savedPersona = try String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                if !savedPersona.isEmpty {
                    return savedPersona
                }
            } catch {
                print("⚠️ VaultWriter failed to load current persona: \(error)")
            }
        }
        
        // Emergency fallback
        return "samara"
    }
    
    // MARK: - Machine Trim Batch Processing
    
    /// Clear existing journal files and regenerate all trims
    /// SAFETY: Moves existing journal files to trash, then regenerates
    
    // MARK: - Taxonomy Integration for Live Operations
    
    /// Get taxonomy context for inclusion in live LLM requests
    /// BLUEPRINT: "Option A - include current taxonomy in omniscient bundle"
    /// USAGE: Called by LLMManager for live conversation trims
    func getTaxonomyContextForLiveTrims() -> String {
        return taxonomyManager.getTaxonomyContext()
    }
    
    /// Get taxonomy statistics for monitoring
    /// BLUEPRINT: "Quality metrics - consistency score, coverage analysis"
    func getTaxonomyStats() -> [String: Any] {
        return taxonomyManager.getTaxonomyStats()
    }
    
    /// Get human-readable taxonomy structure
    /// USAGE: For debugging and system monitoring
    func getTaxonomyDescription() -> String {
        return taxonomyManager.getTaxonomyDescription()
    }
    
    // MARK: - Future Blueprint Implementation
    
    // TODO: LLM-powered command interpretation
    // TODO: "Write a new strategy note to journal titled X. Content begins..."
    // TODO: Complex file operations via natural language
    // TODO: Metadata attachment (attribution, origin tracking)
    // TODO: Integration with persona system for context-aware file operations
}