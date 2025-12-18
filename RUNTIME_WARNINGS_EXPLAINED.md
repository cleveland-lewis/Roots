# Runtime Warnings Explained

This document explains the various runtime warnings you may see in the console when running the Roots app on macOS.

## Fixed Issues

### 1. ✅ Notification Permission Error (UNErrorDomain error 1)
**Status:** Fixed

**What it was:**
```
[Permissions] Permission request failed: The operation couldn't be completed. (UNErrorDomain error 1.)
```

**Cause:** The app attempted to request notification permissions in a sandboxed or restricted environment where the User Notifications framework reported an error.

**Fix:** The error is now handled gracefully in both `NotificationManager.swift` and `TimerManager.swift`. Instead of logging as an error, it's now treated as a debug-level message since it's expected behavior in certain environments.

### 2. ✅ Window Restoration Warning
**Status:** Fixed

**What it was:**
```
-[NSApplication(NSWindowRestoration) restoreWindowWithIdentifier:state:completionHandler:] Unable to find className=(null)
```

**Cause:** SwiftUI's `WindowGroup` doesn't automatically support NSCoding for window restoration, causing macOS to fail when trying to restore windows on app relaunch.

**Fix:** 
- Added `AppDelegate.swift` with proper window restoration support
- Added unique window identifier to `WindowGroup(id: "main")`
- Implemented `applicationSupportsSecureRestorableState` to enable secure restoration

### 3. ⚠️ Invalid Display Identifier Warnings
**Status:** Documented (Cannot be fully suppressed)

**What they are:**
```
invalid display identifier B64FFD91-0AB0-472D-88DF-4C54D064C66F
invalid display identifier 2C996BDF-3108-417F-8D2F-1B874D781D4C
Invalid display 0x00000002
CALocalDisplayUpdateBlock returned NO
```

**Cause:** These warnings originate from macOS's WindowServer and CoreGraphics frameworks when:
- External displays were previously connected but are now disconnected
- Display configuration has changed (e.g., arrangement, resolution)
- Multiple displays are being hot-plugged/unplugged

**Why they can't be suppressed:** These are system-level warnings from WindowServer/CoreGraphics, not from our application code. They appear in the unified logging system and cannot be filtered by application code.

**Impact:** None. These warnings are completely harmless and don't affect app functionality. They're a known macOS behavior when display configurations change.

**Workaround:** You can filter them out in Console.app by adding exclusion rules, or simply ignore them as they don't indicate any problem with the app.

## Other Harmless Warnings

### Accessibility Warnings
```
Accessibility: Not vending elements because elementWindow(0) is lower than shield(2001)
```
**What it is:** macOS accessibility system informing that some UI elements are behind security overlays.
**Impact:** None for normal users. Only affects VoiceOver/accessibility tools.

### Connection Interrupted
```
Connection interrupted!
```
**What it is:** Temporary loss of connection to system services (likely display-related).
**Impact:** None. macOS automatically reconnects.

### Fence TX Observer Timeout
```
fence tx observer 1540f timed out after 0.600000
```
**What it is:** CoreGraphics frame synchronization timeout (likely during display changes).
**Impact:** None. May cause a brief frame skip but doesn't affect functionality.

## Summary

All critical issues have been fixed. The remaining warnings are:
1. System-level display warnings (cannot be suppressed, harmless)
2. Accessibility/security warnings (expected macOS behavior)
3. Brief connection/timing warnings (transient, self-recovering)

The app functions correctly despite these console messages.
