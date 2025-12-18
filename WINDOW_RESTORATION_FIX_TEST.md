# Window Restoration Fix - Testing Instructions

## Issue
The warning `-[NSApplication(NSWindowRestoration) restoreWindowWithIdentifier:state:completionHandler:] Unable to find className=(null)` was appearing on every app launch.

## Fix Applied
Updated `AppDelegate` in `macOSApp/App/RootsApp.swift` to disable window restoration **before** the app finishes launching by setting `NSQuitAlwaysKeepsWindows` to `false` in the `init()` method.

## What Changed
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        super.init()
        // Disable window restoration BEFORE app finishes launching
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }
    
    func application(_ app: NSApplication, willDecodeRestorableStateWith coder: NSCoder) {
        // Don't restore any state
    }
}
```

## How to Test

### Test 1: Fresh Launch
1. **Clean UserDefaults** (optional but recommended for clean test):
   ```bash
   defaults delete com.clevelandlewis.Roots NSQuitAlwaysKeepsWindows
   ```

2. **Launch the app**

3. **Check console output** - You should **NOT** see:
   ```
   -[NSApplication(NSWindowRestoration) restoreWindowWithIdentifier:state:completionHandler:] Unable to find className=(null)
   ```

### Test 2: Relaunch After Quit
1. **Resize/move the main window** to a specific position
2. **Quit the app** (Cmd+Q)
3. **Relaunch the app**
4. **Check console** - The `className=(null)` warning should **NOT** appear
5. **Check window** - Window may or may not restore to previous position (this is expected since we disabled restoration)

### Test 3: Multiple Launches
1. **Launch, quit, and relaunch** the app 3-5 times
2. **Each time check console** for the `className=(null)` warning
3. Warning should **never** appear

## Expected Results

### ✅ Success Indicators:
- No `className=(null)` warning in console
- App launches normally
- All features work correctly
- No crashes or hangs

### ⚠️  Side Effects (Expected):
- Window position/size may **not** be restored across launches
- This is the trade-off for eliminating the warning
- User can still manually resize/position windows

## Fallback

If the warning still appears, the issue is that:
1. UserDefaults setting isn't being applied early enough
2. Need to add Info.plist key instead (requires project configuration change)

Would need to add to project build settings:
```
INFOPLIST_KEY_NSQuitAlwaysKeepsWindows = NO
```

## Status

Build: ✅ SUCCESS  
Ready for testing: ✅ YES  
Manual testing required: ✅ YES
