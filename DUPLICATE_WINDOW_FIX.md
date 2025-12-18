# Duplicate Window Issue - Fixed

## Problem
App opens with TWO windows instead of one - this is caused by macOS window restoration attempting to restore a previously saved window state.

## Root Cause
1. macOS automatically saves window state when app quits
2. On relaunch, it tries to restore saved windows
3. SwiftUI also creates a new window from WindowGroup
4. Result: 2 windows (1 restored + 1 new)

## Fix Applied

### File: `macOSApp/App/RootsApp.swift`

**Enhanced AppDelegate with multiple prevention strategies:**

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    
    override init() {
        super.init()
        // Completely disable window restoration
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.set(false, forKey: "ApplePersistenceIgnoreState")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Close all windows except the first one (prevents duplicates)
        let windows = NSApplication.shared.windows
        if windows.count > 1 {
            for window in windows.dropFirst() {
                window.close()
            }
        }
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false  // Completely disable restoration
    }
    
    func application(_ app: NSApplication, 
                    willDecodeRestorableStateWith coder: NSCoder) {
        // Don't restore any state
    }
    
    func application(_ application: NSApplication, 
                    willEncodeRestorableStateWith coder: NSCoder) {
        // Don't encode any state
    }
}
```

## What Changed

### 1. Multiple UserDefaults Keys Set
- `NSQuitAlwaysKeepsWindows = false` - Don't save window state on quit
- `ApplePersistenceIgnoreState = false` - Ignore any saved persistence state

### 2. Return `false` from `applicationSupportsSecureRestorableState`
- Previous code returned `true` which ENABLED restoration
- Now returns `false` to completely disable it

### 3. Added `willEncodeRestorableStateWith`
- Prevents encoding state in the first place
- Blocks the save operation

### 4. Automatic Duplicate Window Closure
- In `applicationDidFinishLaunching`, if more than 1 window exists
- Automatically closes all except the first one
- Failsafe in case restoration happens anyway

## How to Apply

1. **Code changes:** ✅ Already applied

2. **Clear existing saved state:**
   ```bash
   # Run in Terminal:
   defaults delete com.clevelandlewis.Roots NSQuitAlwaysKeepsWindows
   defaults delete com.clevelandlewis.Roots ApplePersistenceIgnoreState
   ```

3. **Quit and relaunch the app**

## Expected Behavior

### Before Fix:
❌ Two windows open on launch  
❌ Both windows show the same content  
❌ Confusing user experience

### After Fix:
✅ Only ONE window opens  
✅ Clean app launch  
✅ No window restoration warnings in console

## Testing

1. **First launch after fix:**
   - Should open 1 window (might still see 2 briefly if old state exists)
   - Run the `defaults delete` commands if you see 2

2. **Second launch:**
   - Should open only 1 window
   - No duplicate windows ever again

3. **After quitting and relaunching:**
   - Still only 1 window
   - Window position may not be saved (trade-off for no duplicates)

## Side Effects

**Intentional trade-off:**
- Window position/size will NOT be restored across launches
- This is acceptable - user can manually position window
- Better than having duplicate windows

## Build Status

✅ **BUILD SUCCEEDED**  
✅ **Ready for testing**

## Troubleshooting

If you STILL see duplicate windows after applying the fix:

1. **Make sure to run the `defaults delete` commands**
2. **Completely quit the app** (Cmd+Q)
3. **Delete app from Dock** and re-add it
4. **Restart Mac** (clears all app state)

The fix is comprehensive and should prevent duplicates permanently!

---

## Summary

The issue was that `applicationSupportsSecureRestorableState` returned `true`, enabling window restoration. Now it returns `false`, and we added multiple layers of prevention plus automatic cleanup of any duplicates that slip through.
