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
    private let taxonomyManager = TaxonomyManager.shared
    
    // MARK: - Conversation State for Scrollback
    private var storedMessages: [ChatMessage] = []
    
    private init() {
        loadConversationFromSuperjournal()
    }
    
    // MARK: - Memory Context (Current Implementation)
    
    /// Get conversation context for scrollback UI only
    /// SEPARATION OF CONCERNS: ContextMemoryIndex serves UI, OmniscientBundleBuilder serves LLM
    /// RESPONSIBILITY: Reconstruct conversation history for display purposes only
    func getConversationContext() -> String {
        let messages = storedMessages // Use stored conversation state
        
        // Simple conversation text for UI/debugging purposes
        if messages.isEmpty {
            return "No conversation history available"
        }
        
        let conversationText = messages.map { message in
            "\(message.author): \(message.content)"
        }.joined(separator: "\n\n")
        
        return """
        Previous conversation:
        
        \(conversationText)
        """
    }
    
    /// Get full conversation history as ChatMessage array
    /// CURRENT: Loads conversation state for scrollback display
    /// BLUEPRINT: Eventually includes all vault sources with intelligent consolidation
    func getConversationHistory() -> [ChatMessage] {
        return storedMessages
    }
    
    /// Save conversation state for scrollback persistence
    /// CURRENT: Simple in-memory storage for scrollback display
    /// BLUEPRINT: Eventually triggers semantic consolidation when memory grows large
    func saveConversationHistory(_ messages: [ChatMessage]) {
        storedMessages = messages
    }
    
    /// Load conversation history from superjournal files on app startup
    /// CURRENT: Reconstruct scrollback from superjournal backup files
    private func loadConversationFromSuperjournal() {
        let superjournalPath = VaultConfig.superJournalPath
        
        guard FileManager.default.fileExists(atPath: superjournalPath) else {
            print("📖 No superjournal directory found")
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: superjournalPath)
            let superjournalFiles = files.filter { $0.hasPrefix("FullTurn-") && $0.hasSuffix(".md") }
                .sorted() // Chronological order
            
            var reconstructedMessages: [ChatMessage] = []
            
            for filename in superjournalFiles {
                let filePath = "\(superjournalPath)/\(filename)"
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                
                if let messages = parseSuperjournalFile(content, filename: filename) {
                    reconstructedMessages.append(contentsOf: messages)
                }
            }
            
            storedMessages = reconstructedMessages
            print("📖 Loaded \(reconstructedMessages.count) messages from superjournal")
            
        } catch {
            print("❌ Failed to load conversation from superjournal: \(error)")
        }
    }
    
    /// Parse superjournal file to extract ChatMessage objects
    private func parseSuperjournalFile(_ content: String, filename: String) -> [ChatMessage]? {
        let lines = content.components(separatedBy: .newlines)
        
        var userMessage: String?
        var aiMessage: String?
        var persona: String?
        var isCollectingUser = false
        var isCollectingAI = false
        
        for line in lines {
            if line.hasPrefix("## Boss") {
                isCollectingUser = true
                isCollectingAI = false
            } else if line.hasPrefix("## ") && !line.hasPrefix("## Boss") {
                // Dynamic persona detection from header
                let personaName = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                isCollectingUser = false
                isCollectingAI = true
                persona = personaName.lowercased()
            } else if line.hasPrefix("---") || line.hasPrefix("*End of turn*") || line.hasPrefix("#") {
                isCollectingUser = false
                isCollectingAI = false
            } else if isCollectingUser && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                userMessage = (userMessage ?? "") + line + "\n"
            } else if isCollectingAI && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                aiMessage = (aiMessage ?? "") + line + "\n"
            }
        }
        
        // Create ChatMessage objects
        var messages: [ChatMessage] = []
        
        if let userContent = userMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !userContent.isEmpty {
            let userMsg = ChatMessage(content: userContent, author: "User", persona: nil)
            messages.append(userMsg)
        }
        
        if let aiContent = aiMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !aiContent.isEmpty {
            let aiMsg = ChatMessage(content: aiContent, author: "AI", persona: persona)
            messages.append(aiMsg)
        }
        
        return messages.isEmpty ? nil : messages
    }
    
    // MARK: - Taxonomy-Aware Memory Retrieval
    
    /// Get relevant journal entries based on topic hierarchy
    /// BLUEPRINT: "Structured metadata for future semantic search"
    /// USAGE: Retrieve contextually relevant memories using taxonomy structure
    func getJournalEntriesByTopic(_ topicHierarchy: String) -> [String] {
        let journalPath = "\(VaultConfig.journalPath)"
        var relevantEntries: [String] = []
        
        do {
            let journalFiles = try FileManager.default.contentsOfDirectory(atPath: journalPath)
            let trimFiles = journalFiles.filter { $0.hasPrefix("Trim-") && $0.hasSuffix(".md") }
            
            for filename in trimFiles {
                let filePath = "\(journalPath)/\(filename)"
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    // Parse trim metadata to check topic hierarchy
                    if let metadata = taxonomyManager.parseTrimMetadata(content) {
                        // Check for exact match or hierarchical relationship
                        if isTopicRelated(metadata.topicHierarchy, to: topicHierarchy) {
                            relevantEntries.append(content)
                        }
                    }
                }
            }
        } catch {
            print("❌ Error loading journal entries: \(error)")
        }
        
        return relevantEntries.sorted() // Chronological order
    }
    
    /// Get journal entries by keywords
    /// BLUEPRINT: "Structured keyword extraction for future relevance matching"
    func getJournalEntriesByKeywords(_ keywords: [String]) -> [String] {
        let journalPath = "\(VaultConfig.journalPath)"
        var relevantEntries: [String] = []
        
        do {
            let journalFiles = try FileManager.default.contentsOfDirectory(atPath: journalPath)
            let trimFiles = journalFiles.filter { $0.hasPrefix("Trim-") && $0.hasSuffix(".md") }
            
            for filename in trimFiles {
                let filePath = "\(journalPath)/\(filename)"
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    // Parse trim metadata to check keywords
                    if let metadata = taxonomyManager.parseTrimMetadata(content) {
                        // Check for keyword overlap
                        let keywordOverlap = Set(metadata.keywords).intersection(Set(keywords))
                        if !keywordOverlap.isEmpty {
                            relevantEntries.append(content)
                        }
                    }
                }
            }
        } catch {
            print("❌ Error loading journal entries: \(error)")
        }
        
        return relevantEntries.sorted() // Chronological order
    }
    
    /// Get journal entries by dependency relationships
    /// BLUEPRINT: "Cross-turn dependency tracking"
    func getJournalEntriesByDependencies(_ dependencyTypes: [String]) -> [String] {
        let journalPath = "\(VaultConfig.journalPath)"
        var relevantEntries: [String] = []
        
        do {
            let journalFiles = try FileManager.default.contentsOfDirectory(atPath: journalPath)
            let trimFiles = journalFiles.filter { $0.hasPrefix("Trim-") && $0.hasSuffix(".md") }
            
            for filename in trimFiles {
                let filePath = "\(journalPath)/\(filename)"
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    // Parse trim metadata to check dependencies
                    if let metadata = taxonomyManager.parseTrimMetadata(content) {
                        // Check for dependency type matches
                        for dependency in metadata.dependencies {
                            let dependencyType = dependency.components(separatedBy: ":").first ?? ""
                            if dependencyTypes.contains(dependencyType) {
                                relevantEntries.append(content)
                                break
                            }
                        }
                    }
                }
            }
        } catch {
            print("❌ Error loading journal entries: \(error)")
        }
        
        return relevantEntries.sorted() // Chronological order
    }
    
    /// Get journal entries with specific sentiment
    /// BLUEPRINT: "Sentiment tracking for emotionally significant moments"
    func getJournalEntriesBySentiment(_ sentimentType: String) -> [String] {
        let journalPath = "\(VaultConfig.journalPath)"
        var relevantEntries: [String] = []
        
        do {
            let journalFiles = try FileManager.default.contentsOfDirectory(atPath: journalPath)
            let trimFiles = journalFiles.filter { $0.hasPrefix("Trim-") && $0.hasSuffix(".md") }
            
            for filename in trimFiles {
                let filePath = "\(journalPath)/\(filename)"
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    // Parse trim metadata to check sentiment
                    if let metadata = taxonomyManager.parseTrimMetadata(content),
                       let sentiment = metadata.sentiment {
                        if sentiment.lowercased().contains(sentimentType.lowercased()) {
                            relevantEntries.append(content)
                        }
                    }
                }
            }
        } catch {
            print("❌ Error loading journal entries: \(error)")
        }
        
        return relevantEntries.sorted() // Chronological order
    }
    
    /// Check if two topic hierarchies are related
    /// BLUEPRINT: "Hierarchical topic classification" - enables semantic relationship detection
    private func isTopicRelated(_ topic1: String, to topic2: String) -> Bool {
        let components1 = topic1.components(separatedBy: "/")
        let components2 = topic2.components(separatedBy: "/")
        
        // Exact match
        if topic1 == topic2 { return true }
        
        // Hierarchical relationship (one is parent of the other)
        let minLength = min(components1.count, components2.count)
        let commonPrefix = Array(components1.prefix(minLength)) == Array(components2.prefix(minLength))
        
        return commonPrefix
    }
    
    // MARK: - Enhanced Omniscient Context
    
    /// Get context-aware memory for UI debugging only
    /// SEPARATION OF CONCERNS: LLM context now handled by OmniscientBundleBuilder
    func getContextAwareMemory(for userMessage: String) -> String {
        // This method is now only for UI/debugging purposes
        // Real LLM context assembly happens in OmniscientBundleBuilder
        
        let baseContext = getConversationContext()
        return """
        UI Context Debug:
        \(baseContext)
        
        Note: LLM receives full omniscient bundle from OmniscientBundleBuilder
        """
    }
    
    // MARK: - Memory Analytics
    
    /// Get memory statistics with taxonomy insights
    /// BLUEPRINT: "Quality metrics - consistency score, coverage analysis"
    func getMemoryAnalytics() -> [String: Any] {
        var analytics = taxonomyManager.getTaxonomyStats()
        
        // Add journal statistics
        let journalPath = "\(VaultConfig.journalPath)"
        do {
            let journalFiles = try FileManager.default.contentsOfDirectory(atPath: journalPath)
            let trimFiles = journalFiles.filter { $0.hasPrefix("Trim-") && $0.hasSuffix(".md") }
            
            analytics["totalJournalEntries"] = trimFiles.count
            analytics["memoryIndexStatus"] = "taxonomy-enabled"
            
            // Count entries by topic categories
            var topicCounts: [String: Int] = [:]
            for filename in trimFiles {
                let filePath = "\(journalPath)/\(filename)"
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8),
                   let metadata = taxonomyManager.parseTrimMetadata(content) {
                    let topCategory = metadata.topicHierarchy.components(separatedBy: "/").first ?? "unknown"
                    topicCounts[topCategory] = (topicCounts[topCategory] ?? 0) + 1
                }
            }
            analytics["topicDistribution"] = topicCounts
            
        } catch {
            analytics["error"] = "Failed to analyze journal entries: \(error)"
        }
        
        return analytics
    }
    
    // MARK: - Future Blueprint Implementation
    
    // TODO: Samara's Threader Role:
    //       - Trigger semantic consolidation when memory grows large
    //       - Collapse resolved topics into single compact .md files
    //       - Reduce 7 interwoven trims → 1 consolidated narrative
    //       - Remove dead-end decisions and conversational detours
    //       - Structured forgetting, not data loss
    // TODO: Vector similarity search for semantic relationships
    // TODO: Temporal pattern analysis for memory consolidation triggers
    // TODO: Cross-persona memory sharing and context isolation
}