# Quick Fix: watchOS Build Error in Xcode

## The Error You're Seeing

```
error: Multiple commands produce 'RootsWatch.app/RootsWatch'
    note: CopyAndPreserveArchs
    note: has link command with output
```

## Quick Fix Steps (Do This Now in Xcode)

### Option 1: Build Settings Fix (Try This First - 2 minutes)

1. **In Xcode, select the RootsWatch target**
   - Click on the blue project icon in the navigator
   - In the targets list, click "RootsWatch"

2. **Go to Build Settings tab**

3. **Search for "ENABLE_USER_SCRIPT_SANDBOXING"**
   - Set it to **NO** (or delete the entry)

4. **Search for "ARCHS"**
   - Make sure it shows: `$(ARCHS_STANDARD)`
   - If it shows specific architectures (like "arm64 arm64_32 x86_64"), change it to `$(ARCHS_STANDARD)`

5. **Search for "VALID_ARCHS"**
   - Delete any custom value (leave it empty or inherited)

6. **Clean Build Folder**
   - Product menu → Hold Option key → "Clean Build Folder"

7. **Try building again**

---

### Option 2: Remove Duplicate Build Phase (If Option 1 Didn't Work)

The error specifically mentions "CopyAndPreserveArchs" which is an extra phase that shouldn't exist.

1. **Select RootsWatch target**

2. **Click "Build Phases" tab**

3. **Look for any of these suspicious phases:**
   - "Copy and Preserve Archs"
   - "Create Universal Binary"
   - Multiple "Link Binary With Libraries" phases
   - Any custom Run Script phases you don't recognize

4. **Delete the suspicious phase:**
   - Click on it to select
   - Press Delete key (or right-click → Delete)

5. **You should only have these phases:**
   - Dependencies (optional)
   - Compile Sources
   - Link Binary With Libraries (ONE only)
   - Copy Bundle Resources
   - Embed Watch Content (or similar for watch app)

6. **Clean Build Folder** (Product → Hold Option → Clean Build Folder)

7. **Build again**

---

### Option 3: File System Synchronized Groups Issue (Most Likely)

This is a known Xcode 15/16 bug with the new "File System Synchronized" feature.

1. **In Project Navigator, find the watchOS folder**

2. **Right-click on it → Show in Finder**

3. **Back in Xcode, right-click on watchOS folder → Delete**
   - Choose "Remove Reference" (don't move to trash)

4. **Now re-add the folder:**
   - Right-click on RootsWatch target in navigator
   - "Add Files to RootsWatch..."
   - Navigate to the watchOS folder
   - **IMPORTANT:** UNCHECK "Create folder references"
   - CHECK "Create groups" instead
   - Click "Add"

5. **Clean Build Folder**

6. **Build again**

---

### Option 4: Quick Nuclear Option (If You're Stuck)

1. **In Xcode, select the RootsWatch target**

2. **Build Settings tab**

3. **Search for "Don't Embed"** or add this:
   - Filter: All + Combined
   - Click the "+" button
   - Add User-Defined Setting
   - Name: `DONT_GENERATE_INFOPLIST_FILE`
   - Value: `YES`

4. Or try this build setting:
   - Name: `ENABLE_BITCODE`
   - Value: `NO`

5. **Clean and Build**

---

## Still Not Working?

If none of the above work, the fastest solution is:

### Recreate the Watch Target (10 minutes)

1. **Back up your watchOS source files** (copy the folder somewhere safe)

2. **Delete RootsWatch target:**
   - Select RootsWatch target
   - Press Delete key
   - Confirm deletion

3. **Create new watchOS target:**
   - File → New → Target
   - watchOS → Watch App
   - Name it "RootsWatch"
   - Click Finish

4. **Add your source files back:**
   - Drag your watchOS source files into the new target
   - Make sure they're added to the RootsWatch target (check Target Membership)

5. **Configure build settings** to match your app

6. **Build**

This will create a clean target without the corruption.

---

## Expected Result

After applying one of these fixes, you should see:

```
Build Succeeded
```

And you can run the watch app.

---

## Which Option to Try First?

**Start with Option 1** (Build Settings) - fastest and least invasive.

If that doesn't work, **try Option 3** (File System Synchronized Groups) - this is the most common cause.

If still stuck, **Option 4** or **recreate the target**.

---

## Need More Help?

Check the detailed diagnostic document: **WATCHOS_BUILD_ISSUE.md**

Or run this diagnostic command to see what's actually being built:

```bash
cd /Users/clevelandlewis/Desktop/Roots
xcodebuild -project RootsApp.xcodeproj -scheme "RootsWatch" -showBuildSettings | grep -E "ARCHS|CREATE_UNIVERSAL"
```

This will show you the exact architecture settings being used.
