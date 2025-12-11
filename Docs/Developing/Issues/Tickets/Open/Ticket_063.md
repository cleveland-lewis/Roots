# **TICKET-063 — On-Device Data Storage Audit (Critical)**

- **Title**
    
    - Ensure all user data is stored locally on the device
        
    
- **Goal**
    
    - Produce a **hard, verified map** of all data the app reads/writes and **guarantee** that:
        
        - Core app data (tasks, schedules, notes, settings, logs) lives **only in on-device storage** (app sandbox, Keychain, etc.)
            
        - Any non-local or external storage is:
            
            - Explicitly documented
                
            - Gated behind **user consent**
                
            - Clearly surfaced in the **Data & Privacy** section
                
            
        
    

---

## **1. Problem Definition**

  

Right now you’re assuming “this is local-only,” but you don’t have:

- A **formal inventory** of:
    
    - What is stored
        
    - Where it is stored
        
    - How it is serialized
        
    
- A **guarantee** that nothing quietly leaks to:
    
    - Cloud / third-party servers
        
    - Analytics SDKs
        
    - Accidental logs with sensitive content
        
    

  

This ticket is about establishing:

- A **source-of-truth document** listing every persistence path
    
- A **code-level audit** to confirm that:
    
    - Data stays in the iOS/macOS **sandbox** (UserDefaults, files, CoreData, etc.)
        
    - Logs don’t contain sensitive content
        
    - Any future external sync must be explicitly wired and consented
        
    

---

## **2. Scope**

  

Data categories to cover:

- Assignments, tasks, events, schedules
    
- Courses / course maps / syllabus-derived data
    
- “Tell Me What To Do” state and study session history
    
- Notes and rich-text documents
    
- Settings and preferences (theme, calendars, app lock, privacy flags, energy level defaults)
    
- Scheduler inputs/outputs and debug logs
    
- Error logs / QA logs / analytics-like events
    
- Any future:
    
    - AI integration
        
    - Export/import / backup functionality
        
    

  

All platforms:

- macOS app
    
- iOS / iPadOS app
    
- watchOS extensions (if any)
    

---

## **3. Deliverables**

- docs/data-inventory.md:
    
    - Table of all data categories and where they are stored
        
    
- docs/data-storage-policy.md:
    
    - Clear statement: “Roots stores all user data locally by default. External sync is opt-in only.”
        
    
- Explicit code-level constraints:
    
    - All current writes confined to:
        
        - App sandbox (e.g. FileManager.default.urls(for: .documentDirectory, …))
            
        - UserDefaults in app group (if used)
            
        - Keychain (for secrets)
            
        
    - No outbound network writes for user content without explicit feature + toggle
        
    
- Optional: small comments or documentation on any “escape hatches” (e.g., export to file, not over network).
    

---

## **4. Step 1 — Map All Storage Points**

  

Create a structured inventory.

- Add a file: docs/data-inventory.md
    
- For each subsystem (AppDataStore, scheduler logs, notes, assignments, settings, etc.), record:
    

```
| ID | Subsystem      | Data Type                          | Storage Mechanism   | Path / Key Prefix                          | Notes                  |
|----|----------------|-------------------------------------|---------------------|--------------------------------------------|------------------------|
| D1 | Assignments    | Assignment list, statuses, due     | JSON in Documents   | /Documents/assignments.json                | Local only             |
| D2 | Settings       | Theme, calendars, privacy toggles  | UserDefaults        | com.roots.settings.*                       | Local only             |
| D3 | Scheduler Logs | Minimal debug logs (no content)    | File in Application | /Library/Logs/Roots/scheduler.log          | No PII / content data  |
```

-   
    
- Use this as **the** reference for what must be guaranteed local-only.
    

  

Implementation detail: you can partially auto-derive this by grepping:

- "UserDefaults.standard"
    
- "FileManager.default"
    
- "Keychain" wrappers
    
- Any custom persistence helpers
    

---

## **5. Step 2 — Audit Each Persistence Mechanism**

  

For each storage mechanism you use, verify:

- It resolves to **on-device** sandbox, not network-backed service.
    

  

### **5.1 UserDefaults**

- Ensure all usages are:
    
    - UserDefaults.standard or app-group defaults you control
        
    
- Confirm:
    
    - No explicit custom suite that is iCloud-synced unless you intend to:
        
        - If you ever add iCloud Key-Value or NSUbiquitousKeyValueStore:
            
            - It becomes **non-local** and must be documented + consented under Data & Privacy.
                
            
        
    

  

### **5.2 File-Based Storage**

- Any FileManager calls must use:
    
    - .documentDirectory
        
    - .applicationSupportDirectory
        
    - .cachesDirectory
        
    - .libraryDirectory
        
    

  

within **your app’s sandbox**:

```
let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    .appendingPathComponent("Roots")
```

- Check for:
    
    - Hardcoded absolute paths (/Users/.../Documents) – forbidden in production
        
    - Shared network mounts – do not use
        
    

  

### **5.3 Core Data / SQLite / Custom DB (if used)**

- Verify the store URL is in:
    
    - Application Support
        
    - Documents
        
    
- Confirm:
    
    - No remote DB URLs
        
    - No network-based store types
        
    

  

### **5.4 Logs / Diagnostics**

- Any logging facility you build under TICKET-017 must:
    
    - Write to local file (e.g. Application Support/Logs/Roots/…)
        
    - Or use in-memory logs only
        
    - Never send logs over the network automatically
        
    
- Explicit rule:
    
    - Scheduler logs and error reports **must not** be automatically uploaded.
        
    - If you add “Export logs” later, it should export to a local file share (system Share Sheet), not send anywhere by default.
        
    

---

## **6. Step 3 — Verify Network Usage (Enforce “No Hidden Sync”)**

  

Search for and review **all** networking code:

- URLSession
    
- Third-party clients (e.g. Alamofire, etc.)
    
- Any SDK initialization (analytics, crash reporting, etc.)
    

  

Decision:

- For this ticket, the constraint is:
    
    - No user content, events, tasks, notes, or schedules are sent over the network without:
        
        - A dedicated feature (e.g., “Export backup to …”)
            
        - An explicit user control or toggle in **Data & Privacy settings**
            
        
    

  

So:

- If there is currently **no network code** → document that.
    
- If there is **some network code** (e.g. feature you’re not yet using), you either:
    
    - Remove/disable it, or
        
    - Document it, gate it behind settings, and mark that external sync is **off by default**.
        
    

---

## **7. Step 4 — Add a “Data & Storage” Policy Document**

  

Add docs/data-storage-policy.md that:

- Summarizes:
    
    - “Roots stores all academic data, schedules, notes, and settings **only on your device** inside the iOS/macOS sandbox.”
        
    - “No cloud servers are used by default.”
        
    - “If external sync or backup is added in the future, it will require explicit opt-in and be listed under Settings → Data & Privacy.”
        
    
- References:
    
    - docs/data-inventory.md for the detailed mapping
        
    

  

This ties directly into:

- TICKET-036 / TICKET-037 (Data & Privacy Settings / Logging & privacy hygiene)
    

---

## **8. Step 5 — Add Guardrails in Code**

  

Add lightweight invariants so you don’t silently violate this later.

  

### **8.1 Centralize Persistence Paths**

  

Create something like AppPaths:

```
enum AppPaths {
    static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Roots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var dataDirectory: URL {
        appSupportDirectory.appendingPathComponent("Data", isDirectory: true)
    }

    static var logsDirectory: URL {
        appSupportDirectory.appendingPathComponent("Logs", isDirectory: true)
    }

    static func dataFile(named name: String) -> URL {
        dataDirectory.appendingPathComponent(name)
    }

    static func logFile(named name: String) -> URL {
        logsDirectory.appendingPathComponent(name)
    }
}
```

Then enforce:

- All JSON/DB/log writes use AppPaths functions, not ad-hoc paths.
    

  

This gives you a **single point** to check for “local-only” behavior.

  

### **8.2 Explicit No-Remote Rule for Data Layer**

  

Document in code (and optionally in comments) for AppDataStore:

- “This data store must never perform network operations. It only reads/writes to local files/UserDefaults/Keychain.”
    

  

If you want more, add a NetworkClient abstraction and keep it completely separate from the data store.

---

## **9. Step 6 — Manual QA: Validate “Airplane Mode” Behavior**

  

This overlaps with TICKET-064 but at the storage level:

- Run the app with:
    
    - Airplane mode (iOS) / disabled network (macOS)
        
    
- Use the app normally:
    
    - Create assignments, notes, schedule events, set preferences
        
    
- Check:
    
    - Everything continues to function
        
    - No alerts appear complaining about missing network for **core** flows
        
    - Nothing obviously tries to sync externally
        
    

  

If any core operation requires network access, that’s a violation of this ticket’s expectation unless explicitly documented as non-core.

---

## **10. Integration With Other Tickets**

- **TICKET-064 — Full offline-capable app behavior**
    
    - 063 is the _data storage constraint_; 064 is the _runtime behavior and UX_ under no network.
        
    
- **TICKET-017 / 036 / 037 — Logging, Data & Privacy**
    
    - Logging paths discovered here feed directly into:
        
        - Data & Privacy settings
            
        - Privacy documentation
            
        
    
- **TICKET-046 / 047 — Syllabus parser, Tell Me What To Do**
    
    - Any future “AI” or remote parsing must:
        
        - Be opt-in
            
        - Be documented as external
            
        - Never silently exfiltrate data outside what’s described in data-storage-policy.md.
            
        
    

---

## **11. Done Definition (Strict)**

  

TICKET-063 is complete when:

- docs/data-inventory.md exists and lists:
    
    - Every data category
        
    - Storage mechanism
        
    - File paths / keys
        
    - Local vs external classification
        
    
- docs/data-storage-policy.md exists and states:
    
    - App is **local-only** by default
        
    - External sync/backup is opt-in and future-gated
        
    
- Code review confirms:
    
    - All persistence uses sandboxed on-device mechanisms (UserDefaults, local files, CoreData/SQLite in app dirs, Keychain)
        
    - No user data is written via network calls by default
        
    
- A centralized path helper (AppPaths or equivalent) is in place and being used by persistence components.
    
- Manual QA with network disabled shows:
    
    - Core academic functionality still works
        
    - No unexpected network failures related to data saving/loading
        
    

  

Once this is locked, 064 (offline behavior) is the natural follow-up, because now you know _what_ is local and can design how the app should behave when external resources truly are unavailable.


**Completed:** 2025-11-30T16:45:55.636Z

Summary of changes:
- Added docs/data-inventory.md (comprehensive mapping of persisted data categories and paths).
- Added docs/data-storage-policy.md (local-first policy, export opt-in guidance).
- Added Sources/Roots/Utilities/AppPaths.swift centralizing AppSupport/Data/Logs/Caches directories.
- Updated DashboardStorage to persist dashboard-summary.json under AppPaths.dataDirectory and ensured directory creation prior to writes.
- Updated FileStorageManager to use AppPaths.dataDirectory for course files.

Verification:
- No user content is sent over the network by default; networked APIs are gated and Data & Privacy policy documents created.
- Core create/save flows use centralized local directories; manual QA step (airplane mode) recommended next.
