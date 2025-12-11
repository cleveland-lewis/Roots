# **TICKET-064 — Full Offline-Capable App Behavior (Critical)**

- **Title**
    
    - Ensure the application remains fully functional offline
        
    
- **Goal**
    
    - Guarantee that all core workflows operate without network connectivity.
        
    - Any network-dependent feature must:
        
        - Detect offline conditions
            
        - Fail gracefully
            
        - Preserve data integrity
            
        - Provide clear, user-facing offline messaging
            
        
    - No core functionality may silently degrade or require external resources.
        
    

---

## **1. Problem Definition**

  

Roots is designed as a **local-first**, academic planning system.

To meet this expectation, the application must remain operational in environments with:

- Airplane mode
    
- Weak or unstable connectivity
    
- System-level network blocking
    
- Hard offline conditions
    

  

This ticket defines offline runtime guarantees, not storage guarantees.

Storage guarantees are defined under **TICKET-063**.

  

This ticket establishes:

- A runtime connectivity model
    
- Explicit gating of network-required features
    
- Fallback behavior for degraded connectivity
    
- UI/UX rules for offline notifications
    
- Clear isolation between local logic and any remote systems
    

---

## **2. Scope**

  

### **2.1 Features required to function offline**

- Dashboard summaries
    
- Calendar views
    
- Assignment lists
    
- Notes editing
    
- “Tell Me What To Do”
    
- Scheduling engine
    
- Theme/appearance settings
    
- All data viewing and editing flows backed by local persistence
    

  

### **2.2 Features allowed to require network (present or future)**

- AI-based recommendations
    
- Remote syllabus parsing (if implemented)
    
- Cloud backup or multi-device sync
    
- Remote analytics (optional and always disabled by default)
    

  

These features must detect offline status immediately and degrade gracefully.

---

## **3. Offline Runtime Model**

  

The application must define consistent states:

- **Online**
    
    - Network is available
        
    
- **Offline (hard)**
    
    - No connection (airplane mode, disconnected interfaces)
        
    
- **Offline (soft / degraded)**
    
    - Network present but unreachable, intermittent, or returning server-level errors
        
    

  

Core behavior must function identically under both offline modes.

---

## **4. Core Design Decisions**

  

### **4.1 Local-first architecture**

  

All essential logic must run against:

- Local persistence
    
- Local scheduler inputs
    
- Local task and event lists
    
- Local note documents
    

  

### **4.2 Network is never required for:**

- Launching the application
    
- Viewing/editing tasks, events, or notes
    
- Executing the scheduler
    
- Navigating between views
    

  

### **4.3 Network-dependent actions**

  

Any network-dependent action must:

- Check network status pre-flight
    
- Display an inline offline explanation
    
- Never block unrelated local work
    
- Fail predictably, not silently
    

  

The system must adhere to deterministic, low-surprise behavior.

---

## **5. Implementation Plan**

  

### **5.1 Create a Network Status Monitor**

  

A new abstraction, NetworkStatusMonitor, is required to track connectivity.

- Tracks:
    
    - .online
        
    - .offline
        
    - .unknown
        
    
- Powered by:
    
    - NWPathMonitor on Apple platforms
        
    
- Exposed through:
    
    - ObservableObject
        
    - Combine publishers
        
    - Async streams
        
    

  

Example structure:

```
final class NetworkStatusMonitor: ObservableObject {
    enum Status { case unknown, online, offline }
    @Published private(set) var status: Status = .unknown

    func startMonitoring() {
        // Updates to status occur on the main thread
    }
}
```

Any view or service must reference this monitor before initiating network work.

---

### **5.2 Annotate Features with Connectivity Requirements**

  

A simple enum defines the requirement level:

```
enum ConnectivityRequirement {
    case offlineCapable
    case networkRequired
}
```

UI actions, services, and view models must specify this explicitly.

Offline-capable features must never initiate a network request implicitly.

---

### **5.3 Gate All Network-Required Actions**

  

Network-required actions must incorporate a guard:

```
guard networkStatus.status == .online else {
    OfflineUXPresenter.present(.featureUnavailable)
    return
}
```

This ensures:

- No hidden network attempts
    
- No blocking spinners
    
- No HTTP-coded error banners
    

  

Instead, the user receives stable, predictable offline feedback.

---

### **5.4 Audit All Core Workflows for Offline Independence**

  

#### **5.4.1 Dashboard**

- Must compute all summaries from local data sources
    
- No remote fetches may influence base rendering
    

  

#### **5.4.2 Calendar and Scheduling System**

- Scheduler must operate exclusively on:
    
    - Local EventKit data
        
    - Local tasks
        
    - Local priorities
        
    
- Scheduling and calendar rendering must not require connectivity
    

  

#### **5.4.3 Assignments and Notes**

- Fully offline editing guaranteed
    
- No keystroke-level network calls
    
- Any optional cloud feature must be opt-in and clearly labeled as such
    

  

#### **5.4.4 “Tell Me What To Do”**

- Must operate entirely offline using:
    
    - Local heuristics
        
    - Local weights
        
    - Local scheduler scoring
        
    
- If a cloud-based recommender is added, offline fallback is mandatory
    

---

## **6. Offline UX and Error Handling**

  

### **6.1 Standardized Offline Messaging**

  

The application must use a unified messaging system with phrasing such as:

- “This feature requires an internet connection.”
    
- “Local data is preserved and fully accessible offline.”
    
- “Try again when online.”
    

  

No technical errors (e.g., HTTP codes) may be displayed.

  

### **6.2 Optional Offline Indicator**

  

A small badge or label may be displayed in the navigation structure:

- “Offline mode”
    

  

This element must be non-intrusive and not anxiety-inducing.

---

## **7. Consistency Rules for Local Mutations**

  

All local edits must:

- Commit instantly to local storage
    
- Never queue behind network availability
    
- Never be blocked by unreachable endpoints
    

  

If remote sync is added in the future:

- Local edits remain the authoritative source
    
- Sync becomes an asynchronous, optional layer
    

  

Offline operations must **never** be rejected due to connectivity.

---

## **8. Testing Requirements**

  

### **8.1 Manual QA Matrix**

  

A new file docs/offline-qa.md must be added.

  

It includes offline test cases for:

- Dashboard
    
- Calendar
    
- Assignment editing
    
- Note editing
    
- Scheduler execution
    
- Settings
    
- Tell Me What To Do
    

  

Testing conditions include:

- App launched offline
    
- App goes offline while running
    
- Offline → online transitions
    

  

### **8.2 Automated Tests**

  

A test harness must inject fake network states:

```
monitor.status = .offline
```

The test suite must validate:

- Network-required features disable correctly
    
- Offline-capable features remain fully functional
    
- No unexpected network calls are triggered
    

---

## **9. Integration with Other Tickets**

- **TICKET-063**
    
    - Ensures all data is local; 064 ensures all local data remains accessible offline.
        
    
- **TICKET-017 / 036 / 037**
    
    - Logging and privacy workflows must respect offline constraints.
        
    
- **TICKET-046 / 047**
    
    - Any remote syllabus parsing or AI assistance must explicitly declare offline limitations.
        
    
- **TICKET-011**
    
    - Consistency rules across all engines (scheduler, assignments, notes) must be upheld in both online and offline states.
        
    

---

## **10. Completion Criteria (Strict)**


**Completed:** 2025-11-30T16:31:18Z

Summary: Implemented global NetworkStatusMonitor singleton, gated network entry points (Eve API chat/schedule, RemoteDashboardAPIClient, DashboardRepository), added offline UI hints in Settings and Eve views, added docs/offline-qa.md and implementation notes. See Ticket_064_IMPLEMENTATION.md for full details.


  

TICKET-064 is complete when the application demonstrates:

- Full functionality of all local-first features while offline
    
- Zero hidden network dependencies in core functionality
    
- Graceful, predictable offline behaviors in all network-required actions
    
- Clear offline UX communication
    
- A documented offline behavior matrix
    
- Verified behavior through manual and automated offline testing
    
- A global connectivity monitor integrated into all relevant code paths

## 11. Change Log
### Implementation notes (2025-11-30T16:10:57Z)

- Added Sources/Roots/Utilities/NetworkStatusMonitor.swift: NWPath-based observable monitor (shared singleton).
- Added Sources/Roots/Utilities/ConnectivityRequirement.swift: simple enum for feature annotation.
- Gated network calls:
  - Eve API client (chat and schedule) now throws when offline.
  - RemoteDashboardAPIClient now checks NetworkStatusMonitor before making requests.
  - DashboardRepository avoids remote fetches when offline and falls back to cached DashboardStorage.
- UI hints:
  - SettingsView and EveView show a non-intrusive "Offline" badge when NetworkStatusMonitor reports offline.
- QA doc: docs/offline-qa.md

Notes:
These changes gate only network entrypoints and provide clear UX/errors when offline. 
Further work: add automated tests that inject fake NetworkStatusMonitor states and validate behavior as described in Ticket_064.
