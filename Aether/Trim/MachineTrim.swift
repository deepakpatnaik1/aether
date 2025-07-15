//
//  MachineTrim.swift
//  Aether
//
//  Machine trimming handled by LLMManager dual-task system
//  This class is no longer needed - LLMManager handles omniscient compression
//

import Foundation

class MachineTrim: ObservableObject {
    // DEPRECATED: Machine trimming now handled by LLMManager dual-task system
    // The LLM receives omniscient context and performs both tasks:
    // 1. Natural persona response (goes to scrollback)
    // 2. Machine-compressed turn (goes to journal)
    
    // This approach was replaced because:
    // - Programmatic compression can't match LLM intelligence
    // - LLM already has omniscient context from PersonaRegistry
    // - Dual-task system is more elegant and follows Blueprint 4.0
    
    // TODO: Remove this file entirely once VaultWriter is updated
}