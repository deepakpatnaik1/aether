//
//  EnvFileParser.swift
//  Aether
//
//  Environment file parsing utility for secure API key management
//
//  BLUEPRINT SECTION: 🚨 Core - Configuration Management
//  =====================================================
//
//  DESIGN PRINCIPLES:
//  - Separation of Concerns: Pure .env file operations, no configuration logic
//  - No Hardcoding: Configurable search paths, no fixed user directories
//  - Modularity: Reusable across any component needing .env parsing
//  - Security: Safe file handling with proper error management
//
//  RESPONSIBILITIES:
//  - Discover .env files across multiple search locations
//  - Parse .env file content with proper key=value extraction
//  - Handle comments, empty lines, and quoted values
//  - Provide clean interface for key lookup
//
//  USAGE:
//  - LLMConfiguration uses for API key resolution
//  - Future: Other services can use for their own .env needs

import Foundation

class EnvFileParser {
    
    // MARK: - Search Path Configuration
    
    /// Generate .env file search paths in priority order
    static func getSearchPaths() -> [String] {
        [
            // Bundle resource (most reliable for sandboxed apps)
            Bundle.main.path(forResource: ".env", ofType: nil) ?? "",
            // Current working directory
            FileManager.default.currentDirectoryPath + "/.env",
            // Project directory (derived from bundle path)
            deriveProjectPath() + "/.env"
        ].filter { !$0.isEmpty }
    }
    
    /// Derive project path from bundle location (no hardcoding)
    private static func deriveProjectPath() -> String {
        let bundlePath = Bundle.main.bundlePath
        
        // Navigate up from build artifacts to project root
        let url = URL(fileURLWithPath: bundlePath)
        return url.deletingLastPathComponent()
                 .deletingLastPathComponent()
                 .deletingLastPathComponent()
                 .deletingLastPathComponent()
                 .path
    }
    
    // MARK: - Key Resolution
    
    /// Load API key from .env file using configurable search paths
    static func loadKey(_ key: String) -> String {
        for envPath in getSearchPaths() {
            if let envContent = tryLoadFile(at: envPath) {
                print("✅ Found .env file at: \(envPath)")
                if let value = parseKey(from: envContent, key: key) {
                    return value
                }
            }
        }
        
        print("❌ No .env file found or key '\(key)' not found")
        print("💡 To fix: Add .env file to Xcode project as bundle resource")
        return ""
    }
    
    /// Load and parse entire .env file into dictionary
    static func loadAllKeys() -> [String: String] {
        for envPath in getSearchPaths() {
            if let envContent = tryLoadFile(at: envPath) {
                print("✅ Found .env file at: \(envPath)")
                return parseAllKeys(from: envContent)
            }
        }
        
        print("❌ No .env file found in search paths")
        return [:]
    }
    
    // MARK: - File Operations
    
    /// Attempt to load .env file content from path
    private static func tryLoadFile(at path: String) -> String? {
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    // MARK: - Content Parsing
    
    /// Parse specific key from .env file content
    private static func parseKey(from envContent: String, key: String) -> String? {
        for line in envContent.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip comments and empty lines
            guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { continue }
            
            // Match key=value pattern
            if trimmed.hasPrefix(key + "=") {
                let value = String(trimmed.dropFirst(key.count + 1))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                print("✅ Found \(key) in .env file")
                return value
            }
        }
        
        return nil
    }
    
    /// Parse all keys from .env file content into dictionary
    private static func parseAllKeys(from envContent: String) -> [String: String] {
        var keyValuePairs: [String: String] = [:]
        
        for line in envContent.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip comments and empty lines
            guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { continue }
            
            // Split on first = only
            if let equalIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(trimmed[trimmed.index(after: equalIndex)...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"' \t"))
                
                if !key.isEmpty {
                    keyValuePairs[key] = value
                }
            }
        }
        
        return keyValuePairs
    }
    
    // MARK: - Validation
    
    /// Check if .env file exists and is readable
    static func validateEnvFile() -> Bool {
        return !getSearchPaths().isEmpty && getSearchPaths().contains { path in
            FileManager.default.isReadableFile(atPath: path)
        }
    }
    
    /// Get path of first found .env file
    static func getEnvFilePath() -> String? {
        return getSearchPaths().first { path in
            FileManager.default.isReadableFile(atPath: path)
        }
    }
}