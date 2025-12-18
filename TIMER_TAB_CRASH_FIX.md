# Timer Tab Crash Fix - FINAL

## Issue
Timer tab crashed immediately with:
```
Publishing changes from within view updates is not allowed, this will cause undefined behavior.
Message from debugger: killed
```

## Root Causes (2 issues found and fixed)

### Issue #1: debugMainThread() Called in body ❌

**THE SMOKING GUN:**

```swift
var body: some View {
    debugMainThread("[TimerPageView] body rendering START")  // ❌ ILLEGAL
    
    return ScrollView {
        // ...
    }
}
```

**Why this crashes:**
1. `body` calls `debugMainThread()`
2. `debugMainThread()` → `recordInfo()` → `addEvent()`
3. `addEvent()` modifies `@Published var events` in MainThreadDebugger
4. **SwiftUI violation: "Publishing changes from within view updates"**
5. MainThreadDebugger detects main thread stall → kills process

**Rule:** NEVER call functions that mutate @Published state from body!

### Issue #2: cachedCollections Feedback Loop ❌

```swift
@State private var cachedCollections: [String] = ["All"]

.onChange(of: selectedCollection) { updateCachedValues() }

private func updateCachedValues() {
    cachedCollections = Array(set).sorted()  // ❌ Triggers onChange again
}
```

Creates infinite loop during render.

## The Fixes

### Fix #1: Remove debugMainThread() from body ✅

```swift
var body: some View {
    // ✅ Removed debugMainThread() call
    ScrollView {
        // ...
    }
}
```

Diagnostic logging should only be in:
- `.onAppear { }`
- `.onChange { }` 
- User actions
- **NEVER in body!**

### Fix #2: Make collections Computed ✅

```swift
// ✅ Pure computed property
private var collections: [String] {
    var set: Set<String> = ["All"]
    set.formUnion(activities.map { $0.category })
    return Array(set).sorted()
}

// ✅ Removed unnecessary onChange
.onChange(of: activities) { _, _ in updateCachedValues() }
.onChange(of: searchText) { _, _ in updateCachedValues() }
// REMOVED: .onChange(of: selectedCollection)
```

## Files Changed

1. `macOSApp/Scenes/TimerPageView.swift`:
   - Removed `debugMainThread()` call from body
   - Removed `@State var cachedCollections`
   - Made `collections` a computed property
   - Removed `cachedCollections` mutations
   - Removed `.onChange(of: selectedCollection)`

## Why This Works

### Body Purity Restored:
- Body now only **reads** state
- No function calls that mutate @Published vars
- No state writes during render

### No Feedback Loops:
- `collections` computes on-demand
- No cached state to create circular dependencies
- Clean separation: state changes happen in handlers, not body

## Testing

### Before Fixes:
❌ Navigate to Timer tab → Immediate crash  
❌ Console: "Publishing changes from within view updates"  
❌ MainThreadDebugger kills process

### After Fixes:
✅ Navigate to Timer tab → Loads instantly  
✅ No SwiftUI warnings  
✅ No crashes  
✅ All timer functionality works

## SwiftUI Rules (Never Forget)

1. **body must be PURE**
   - Read state → compute views → return views
   - NO writes, NO side effects, NO @Published mutations

2. **Avoid calling functions from body that:**
   - Modify @State or @Published properties
   - Trigger network requests
   - Write to disk
   - Log to debug systems that mutate state

3. **Put side effects in the right places:**
   - `.onAppear { }` - One-time setup
   - `.task { }` - Async work
   - `.onChange { }` - React to changes
   - Button actions - User interactions

4. **Computed properties should compute, not store**
   - If derived from state, calculate it each time
   - Caching is rarely worth the complexity

## Performance Note

Computing `collections` on every render is fine because:
- Small array (typically < 20 items)
- Simple operations (filter, sort)
- SwiftUI already optimizes rendering
- Premature optimization causes bugs (as seen here)

## Build Status

✅ **BUILD SUCCEEDED**  
✅ **Timer tab functional**  
✅ **Zero SwiftUI violations**  
✅ **No crashes**

---

## Key Takeaway

**Debug logging in body is a MASSIVE anti-pattern.**

If your debugger modifies @Published state, calling it from body will:
1. Violate SwiftUI rules
2. Trigger cascade failures
3. Kill your app

**Solution:** Only log from lifecycle methods (onAppear, onChange) or user actions, NEVER from body.

---

## Bonus: Other Issues Found

The log also shows:
- `Picker: the selection "nil" is invalid` - Some Picker has nil selection without nil tag
- EventKit alarm URL errors - Sandboxing restriction (harmless)
- Layout recursion warning - AppKit layout issue (one-time warning, non-fatal)

These are separate issues not causing the Timer crash.
