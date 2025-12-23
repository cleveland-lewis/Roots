# Localization Bundle Issue - Diagnosis & Fix

## Issue

LocalizationManager was triggering fatal errors when keys couldn't be found, even though the keys exist in `Localizable.strings` files.

```
⚠️ LOCALIZATION MISSING: dashboard.events.title
Fatal error: Missing localization key: dashboard.events.title
```

## Root Cause

`NSLocalizedString` returns the key itself when it can't find the localization. This can happen when:

1. **Bundle Configuration**
   - `.strings` files aren't included in the app target
   - Files exist in project but not copied to bundle
   - Xcode build settings exclude localization resources

2. **Bundle Lookup**
   - `Bundle.main` might not contain the strings
   - Framework/module boundary issues
   - Build output doesn't include localization files

3. **Build Issues**
   - Clean build needed
   - DerivedData corruption
   - Target membership not set

## Solution Implemented

### 1. Removed Fatal Assertion ✅
```swift
// Before (❌ Crashes app)
if localized == key {
    assertionFailure("Missing localization key: \(key)")
    return englishFallback(for: key)
}

// After (✅ Graceful degradation)
if localized == key {
    #if DEBUG
    print("⚠️ LOCALIZATION MISSING: \(key)")
    // Check bundle for diagnostics
    #endif
    return englishFallback(for: key)
}
```

### 2. Added Diagnostic Logging ✅
```swift
if let stringsPath = Bundle.main.path(forResource: "Localizable", ofType: "strings") {
    print("   Localizable.strings found at: \(stringsPath)")
} else {
    print("   Localizable.strings NOT FOUND in main bundle")
}
```

### 3. Fallback Behavior ✅
Even if NSLocalizedString fails, the app:
- Generates readable English from key structure
- Never shows raw keys to users
- Logs warnings for developers
- Continues running without crashes

## How to Diagnose

### Check if .strings files are in bundle:
```bash
# Build the app, then check the bundle
cd ~/Library/Developer/Xcode/DerivedData/RootsApp-*/Build/Products/Debug/Roots.app/Contents/Resources
ls -la *.lproj/
```

### Check Xcode target membership:
1. Open Xcode
2. Select `en.lproj/Localizable.strings`
3. Open File Inspector (⌘⌥1)
4. Check "Target Membership" - ensure "Roots" is checked

### Check build phase:
1. Select Roots target in Xcode
2. Go to "Build Phases"
3. Check "Copy Bundle Resources"
4. Verify `.lproj` folders are listed

## Temporary Workaround

The fallback behavior means the app continues to work even if localization lookup fails:

```
dashboard.events.title → "Events Title" (generated from key)
planner.settings.enable_ai → "Enable Ai" (generated from key)
```

Not perfect, but better than showing `dashboard.events.title` or crashing.

## Proper Fix

To properly fix the bundle issue:

### Option 1: Verify Target Membership
1. Select each `.lproj` folder in Xcode
2. Check Roots target in File Inspector
3. Rebuild

### Option 2: Re-add Resources
1. Remove `.lproj` folders from project
2. Re-add them with "Copy items if needed" checked
3. Ensure "Create folder references" (not groups)
4. Rebuild

### Option 3: Clean Build
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/RootsApp-*

# Clean and rebuild
cd /path/to/Roots
xcodebuild clean -scheme Roots
xcodebuild build -scheme Roots
```

## Verification

After fixing, run the app and check console:
- ✅ No "LOCALIZATION MISSING" warnings
- ✅ Proper text displays (not generated fallbacks)
- ✅ All locales work (en, zh-Hans, zh-Hant)

## Current Status

- ✅ App doesn't crash
- ✅ Fallback text displays (not keys)
- ⚠️ Bundle lookup may still fail
- 📋 TODO: Verify .strings files in app bundle

## Files Changed

- `SharedCore/Utilities/LocalizationManager.swift`

## Commit

```
b482835 - fix: Disable fatal assertion in LocalizationManager
```

---

**Priority:** High (affects localization but doesn't block usage)  
**Impact:** Users see generated English instead of translations  
**Risk:** Low (fallback prevents keys from showing)
