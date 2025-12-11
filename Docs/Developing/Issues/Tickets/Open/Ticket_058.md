# **TICKET-058 — Main-Thread Publishing For Observable Models (Critical)**

- **Title**
    
    - Enforce main-thread publishing for UI-observed models
        
    
- **Goal**
    
    - Eliminate "Publishing changes from background threads is not allowed" warnings and any undefined behavior by **guaranteeing** that all ObservableObject / @Published changes observed by SwiftUI are marshalled back to the **main thread**.
        
    

---

## **1. Problem Overview**

  

Anywhere you have:

- ObservableObject with @Published properties
    
- SwiftUI views using @StateObject, @ObservedObject, or @EnvironmentObject
    

  

You must **only** mutate those properties on the **main thread**.

  

You probably have some of these patterns:

- Background work (scheduler, data loads, EventKit fetches, file IO) calling:
    
    - self.items = newItems
        
    - self.state = .loaded(newData)
        
    
- Timers, async tasks, or callbacks firing on background queues and directly mutating published state.
    

  

This causes:

- Runtime warnings
    
- Undefined UI behavior
    
- Potential crashes or subtle UI race conditions
    

  

This ticket standardizes a single rule:

  

> Any state that SwiftUI observes must only be mutated on the main thread.

---

## **2. Scope**

  

Applies to all **UI-facing models**, including at minimum:

- Scheduler view models
    
- Calendar / events models
    
- Settings / ThemeManager
    
- AppDataStore-backed UI wrappers
    
- Dashboard / assignments / “Tell Me What To Do” view models
    

  

Non-UI-only logic (e.g., pure data pipelines) can do whatever they want on background queues as long as they only hand **final results** back on the main thread when touching an observed object.

---

## **3. Design Principles**

- Mutations to @Published or ObservableObject state:
    
    - Must be done on main thread
        
    - Either by:
        
        - Ensuring the entire pipeline is main-thread bound, or
            
        - Hopping back to main right before mutation
            
        
    
- Background work:
    
    - Runs off main thread
        
    - Returns **results**, not direct state mutations
        
    
- Where unavoidable, add:
    
    - Explicit DispatchQueue.main.async
        
    - Or .receive(on: DispatchQueue.main) in Combine pipelines
        
    

---

## **4. Patterns To Use**

  

### **4.1 Direct Dispatch to Main**

  

For async or callback-style APIs:

```
class SchedulerViewModel: ObservableObject {
    @Published var schedule: [CalendarEvent] = []
    @Published var isLoading: Bool = false

    private let scheduler: SchedulerEngine

    func runScheduling() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.scheduler.computeSchedule()
            DispatchQueue.main.async {
                self.schedule = result
                self.isLoading = false
            }
        }
    }
}
```

Key rule:

- Only call self.schedule = result inside DispatchQueue.main.async.
    

  

### **4.2 Combine Pipelines**

  

If you are using Combine publishers to load or compute data:

```
func bindScheduler() {
    schedulerEngine
        .schedulePublisher()        // Emits on background queue
        .receive(on: DispatchQueue.main)
        .assign(to: &$schedule)
}
```

or explicitly:

```
schedulerEngine
    .schedulePublisher()
    .receive(on: DispatchQueue.main)
    .sink { [weak self] newSchedule in
        self?.schedule = newSchedule   // Safe: now on main
    }
    .store(in: &cancellables)
```

The .receive(on:) boundary is the guarantee.

---

## **5. Concrete Implementation Steps**

  

### **5.1 Identify All Observable Models**

  

Search for:

- class .*: ObservableObject
    
- @Published
    
- @StateObject, @ObservedObject, @EnvironmentObject
    

  

Create a list of key types, e.g.:

- ThemeManager
    
- SchedulerViewModel
    
- CalendarViewModel
    
- AssignmentsViewModel
    
- SettingsViewModel
    
- Any AppDataStore wrapper exposed directly to SwiftUI
    

  

You don’t have to do this manually each time; you can keep a short **registry** in a markdown doc for future reference.

  

### **5.2 Add a Thread-Safety Helper (Optional But Useful)**

  

Centralize the “ensure main” logic.

```
enum MainThread {
    static func assert() {
        assert(Thread.isMainThread, "UI-published state modified off main thread")
    }

    static func async(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
```

You can then write:

```
MainThread.async {
    self.schedule = result
    self.isLoading = false
}
```

This gives you:

- Safety in release
    
- Assertions in debug
    

  

### **5.3 Wrap All Published Mutations**

  

For each ObservableObject:

1. Look at every place @Published properties are assigned or mutated.
    
2. For any path that might run off-main:
    
    - Either guarantee caller is main-thread-only,
        
    - Or wrap mutation in MainThread.async { ... }.
        
    

  

Examples:

```
func updateEvents(_ newEvents: [CalendarEvent]) {
    MainThread.async {
        self.events = newEvents
    }
}
```

If you have **mutating collections** like:

```
self.items.append(newItem)
self.items[index].status = .done
```

wrap the whole **mutating block**:

```
MainThread.async {
    self.items.append(newItem)
}
```

or

```
MainThread.async {
    self.items[index].status = .done
}
```

### **5.4 Long-Running Tasks**

  

In view models that do heavy work:

```
func refreshAssignments() {
    MainThread.async {
        self.isLoading = true
    }
    DispatchQueue.global(qos: .userInitiated).async {
        let assignments = self.dataStore.fetchAssignments()    // background
        MainThread.async {
            self.assignments = assignments
            self.isLoading = false
        }
    }
}
```

Pattern:

- Set isLoading on main
    
- Compute on background
    
- Assign on main
    

---

## **6. Scheduler-Specific Fixes (High Priority)**

  

The scheduler is a likely offender because:

- It runs heavy computations
    
- It touches UI models (schedule lists, statuses, progress states)
    

  

You want:

- SchedulerEngine = pure logic, no @Published, no SwiftUI awareness
    
- SchedulerViewModel = UI-facing, main-thread-only publishes
    

  

### **6.1 Strong Separation**

```
final class SchedulerEngine {
    func computeSchedule(input: SchedulerInput) -> SchedulerResult {
        // pure calculation, no main-thread requirement
    }
}

final class SchedulerViewModel: ObservableObject {
    @Published var scheduleBlocks: [ScheduleBlock] = []
    @Published var isRunning: Bool = false

    private let engine: SchedulerEngine

    func run(input: SchedulerInput) {
        MainThread.async {
            self.isRunning = true
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.engine.computeSchedule(input: input)
            MainThread.async {
                self.scheduleBlocks = result.blocks
                self.isRunning = false
            }
        }
    }
}
```

No background-thread published writes.

---

## **7. Debugging & Guardrails**

  

### **7.1 Add Temporary Assertions**

  

Inside critical models (scheduler, calendar, settings), you can enforce main-thread mutation in debug builds:

```
#if DEBUG
private func assertMainThread(_ message: String = "Must mutate on main thread") {
    assert(Thread.isMainThread, message)
}
#endif
```

Then:

```
func setTheme(_ preference: ThemePreference) {
    assertMainThread("ThemeManager.setTheme must be called on main")
    self.preference = preference
}
```

You can remove or relax these later once the code is clean.

  

### **7.2 Xcode Runtime Diagnostics**

  

In Scheme → Run → Diagnostics:

- Enable “Main Thread Checker”
    
- This will scream at you when UI-ish things happen off main.
    

  

Use it while:

- Running complex scheduler scenarios
    
- Rapidly toggling settings, calendars, views
    

  

If any new warnings appear, track back and fix with MainThread.async or .receive(on:).

---

## **8. Testing Strategy**

  

### **8.1 Unit Tests (Structure-Level)**

  

You can’t directly “test threads” in standard unit tests easily, but you can:

- Test that view models accept injected scheduler/data engines that are **thread-agnostic**.
    
- Test that MainThread.async behaves correctly:
    
    - On main thread: executes immediately
        
    - Off main: enqueues to main
        
    

  

### **8.2 Manual Regression Tests**

  

Perform these flows with **Main Thread Checker** enabled:

- Rapidly switching theme (Light / Dark / Auto)
    
- Running the scheduler for:
    
    - Empty schedule
        
    - Heavy schedule with multiple events
        
    
- Adding/removing calendar events quickly
    
- Editing assignments while scheduler runs or recomputes
    
- Changing settings related to calendar, permissions, energy sliders
    

  

Expected result:

- Zero “Publishing changes from background threads is not allowed” warnings
    
- No data races, no flickering weirdness
    

---

## **9. Interactions With Other Tickets**

- **TICKET-009 — Scheduler correctness tests**
    
    - Once main-thread publishing is enforced, scheduler tests are less likely to be flaky due to subtle concurrency problems.
        
    
- **TICKET-011 — Cross-engine and UI consistency**
    
    - Shared engine behavior must be thread-safe; UI layer always applies results on main thread.
        
    
- **TICKET-013 — Fail-safe behavior**
    
    - Error paths also must respect main-thread publishing when updating error states, banners, or alerts.
        
    
- **TICKET-045 — Settings persistence**
    
    - All setting changes that hit @Published properties must do so on main.
        
    

---

## **10. Done Definition (Strict)**

  

TICKET-058 is complete when:


**Completed:** 2025-11-30T20:57:14.671Z

Summary of changes:
- Added MainThread helper and used it where appropriate.
- Marked ThemeManager @MainActor and ensured DashboardViewModel updates occur on the main actor.
- Replaced off-main @Published mutations and added assertions where useful; updated changelog.



- All ObservableObject classes have been reviewed for @Published mutations.
    
- Any mutation that may be invoked from a background context is wrapped in:
    
    - DispatchQueue.main.async or
        
    - MainThread.async helper or
        
    - Combine .receive(on: DispatchQueue.main).
        
    
- Running the app with:
    
    - Main Thread Checker enabled
        
    - Full typical flows exercised
        
        produces:
        
    - **No** "Publishing changes from background threads is not allowed" warnings.
        
    
- No new warnings appear in edge-case flows (scheduler re-runs, calendar permission changes, settings toggles).
    
- There is a clear convention documented in your codebase (e.g., in CONTRIBUTING.md or ARCHITECTURE.md):
    
    - “Any state observed by SwiftUI (ObservableObject / @Published) must only be mutated on the main thread.”
        
    

---

Next in the critical chain after 058, if you follow your sorted list, are:

- TICKET-063 — On-device data storage audit
    
- TICKET-064 — Full offline-capable app behavior
    

  

Both of those are architectural, so once you’re happy with 058, those are the next big structural passes.