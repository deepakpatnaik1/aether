# Blueprint 5.0: Complete Aether Persona Lifecycle

## Complete Aether Persona Lifecycle - Turn 1 and Beyond

### **Turn 1: First App Launch (Cold Start)**

#### **1. App Initialization**
```
App Starts → MessageStore.init() → loadCurrentPersona()
```

**What happens in `loadCurrentPersona()`:**
- Checks for `/vault/playbook/tools/currentPersona.md`
- **File doesn't exist** (first time)
- Sets `currentPersona = "samara"` (first-time default)
- **Immediately saves** "samara" to `currentPersona.md`
- **Result**: `currentPersona = "samara"` in memory AND vault

#### **2. Boss Input: "Samara, what is quantum computing?"**

**Parse Phase:**
- `parsePersonaFromMessage()` extracts first word: "Samara"
- Finds match in PersonaRegistry
- Calls `setCurrentPersona("samara")`
- **Already "samara"** → No change, but still saves to vault

#### **3. LLM Request Assembly**
```
coordinateLLMResponse(persona: "samara") 
→ LLMManager.sendMessage(persona: "samara")
→ buildPersonaPrompt(persona: "samara")
→ actualPersona = "samara" (not nil, so uses passed value)
→ OmniscientBundleBuilder.buildBundle(for: "samara")
```

**Bundle Contents:**
- instructions-to-llm.md (header)
- boss/ context
- **personas/Samara/** context ← Correct persona folder
- tools/ context  
- journal/ context
- User message

#### **4. LLM Response Processing**
- LLM responds as Samara (instructed by bundle)
- `startAIMessage(persona: "samara")` creates ChatMessage
- Response displayed in scrollback with "Samara" attribution
- `autoSaveCompleteTurn(persona: "samara")` saves to superjournal
- Machine trim saved to journal

### **Turn 2: Boss says "explain machine learning"** (no persona mentioned)

#### **1. Parse Phase**
- `parsePersonaFromMessage()` finds no persona in first word
- `targetPersona = nil`
- **No call to `setCurrentPersona()`**
- `currentPersona` remains "samara" in memory

#### **2. LLM Request Assembly**
```
coordinateLLMResponse(persona: getCurrentPersona()) // returns "samara"
→ LLMManager.sendMessage(persona: "samara") 
→ buildPersonaPrompt(persona: "samara")
→ actualPersona = "samara" (uses passed value)
→ OmniscientBundleBuilder.buildBundle(for: "samara")
```

**Result**: Still uses Samara's persona folder and voice

### **Turn 15: Boss says "Vlad, analyze this data"**

#### **1. Parse Phase**
- `parsePersonaFromMessage()` extracts "Vlad"
- Calls `setCurrentPersona("vlad")`
- **Updates memory**: `currentPersona = "vlad"`
- **Saves to vault**: Writes "vlad" to `currentPersona.md`

#### **2. LLM Request Assembly**
```
coordinateLLMResponse(persona: "vlad")
→ OmniscientBundleBuilder.buildBundle(for: "vlad")
```

**Bundle Contents:**
- instructions-to-llm.md
- boss/ context
- **personas/Vlad/** context ← Switched to Vlad's folder
- tools/ context
- journal/ context
- User message

### **App Restart After 100 Turns**

#### **1. App Initialization**
```
App Starts → MessageStore.init() → loadCurrentPersona()
```

**What happens:**
- Checks `/vault/playbook/tools/currentPersona.md`
- **File exists** with content "vlad"
- Sets `currentPersona = "vlad"` (loaded from vault)
- **No save needed** - already persisted

#### **2. First Message: "what's the weather?"** (no persona)

```
coordinateLLMResponse(persona: getCurrentPersona()) // returns "vlad"
→ OmniscientBundleBuilder.buildBundle(for: "vlad")
```

**Result**: Continues with Vlad, seamlessly across restart

### **The Complete Persistence Chain**

#### **Memory Layer:**
- `MessageStore.currentPersona` (in-memory, session-based)

#### **Vault Layer:**
- `/vault/playbook/tools/currentPersona.md` (persistent, eternal)

#### **Attribution Points:**
1. **Scrollback**: `ChatMessage.persona` field
2. **Superjournal**: `formatTurnForSuperjournal(persona: X)`
3. **Journal**: Machine trim with persona context
4. **Omniscient Bundle**: `loadPersonaContext(persona: X)`

#### **The Golden Rule:**
- **Every attribution point** gets the same value from the persistent `currentPersona`
- **Never defaults to hardcoded values** - always reads from vault
- **Immediately saves** any persona changes
- **Survives app restarts** forever

This is why "Aether" was appearing - the old system had hardcoded fallbacks that ignored the persistent persona state. Now there's a single source of truth that controls everything.

## Architecture Overview

### **The Aether Memory Cycle:**

1. **Boss Input** → May or may not specify a persona (first word)
2. **Persona State Management** → MessageStore tracks current active persona until Boss summons another
3. **Omniscient Bundle Assembly** → Combines:
   - Boss folder (user context)
   - Current persona folder 
   - Tools folder (taxonomy, etc.)
   - Journal folder (previous trims)
4. **LLM Instructions** → `instructions-to-LLM.md` tells LLM to do 3 tasks:
   - [i] Taxonomy management using rules
   - [ii] Reply in current persona's authentic voice  
   - [iii] Machine trim the whole turn
5. **LLM 3-Part Response**:
   - [i] Taxonomy updates → Aether applies to `taxonomy.json`
   - [ii] Persona response → Displayed in scrollback + saved to superjournal
   - [iii] Machine trim → Saved to journal folder
6. **Next Turn** → Journal folder (with new trim) becomes part of next omniscient bundle

**The Wheel Turns** → Each cycle enriches the memory for the next cycle.

### **Super-Persistent Persona State:**

The `currentPersona` should be **super-persistent** across app restarts, not just session-based. The system:

1. **Persistent Storage** - `currentPersona` saved to vault when changed
2. **Load on App Start** - On app initialization, load the saved `currentPersona` from vault
3. **Never Nil** - There should always be a valid persona (no nil/fallback logic needed)

The currentPersona variable can never ever be nil. There will always be a persona value. The omniscient bundle that is sent to the LLM, the name that is displayed in the scrollback, the journal, the superjournal - they all take what is in the super-persistent currentPersona variable.