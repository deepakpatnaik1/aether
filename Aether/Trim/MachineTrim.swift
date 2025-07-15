//
//  MachineTrim.swift
//  Aether
//
//  Executes Samara-style machine trimming
//

import Foundation

class MachineTrim: ObservableObject {
    
    func compressTurn(userMessage: String, aiResponse: String, persona: String) -> String {
        let topic = extractTopic(from: userMessage, response: aiResponse)
        let sentiment = analyzeSentiment(from: userMessage, response: aiResponse)
        let relationshipTags = generateRelationshipTags(persona: persona, userMessage: userMessage, aiResponse: aiResponse)
        let contextDeltas = generateContextDeltas(userMessage: userMessage, aiResponse: aiResponse, persona: persona)
        
        let compressedUser = compressSemanticContent(userMessage)
        let compressedAI = compressSemanticContent(aiResponse)
        
        var result = ""
        result += "topic: \(topic)\n"
        result += "sentiment: \(sentiment)\n"
        result += "relationship_tags: \(relationshipTags)\n"
        
        if !contextDeltas.isEmpty {
            result += "context_deltas:\n"
            for delta in contextDeltas {
                result += "- \(delta)\n"
            }
        }
        
        result += "\n"
        result += "boss: \(compressedUser)\n"
        result += "\(persona.lowercased()): \(compressedAI)\n"
        
        return result
    }
    
    private func extractTopic(from userMessage: String, response: String) -> String {
        let combined = userMessage + " " + response
        let words = combined.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        // Look for key topic indicators
        if words.contains("particle") || words.contains("collider") || words.contains("cern") || words.contains("physics") {
            return "particle physics discoveries"
        }
        if words.contains("ui") || words.contains("interface") || words.contains("design") || words.contains("glassmorphic") {
            return "UI design implementation"
        }
        if words.contains("memory") || words.contains("trim") || words.contains("compression") || words.contains("journal") {
            return "memory system architecture"
        }
        if words.contains("persona") || words.contains("cognitive") || words.contains("thinking") {
            return "persona cognitive strategy"
        }
        if words.contains("architecture") || words.contains("code") || words.contains("implementation") {
            return "system architecture"
        }
        
        // Fallback: extract key nouns
        let keyWords = words.filter { $0.count > 4 && !["about", "would", "could", "should", "might", "think", "really", "quite", "rather"].contains($0) }
        return keyWords.prefix(3).joined(separator: " ")
    }
    
    private func analyzeSentiment(from userMessage: String, response: String) -> String {
        let combined = (userMessage + " " + response).lowercased()
        
        // Detect emotional tone arc patterns
        if combined.contains("wrong") || combined.contains("disaster") || combined.contains("broken") {
            if combined.contains("right") || combined.contains("fix") || combined.contains("correct") {
                return "concern to resolution"
            }
            return "critical assessment"
        }
        
        if combined.contains("excellent") || combined.contains("perfect") || combined.contains("great") {
            return "appreciative confirmation"
        }
        
        if combined.contains("need") || combined.contains("should") || combined.contains("must") {
            return "directive clarity"
        }
        
        if combined.contains("understand") || combined.contains("see") || combined.contains("clear") {
            return "cognitive alignment"
        }
        
        if combined.contains("implement") || combined.contains("build") || combined.contains("create") {
            return "constructive planning"
        }
        
        return "neutral exchange"
    }
    
    private func generateRelationshipTags(persona: String, userMessage: String, aiResponse: String) -> String {
        var tags: [String] = []
        
        tags.append("boss-\(persona.lowercased())")
        
        let combined = (userMessage + " " + aiResponse).lowercased()
        
        if combined.contains("right") || combined.contains("correct") || combined.contains("exactly") {
            tags.append("trust-reinforced")
        }
        
        if combined.contains("wrong") || combined.contains("disaster") || combined.contains("broken") {
            tags.append("correction-applied")
        }
        
        if combined.contains("thank") || combined.contains("appreciate") || combined.contains("good") {
            tags.append("tone-appreciative")
        }
        
        if combined.contains("need") || combined.contains("must") || combined.contains("should") {
            tags.append("tone-directive")
        }
        
        return tags.joined(separator: ", ")
    }
    
    private func generateContextDeltas(userMessage: String, aiResponse: String, persona: String) -> [String] {
        var deltas: [String] = []
        
        let combined = (userMessage + " " + aiResponse).lowercased()
        
        // Trust shifts
        if combined.contains("wrong") && combined.contains("right") {
            deltas.append("boss: corrects \(persona.lowercased()) assessment")
            deltas.append("\(persona.lowercased()): acknowledges error and realigns")
        }
        
        // Tone reversals
        if combined.contains("disaster") && combined.contains("fix") {
            deltas.append("boss: shifts from concern to solution focus")
        }
        
        // Role redefinition
        if combined.contains("implement") && combined.contains("plan") {
            deltas.append("\(persona.lowercased()): transitions from analysis to execution mode")
        }
        
        return deltas
    }
    
    private func compressSemanticContent(_ content: String) -> String {
        var compressed = content
        
        // Strip hedges and filler
        let hedges = ["I think", "I believe", "perhaps", "maybe", "sort of", "kind of", "really", "quite", "rather", "actually", "basically", "essentially", "obviously", "clearly", "of course"]
        
        for hedge in hedges {
            compressed = compressed.replacingOccurrences(of: hedge, with: "", options: .caseInsensitive)
        }
        
        // Remove excessive politeness
        compressed = compressed.replacingOccurrences(of: "please", with: "", options: .caseInsensitive)
        compressed = compressed.replacingOccurrences(of: "thank you", with: "", options: .caseInsensitive)
        
        // Clean up multiple spaces and newlines
        compressed = compressed.replacingOccurrences(of: "  ", with: " ")
        compressed = compressed.replacingOccurrences(of: "\n\n", with: "\n")
        compressed = compressed.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return compressed
    }
}