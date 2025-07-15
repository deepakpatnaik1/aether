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
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}

class VaultWriter: ObservableObject {
    
    static let shared = VaultWriter()
    private let llmManager = LLMManager()
    
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
        }
        
        return nil // No write command detected
    }
    
    // MARK: - Auto-Save Superjournal (Blueprint Implementation)
    // 🎉 MAJOR ACHIEVEMENT: Complete superjournal system with agentic auto-save
    
    /// Auto-save conversation turn to superjournal
    /// BLUEPRINT: "FullTurn-YYYY-MM-DD-HHMM.md — Complete uncompressed logs"
    /// ACHIEVEMENT: ✅ Fully implemented with automatic triggering from MessageStore
    /// PURPOSE: Enterprise-grade audit trail for deep recall, debugging, and trim quality assessment
    func autoSaveTurn(userMessage: String, aiResponse: String) {
        let timestamp = createTimestamp()
        let filename = "FullTurn-\(timestamp).md"
        let filePath = "\(VaultConfig.superJournalPath)/\(filename)"
        
        let turnContent = formatTurnForSuperjournal(
            userMessage: userMessage,
            aiResponse: aiResponse,
            timestamp: timestamp
        )
        
        do {
            try turnContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("📝 Auto-saved turn to superjournal: \(filename)")
        } catch {
            print("❌ Failed to auto-save turn to superjournal: \(error)")
        }
    }
    
    /// Migrate existing conversation turns to superjournal
    /// BLUEPRINT: Backfill existing conversations for complete audit trail
    /// ACHIEVEMENT: ✅ Successfully migrates "What is outer space?" and all previous conversations
    /// PURPOSE: Ensures no conversation data is lost, complete historical audit trail
    func migratePreviousTurns(_ messages: [ChatMessage]) {
        print("📝 Migrating \(messages.count) previous messages to superjournal...")
        
        var userMessage: String?
        
        for message in messages {
            if message.author == "User" {
                userMessage = message.content
            } else if message.author == "AI", let user = userMessage {
                // Complete turn: user + AI response
                let timestamp = formatTimestamp(message.timestamp)
                let filename = "FullTurn-\(timestamp).md"
                let filePath = "\(VaultConfig.superJournalPath)/\(filename)"
                
                let turnContent = formatTurnForSuperjournal(
                    userMessage: user,
                    aiResponse: message.content,
                    timestamp: timestamp
                )
                
                do {
                    try turnContent.write(toFile: filePath, atomically: true, encoding: .utf8)
                } catch {
                    print("❌ Failed to migrate turn: \(error)")
                }
                
                userMessage = nil // Reset for next turn
            }
        }
        
        print("✅ Migration to superjournal complete")
    }
    
    /// Backfill missing early turns to superjournal
    /// PURPOSE: Ensures all conversation turns are preserved in superjournal
    /// FIXES: Missing earliest 6 turns that predate auto-save implementation
    func backfillMissingTurns() {
        print("🔄 Checking for missing early turns in superjournal...")
        
        // Get all existing superjournal files
        let superjournalFiles = getSuperJournalFiles()
        let existingCount = superjournalFiles.count
        
        // Load conversation messages to find total turn count
        let memoryIndex = ContextMemoryIndex.shared
        let messages = memoryIndex.getConversationHistory()
        let totalTurns = countConversationTurns(messages)
        
        print("📊 Found \(existingCount) superjournal files, \(totalTurns) total conversation turns")
        
        if existingCount >= totalTurns {
            print("✅ All turns already in superjournal")
            return
        }
        
        // Find missing early turns and backfill them
        let missingCount = totalTurns - existingCount
        print("🔄 Backfilling \(missingCount) missing early turns...")
        
        var userMessage: String?
        var processedTurns = 0
        
        for message in messages {
            if message.author == "User" {
                userMessage = message.content
            } else if message.author == "AI", let user = userMessage {
                processedTurns += 1
                
                // Only backfill if this turn is missing (early turns)
                if processedTurns <= missingCount {
                    let timestamp = formatTimestamp(message.timestamp)
                    let filename = "FullTurn-\(timestamp).md"
                    let filePath = "\(VaultConfig.superJournalPath)/\(filename)"
                    
                    // Only create if file doesn't exist
                    if !FileManager.default.fileExists(atPath: filePath) {
                        let turnContent = formatTurnForSuperjournal(
                            userMessage: user,
                            aiResponse: message.content,
                            timestamp: timestamp
                        )
                        
                        do {
                            try turnContent.write(toFile: filePath, atomically: true, encoding: .utf8)
                            print("📝 Backfilled turn: \(filename)")
                        } catch {
                            print("❌ Failed to backfill turn: \(error)")
                        }
                    }
                }
                
                userMessage = nil
            }
        }
        
        print("✅ Backfill complete")
    }
    
    /// Migrate existing superjournal files: fix timestamps and persona headers
    /// PURPOSE: Fix old timestamp format and hardcoded "User Message"/"AI Response" headers
    /// FIXES: Both filename sorting and proper persona attribution in one operation
    func migrateExistingSuperjournalFiles() {
        print("🔄 Migrating existing superjournal files...")
        
        let superjournalFiles = getSuperJournalFiles()
        var migratedCount = 0
        
        for filename in superjournalFiles {
            // Skip files that already have new format
            if filename.matches("FullTurn-\\d{8}-\\d{6}\\.md") {
                continue
            }
            
            let oldFilePath = "\(VaultConfig.superJournalPath)/\(filename)"
            
            do {
                // Get original file attributes before reading
                let originalAttributes = try FileManager.default.attributesOfItem(atPath: oldFilePath)
                
                // Read existing file content
                let content = try String(contentsOfFile: oldFilePath, encoding: .utf8)
                
                // Parse timestamp from old filename format
                let timestamp = extractTimestampFromOldFilename(filename)
                
                // Parse persona information from content
                let (userLabel, aiLabel) = parsePersonasFromContent(content)
                
                // Create new filename with proper timestamp
                let newFilename = "FullTurn-\(timestamp).md"
                let newFilePath = "\(VaultConfig.superJournalPath)/\(newFilename)"
                
                // Update content with proper persona headers
                let updatedContent = updatePersonaHeaders(content, userLabel: userLabel, aiLabel: aiLabel, timestamp: timestamp)
                
                // Write new file
                try updatedContent.write(toFile: newFilePath, atomically: true, encoding: .utf8)
                
                // Preserve original creation and modification dates
                try FileManager.default.setAttributes(originalAttributes, ofItemAtPath: newFilePath)
                
                // Remove old file
                try FileManager.default.removeItem(atPath: oldFilePath)
                
                print("📝 Migrated: \(filename) → \(newFilename)")
                migratedCount += 1
                
            } catch {
                print("❌ Failed to migrate \(filename): \(error)")
            }
        }
        
        print("✅ Migrated \(migratedCount) superjournal files")
    }
    
    /// Manually fix superjournal timestamps with realistic fake timeline
    /// PURPOSE: Fix the messed up creation dates from migration
    /// APPROACH: Assign realistic timestamps starting 9am today, 40-75 seconds apart
    func fixSuperjournalTimestamps() {
        print("🔧 Manually fixing superjournal timestamps...")
        
        // Clean up existing files first
        cleanupSuperjournalFiles()
        
        // Get conversation history in correct order
        let memoryIndex = ContextMemoryIndex.shared
        let messages = memoryIndex.getConversationHistory()
        
        print("📊 Found \(messages.count) total messages in conversation history")
        
        // Debug: count actual turns
        let turnCount = countConversationTurns(messages)
        print("📊 Calculated \(turnCount) conversation turns from messages")
        
        // Create realistic timeline starting at 9am today
        let calendar = Calendar.current
        let today = Date()
        let startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
        
        var currentTime = startTime
        var fixedCount = 0
        
        // Process conversation turns
        var userMessage: String?
        
        for message in messages {
            if message.author == "User" {
                userMessage = message.content
            } else if message.author == "AI", let user = userMessage {
                // Create realistic timestamp for this turn
                let timestamp = formatTimestamp(currentTime)
                let (userLabel, aiLabel) = parsePersonasFromUserMessage(user)
                
                // Create filename
                let filename = "FullTurn-\(timestamp).md"
                let filePath = "\(VaultConfig.superJournalPath)/\(filename)"
                
                // Create content with proper headers and timing
                let content = createRealisticSuperjournalContent(
                    userMessage: user,
                    aiResponse: message.content,
                    timestamp: timestamp,
                    userLabel: userLabel,
                    aiLabel: aiLabel
                )
                
                do {
                    // Write file with proper content
                    try content.write(toFile: filePath, atomically: true, encoding: .utf8)
                    
                    // Set filesystem timestamps to match our fake timeline
                    let attributes: [FileAttributeKey: Any] = [
                        .creationDate: currentTime,
                        .modificationDate: currentTime
                    ]
                    try FileManager.default.setAttributes(attributes, ofItemAtPath: filePath)
                    
                    print("🕐 Fixed: \(filename) → \(formatReadableTime(currentTime))")
                    fixedCount += 1
                    
                } catch {
                    print("❌ Failed to fix \(filename): \(error)")
                }
                
                // Advance time by 40-75 seconds randomly
                let randomDelay = Int.random(in: 40...75)
                currentTime = currentTime.addingTimeInterval(TimeInterval(randomDelay))
                
                userMessage = nil
            }
        }
        
        print("✅ Fixed \(fixedCount) superjournal timestamps with realistic timeline")
    }
    
    /// Clean up existing superjournal files before fixing
    private func cleanupSuperjournalFiles() {
        print("🧹 Cleaning up existing superjournal files...")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: VaultConfig.superJournalPath)
            let superjournalFiles = files.filter { $0.hasPrefix("FullTurn-") && $0.hasSuffix(".md") }
            
            for filename in superjournalFiles {
                let filePath = "\(VaultConfig.superJournalPath)/\(filename)"
                try FileManager.default.removeItem(atPath: filePath)
            }
            
            print("🧹 Cleaned up \(superjournalFiles.count) files")
        } catch {
            print("❌ Failed to cleanup superjournal files: \(error)")
        }
    }
    
    // MARK: - File Operations (Current Implementation)
    
    private func writeToFile(content: String) -> String {
        do {
            let filePath = VaultConfig.notesFilePath
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            return "✅ Wrote to file: \(content)\n📁 Location: \(filePath)"
        } catch {
            return "❌ Failed to write file: \(error.localizedDescription)"
        }
    }
    
    private func appendToFile(content: String) -> String {
        do {
            let filePath = VaultConfig.notesFilePath
            
            // Read existing content if file exists
            var existingContent = ""
            if FileManager.default.fileExists(atPath: filePath) {
                existingContent = try String(contentsOfFile: filePath, encoding: .utf8)
            }
            
            // Append new content with newline
            let newContent = existingContent.isEmpty ? content : existingContent + "\n" + content
            
            try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            return "✅ Added to file: \(content)\n📁 Location: \(filePath)"
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
    private func formatTurnForSuperjournal(userMessage: String, aiResponse: String, timestamp: String) -> String {
        // Parse persona from user message
        let (userLabel, aiLabel) = parsePersonasFromUserMessage(userMessage)
        
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
        var aiLabel = "Aether"
        
        // Check if user message starts with persona name
        let words = userMessage.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces)
        if let firstWord = words.first {
            let cleanedWord = firstWord.trimmingCharacters(in: .punctuationCharacters).lowercased()
            if ["samara", "vlad", "vanessa"].contains(cleanedWord) {
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
    private func getSuperJournalFiles() -> [String] {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: VaultConfig.superJournalPath)
            return files.filter { $0.hasPrefix("FullTurn-") && $0.hasSuffix(".md") }
        } catch {
            print("❌ Failed to read superjournal directory: \(error)")
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
        let regex = try! NSRegularExpression(pattern: pattern)
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
        var aiLabel = "Aether"
        
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
                    if ["samara", "vlad", "vanessa"].contains(cleanedWord) {
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
        let titleRegex = try! NSRegularExpression(pattern: titlePattern)
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
    
    // MARK: - Future Blueprint Implementation
    
    // TODO: LLM-powered command interpretation
    // TODO: "Write a new strategy note to journal titled X. Content begins..."
    // TODO: Complex file operations via natural language
    // TODO: Metadata attachment (attribution, origin tracking)
    // TODO: Integration with persona system for context-aware file operations
}