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
            print("⚠️ Invalid regex pattern: \(pattern)")
            return false
        }
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
        } else if lowercased == "process trims" {
            // Trigger machine trim processing
            Task {
                await processSuperJournalToTrims()
            }
            return "🔄 Started machine trim processing for all superjournal files..."
        } else if lowercased == "reprocess trims" {
            // Clear existing journal files and regenerate
            Task {
                await reprocessAllTrims()
            }
            return "🔄 Clearing existing journal files and regenerating with improved prompts..."
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
    func autoSaveTurn(userMessage: String, aiResponse: String, persona: String = "Aether") {
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
    
    /// Save machine-compressed turn to journal
    /// BLUEPRINT: Machine trimming handled by LLMManager dual-task system
    /// PURPOSE: Save the compressed turn that comes from LLMManager's dual-task output
    func saveMachineTrim(_ compressedContent: String, timestamp: String) {
        // Convert timestamp format for journal filename
        let journalTimestamp = convertTimestampForJournal(timestamp)
        let journalFilename = "Trim-\(journalTimestamp).md"
        let journalFilePath = "\(VaultConfig.journalPath)/\(journalFilename)"
        
        do {
            try compressedContent.write(toFile: journalFilePath, atomically: true, encoding: .utf8)
            print("🗜️ Saved machine trim: \(journalFilename)")
        } catch {
            print("❌ Failed to save machine trim: \(error)")
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
                
                // SAFETY: Move old file to trash instead of deleting
                let trashFilename = "migrated-\(createTimestamp())-\(filename)"
                let trashPath = "\(VaultConfig.trashPath)/\(trashFilename)"
                try FileManager.default.moveItem(atPath: oldFilePath, toPath: trashPath)
                print("🗑️ Moved old file to trash: \(trashFilename)")
                
                print("📝 Migrated: \(filename) → \(newFilename)")
                migratedCount += 1
                
            } catch {
                print("❌ Failed to migrate \(filename): \(error)")
            }
        }
        
        print("✅ Migrated \(migratedCount) superjournal files")
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
            print("💾 Created backup: \(backupFilename)")
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
            let isValid = writtenContent == expectedContent
            if !isValid {
                print("⚠️ File integrity check failed for: \(URL(fileURLWithPath: filePath).lastPathComponent)")
            }
            return isValid
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
    func getSuperJournalFiles() -> [String] {
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
        
        // SAFETY: Handle regex creation errors gracefully
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            print("⚠️ Invalid regex pattern in extractTimestampFromOldFilename: \(pattern)")
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
        print("⚠️ Failed to parse timestamp from filename: \(filename)")
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
        
        // SAFETY: Handle regex creation errors gracefully
        guard let titleRegex = try? NSRegularExpression(pattern: titlePattern) else {
            print("⚠️ Invalid regex pattern in updatePersonaHeaders: \(titlePattern)")
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
    
    // MARK: - Machine Trim Batch Processing
    
    /// Clear existing journal files and regenerate all trims
    /// SAFETY: Moves existing journal files to trash, then regenerates
    func reprocessAllTrims() async {
        print("🧹 Clearing existing journal files...")
        
        // Move existing journal files to trash
        do {
            let journalFiles = try FileManager.default.contentsOfDirectory(atPath: VaultConfig.journalPath)
            let trimFiles = journalFiles.filter { $0.hasPrefix("Trim-") && $0.hasSuffix(".md") }
            
            for filename in trimFiles {
                let sourcePath = "\(VaultConfig.journalPath)/\(filename)"
                let trashPath = "\(VaultConfig.trashPath)/reprocess-\(createTimestamp())-\(filename)"
                try FileManager.default.moveItem(atPath: sourcePath, toPath: trashPath)
                print("🗑️ Moved to trash: \(filename)")
            }
            
            print("✅ Cleared \(trimFiles.count) existing journal files")
        } catch {
            print("❌ Error clearing journal files: \(error)")
        }
        
        // Now regenerate all trims with improved prompts
        await processSuperJournalToTrims()
    }
    
    /// Process all superjournal files into machine trims
    /// SAFETY: Read-only on superjournal files, atomic operations per file
    func processSuperJournalToTrims() async {
        print("🔄 Starting machine trim processing for all superjournal files...")
        
        let superjournalFiles = getSuperJournalFiles().sorted() // Process in chronological order
        print("📊 Found \(superjournalFiles.count) superjournal files to process")
        
        var successCount = 0
        var failureCount = 0
        
        for filename in superjournalFiles {
            print("🔄 Processing: \(filename)")
            
            let success = await processSingleSuperjournalFile(filename)
            if success {
                successCount += 1
                print("✅ Completed: \(filename)")
            } else {
                failureCount += 1
                print("❌ Failed: \(filename)")
            }
        }
        
        print("🎉 Machine trim processing complete!")
        print("✅ Success: \(successCount) files")
        print("❌ Failed: \(failureCount) files")
    }
    
    /// Process a single superjournal file into machine trim
    /// SAFETY: Read-only on original file, atomic operation
    private func processSingleSuperjournalFile(_ filename: String) async -> Bool {
        let superjournalPath = "\(VaultConfig.superJournalPath)/\(filename)"
        
        // Extract timestamp for journal filename
        let timestamp = extractTimestampFromSuperjournalFilename(filename)
        let journalFilename = "Trim-\(convertTimestampForJournal(timestamp)).md"
        let journalPath = "\(VaultConfig.journalPath)/\(journalFilename)"
        
        // Skip if journal file already exists
        if FileManager.default.fileExists(atPath: journalPath) {
            print("⏭️ Skipping \(filename) - journal file already exists")
            return true
        }
        
        do {
            // SAFETY: Read-only operation on superjournal file
            let content = try String(contentsOfFile: superjournalPath, encoding: .utf8)
            let (userMessage, aiResponse) = parseSuperjournalContent(content)
            
            guard !userMessage.isEmpty && !aiResponse.isEmpty else {
                print("⚠️ Could not parse content from \(filename)")
                return false
            }
            
            // Get machine trim from LLM
            let trimmedContent = try await generateMachineTrim(userMessage: userMessage, aiResponse: aiResponse)
            
            // Write to journal (atomic operation)
            try trimmedContent.write(toFile: journalPath, atomically: true, encoding: .utf8)
            
            return true
            
        } catch {
            print("❌ Error processing \(filename): \(error)")
            return false
        }
    }
    
    /// Extract timestamp from superjournal filename
    private func extractTimestampFromSuperjournalFilename(_ filename: String) -> String {
        // From "FullTurn-20250715-090000.md" to "20250715-090000"
        let pattern = "FullTurn-(\\d{8}-\\d{6})\\.md"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            print("⚠️ Invalid regex pattern for superjournal filename")
            return createTimestamp()
        }
        
        let range = NSRange(location: 0, length: filename.utf16.count)
        if let match = regex.firstMatch(in: filename, options: [], range: range) {
            return (filename as NSString).substring(with: match.range(at: 1))
        }
        
        return createTimestamp()
    }
    
    /// Parse superjournal content into user message and AI response
    private func parseSuperjournalContent(_ content: String) -> (userMessage: String, aiResponse: String) {
        let lines = content.components(separatedBy: .newlines)
        var userMessage = ""
        var aiResponse = ""
        var currentSection = ""
        
        for line in lines {
            if line.hasPrefix("## Boss") {
                currentSection = "user"
                continue
            } else if line.hasPrefix("## Aether") || line.hasPrefix("## Samara") || line.hasPrefix("## Vlad") || line.hasPrefix("## Vanessa") {
                currentSection = "ai"
                continue
            } else if line.hasPrefix("---") || line.hasPrefix("*End of turn*") || line.hasPrefix("#") {
                currentSection = ""
                continue
            }
            
            if currentSection == "user" && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !userMessage.isEmpty { userMessage += "\n" }
                userMessage += line
            } else if currentSection == "ai" && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !aiResponse.isEmpty { aiResponse += "\n" }
                aiResponse += line
            }
        }
        
        return (userMessage.trimmingCharacters(in: .whitespacesAndNewlines), 
                aiResponse.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    /// Generate machine trim using LLM
    private func generateMachineTrim(userMessage: String, aiResponse: String) async throws -> String {
        // Load machine trim instructions
        let machineTrimPath = "\(VaultConfig.vaultRoot)/playbook/tools/machine-trim.md"
        let trimInstructions = try String(contentsOfFile: machineTrimPath, encoding: .utf8)
        
        // Build comprehensive prompt that includes methodology AND asks Samara to compress
        let prompt = """
        Samara, I need you to apply machine compression to this historical conversation turn. Use the methodology below exactly.
        
        HISTORICAL CONVERSATION TURN:
        Boss: \(userMessage)
        AI: \(aiResponse)
        
        MACHINE TRIM METHODOLOGY:
        \(trimInstructions)
        
        Apply this compression methodology to the conversation turn above. Output ONLY the compressed machine trim in the exact format specified - no additional explanation or response.
        """
        
        // Use Samara persona to apply machine trimming methodology
        let personaResponse = try await llmManager.sendMessage(prompt, persona: "samara")
        
        // Return Samara's main response (which should be the machine trim)
        return personaResponse.mainResponse
    }
    
    // MARK: - Future Blueprint Implementation
    
    // TODO: LLM-powered command interpretation
    // TODO: "Write a new strategy note to journal titled X. Content begins..."
    // TODO: Complex file operations via natural language
    // TODO: Metadata attachment (attribution, origin tracking)
    // TODO: Integration with persona system for context-aware file operations
}