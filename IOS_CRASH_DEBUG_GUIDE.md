# iOS App Crash Fix - EXC_BAD_INSTRUCTION

**Date:** December 23, 2025  
**Error:** Thread 1: EXC_BAD_INSTRUCTION (code=1, subcode=0xfeedfacf)

---

## Diagnosis Steps

Since you're getting a crash immediately, here's how to find the exact cause:

### 1. Check Xcode Console

Look for error messages right before the crash. Common patterns:
```
Fatal error: Unexpectedly found nil while unwrapping an Optional value
Fatal error: Index out of range
Precondition failed
```

### 2. Check Crash Location

In Xcode's debug navigator (left panel), look at the call stack to find which file/line is crashing.

### 3. Enable Exception Breakpoint

In Xcode:
1. Go to Debug Navigator (⌘6)
2. Click + at bottom left
3. Add "Exception Breakpoint"
4. Run again - it will stop at the exact crash line

---

## Likely Causes & Fixes

### Issue 1: TabBarPreferencesStore Initialization ⚠️

**Problem:**
`IOSRootView.swift` line 13 might crash if `AppSettingsModel.shared` isn't ready.

**Quick Fix:**

Open `iOS/Root/IOSRootView.swift` and change line 13:

**Before:**
```swift
@StateObject private var tabBarPrefs = TabBarPreferencesStore(settings: AppSettingsModel.shared)
```

**After:**
```swift
@StateObject private var tabBarPrefs: TabBarPreferencesStore
```

Then add an init:
```swift
init() {
    _tabBarPrefs = StateObject(wrappedValue: TabBarPreferencesStore(settings: AppSettingsModel.shared))
}
```

---

### Issue 2: Missing Environment Object

**Problem:**
A view might be trying to access an @EnvironmentObject that wasn't injected.

**Check:**
Make sure all environment objects in `RootsIOSApp.swift` are provided before views that need them.

**Current injection (should be correct):**
```swift
IOSRootView()
    .environmentObject(AssignmentsStore.shared)
    .environmentObject(coursesStore)
    .environmentObject(appSettings)
    // ... all others
```

---

### Issue 3: Watch Bridge Initialization

**Problem:**
`PhoneWatchBridge.shared` in `RootsIOSApp.swift` line 32 might crash if Watch Connectivity isn't available.

**Fix:**

Open `iOS/Services/WatchBridge/PhoneWatchBridge.swift` and wrap initialization:

**Before:**
```swift
private override init() {
    self.session = WCSession.isSupported ? WCSession.default : nil
    // ...
}
```

**After:**
```swift
private override init() {
    if WCSession.isSupported() {
        self.session = WCSession.default
    } else {
        self.session = nil
    }
    // ...
}
```

---

## Quick Diagnostic Commands

Run these in Xcode console when crashed:

```lldb
# Print the current thread's backtrace
bt

# Print all threads
bt all

# Print the current expression that failed
po $arg1
```

---

## Most Likely Fix (Try This First)

Based on common iOS app crashes, the TabBarPreferencesStore initialization is the most likely culprit.

### Apply This Fix:

1. Open `iOS/Root/IOSRootView.swift`

2. Replace lines 11-15 with:

```swift
@EnvironmentObject private var plannerCoordinator: PlannerCoordinator
@StateObject private var navigation = IOSNavigationCoordinator()
@StateObject private var tabBarPrefs: TabBarPreferencesStore

@State private var selectedTab: RootTab = .dashboard

init() {
    _tabBarPrefs = StateObject(wrappedValue: TabBarPreferencesStore(settings: AppSettingsModel.shared))
}
```

3. Clean build (⌘⇧K)

4. Run again

---

## Alternative: Disable Watch Bridge Temporarily

If the crash is in PhoneWatchBridge:

1. Open `iOS/App/RootsIOSApp.swift`

2. Comment out line 32:
```swift
// _ = PhoneWatchBridge.shared  // Temporarily disabled
```

3. Test if app launches

---

## Get Exact Crash Location

To tell me exactly where it's crashing:

1. In Xcode, set Exception Breakpoint (Debug → Breakpoints → Create Exception Breakpoint)
2. Run app
3. When it crashes, look at the left panel (Debug Navigator)
4. Tell me:
   - Which file name is at the top of the stack
   - What line number
   - What the code on that line says

Then I can provide a specific fix for your exact crash.

---

## Send Me This Information

```
File: [filename from crash]
Line: [line number]
Code: [what the crashing line says]
Error: [console message]
```

Example:
```
File: IOSRootView.swift
Line: 13
Code: @StateObject private var tabBarPrefs = TabBarPreferencesStore(settings: AppSettingsModel.shared)
Error: Fatal error: Unexpectedly found nil while unwrapping an Optional value
```

---

## Status

⚠️ **Needs More Info:** Waiting for exact crash location from Xcode

**Most Likely Fix:** TabBarPreferencesStore initialization (see above)

**Temporary Workaround:** Comment out PhoneWatchBridge initialization
