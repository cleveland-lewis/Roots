# watchOS Build Issue - Duplicate Output Files

## Problem

The RootsWatch (watchOS) target fails to build with the following error:

```
error: Multiple commands produce '/path/to/RootsWatch.app/RootsWatch'
    note: Target 'RootsWatch' (project 'RootsApp'): CopyAndPreserveArchs
    note: Target 'RootsWatch' (project 'RootsApp') has link command with output
warning: duplicate output file '/path/to/RootsWatch.app/RootsWatch' on task: 
    CreateUniversalBinary /path/to/RootsWatch.app/RootsWatch normal arm64 x86_64
```

## Root Cause

This is a known Xcode project corruption issue where the build system is creating duplicate build tasks:
1. **CreateUniversalBinary** - Combines arm64 + x86_64 architectures for simulator
2. **CopyAndPreserveArchs** or **Ld (link)** - Also produces the same output file

This typically happens with:
- File-system synchronized groups (new Xcode 15+ feature)
- watchOS targets with multi-architecture simulator builds
- Project file corruption or improper configuration

## Impact

- ❌ watchOS app cannot be built from command line
- ❌ Prevents automated CI/CD builds
- ✅ iOS and macOS builds are NOT affected
- ⚠️  May or may not occur when building from Xcode IDE (depends on settings)

## Attempted Fixes (None Worked)

The following command-line workarounds were attempted but did not resolve the issue:

1. **Clean DerivedData**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```

2. **Set ONLY_ACTIVE_ARCH=YES**
   ```bash
   xcodebuild ... ONLY_ACTIVE_ARCH=YES
   ```

3. **Exclude x86_64 architecture**
   ```bash
   xcodebuild ... EXCLUDED_ARCHS="x86_64"
   ```

4. **Disable build phase warnings**
   ```bash
   xcodebuild ... DISABLE_MANUAL_TARGET_ORDER_BUILD_WARNING=YES
   ```

5. **Use legacy build system**
   ```bash
   xcodebuild ... -UseModernBuildSystem=NO
   ```

6. **Specific device destination**
   ```bash
   xcodebuild ... -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
   ```

All attempts still produced the duplicate output file error.

## Required Fix

This issue **requires manual intervention in Xcode IDE**. It cannot be fixed via command-line tools or code changes.

### Solution Steps (Must be done in Xcode)

1. **Open the project in Xcode**
   ```bash
   open RootsApp.xcodeproj
   ```

2. **Select RootsWatch target**
   - Click on the project in the navigator
   - Select "RootsWatch" target from the targets list

3. **Check Build Phases**
   - Click on "Build Phases" tab
   - Look for duplicate or extra phases:
     - Multiple "Link Binary With Libraries"
     - Extra "Run Script" phases
     - Duplicate "Copy Files" phases
   - **Remove any duplicates**

4. **Check Build Settings**
   - Click on "Build Settings" tab
   - Search for:
     - `CREATE_UNIVERSAL_BINARY` - should be NO for Debug
     - `VALID_ARCHS` - verify correct architectures
     - `ARCHS` - should be `$(ARCHS_STANDARD)` or `arm64 arm64_32`
   - Reset any custom overrides to project defaults

5. **Verify File System Synchronized Groups**
   - watchOS folder might be using "File System Synchronized Groups" (Xcode 15+)
   - Try converting back to explicit file references:
     - Right-click watchOS folder
     - Remove reference
     - Re-add files manually (not as synchronized group)

6. **Alternative: Recreate Watch Target**
   If the above doesn't work:
   - Delete the RootsWatch target completely
   - Create a new watchOS App target
   - Re-add source files
   - Reconfigure build settings

### Verification

After applying fixes in Xcode:

```bash
# Clean and rebuild
cd /Users/clevelandlewis/Desktop/Roots
xcodebuild -project RootsApp.xcodeproj -scheme "RootsWatch" \
  -sdk watchsimulator -destination 'generic/platform=watchOS Simulator' \
  clean build
```

Should see:
```
** BUILD SUCCEEDED **
```

## Current Status

- **Status:** 🔴 **Unresolved** (requires Xcode IDE intervention)
- **Impact:** Low (does not affect iOS/macOS builds)
- **Priority:** Medium (needed for full platform support)
- **Blocking:** watchOS development and testing

## Workaround for Development

Until the Xcode project is fixed, developers can:

1. **Build from Xcode IDE directly** (may work despite command-line failing)
2. **Focus on iOS/macOS development** (both build successfully)
3. **Use iOS simulator** for watch connectivity testing where possible

## References

- Apple Developer Forums: Similar "Multiple commands produce" errors
- Stack Overflow: Xcode duplicate output file issues
- Known Xcode 15/16 bugs with File System Synchronized Groups

## Related Files

- Project file: `/Users/clevelandlewis/Desktop/Roots/RootsApp.xcodeproj/project.pbxproj`
- Watch source: `/Users/clevelandlewis/Desktop/Roots/watchOS/`
- Build logs: `watch_build_*.log`

---

**Last Updated:** December 23, 2024  
**Xcode Version:** 16.x (assumed)  
**Issue Type:** Project Configuration / Build System
