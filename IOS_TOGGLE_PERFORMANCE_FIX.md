# iOS Toggle Performance Optimization

**Date:** December 23, 2025  
**Issue:** iOS app slows down when rapidly toggling switches

---

## Problem

When rapidly toggling switches in the iOS app, the app becomes sluggish and unresponsive. This is caused by:

1. **Immediate view updates** - Every toggle triggers full view re-renders
2. **No debouncing** - Each change processes immediately
3. **Synchronous operations** - Settings might trigger expensive operations
4. **Main thread blocking** - All UI updates happen on main thread

---

## Solutions Applied

### Solution 1: Add Debounced Save to Settings

Add a debouncer to batch rapid setting changes into fewer save operations.

**File:** `SharedCore/State/AppSettingsModel.swift`

Add this property and method:

```swift
private var saveTask: Task<Void, Never>?

func debouncedSave() {
    saveTask?.cancel()
    saveTask = Task { @MainActor in
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        save()
    }
}
```

### Solution 2: Optimize Toggle Bindings

Instead of binding directly to settings properties, use custom bindings that batch updates.

**Example for Settings Views:**

```swift
private func optimizedBinding<T>(_ keyPath: ReferenceWritableKeyPath<AppSettingsModel, T>) -> Binding<T> {
    Binding(
        get: { settings[keyPath: keyPath] },
        set: { newValue in
            settings[keyPath: keyPath] = newValue
            settings.debouncedSave()
        }
    )
}

// Then use it:
Toggle(isOn: optimizedBinding(\.use24HourTimeStorage)) {
    Text("Use 24-Hour Time")
}
```

### Solution 3: Task Priority for Settings

Make sure settings operations don't block UI:

```swift
func save() {
    Task(priority: .utility) {
        let key = "roots.settings.appsettings"
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
```

---

## Quick Fix (Immediate)

The fastest fix is to add a debouncer to the settings model. This will batch rapid changes.

**Add to AppSettingsModel:**

```swift
// Add near the top of the class
private var saveDebouncer: Task<Void, Never>?

// Replace the save() method with:
func save() {
    saveDebouncer?.cancel()
    saveDebouncer = Task { @MainActor [weak self] in
        do {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            guard let self = self else { return }
            
            let key = "roots.settings.appsettings"
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(self) {
                UserDefaults.standard.set(data, forKey: key)
            }
        } catch {
            // Task was cancelled, ignore
        }
    }
}
```

This will batch rapid toggles into a single save operation after 0.3 seconds of inactivity.

---

## Performance Best Practices

### For All Toggle Views:

1. **Avoid expensive computations in view body**
   - Move calculations to computed properties
   - Cache results when possible

2. **Use `.id()` sparingly**
   - Only when you need to force view recreation

3. **Minimize view nesting**
   - Flatten view hierarchies where possible

4. **Use `@State` for local UI state**
   - Don't put every temporary value in settings

5. **Batch updates**
   - Group related changes together
   - Use transactions for coordinated updates

---

## Testing

After applying fixes:

1. **Rapid toggle test:**
   - Toggle a switch 10+ times rapidly
   - Should remain responsive
   - No lag or freezing

2. **Multiple toggle test:**
   - Toggle several switches quickly
   - App should feel snappy

3. **Background save test:**
   - Toggle → immediately background app
   - Settings should be saved correctly

---

## If Still Slow

If performance is still poor after debouncing, check:

1. **View re-render frequency:**
   - Add `let _ = Self._printChanges()` to view body temporarily
   - See what's triggering re-renders

2. **Main thread blocking:**
   - Use Instruments Time Profiler
   - Find blocking operations

3. **Memory pressure:**
   - Check for retain cycles
   - Monitor memory usage during toggling

---

## Files to Modify

1. `SharedCore/State/AppSettingsModel.swift` - Add debounced save
2. Settings views (optional) - Add optimized bindings if needed

---

**Status:** Solution documented  
**Priority:** High (affects UX)  
**Effort:** Low (simple fix)
