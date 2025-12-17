# Timer Page Freeze - Diagnostic Instructions

## What You Need To Do NOW

### Step 1: Enable All Diagnostics in Xcode

1. Open the project in Xcode
2. Click on the scheme dropdown (near the Play button) → "Edit Scheme..."
3. Go to "Run" → "Diagnostics" tab
4. **Enable these checkboxes:**
   - ✅ **Address Sanitizer** (catches use-after-free, buffer overflows)
   - ✅ **Thread Sanitizer** (catches data races) - NOTE: Can't use with Address Sanitizer, try separately
   - ✅ **Undefined Behavior Sanitizer**
   - ✅ **Main Thread Checker** (should already be on)
   - ✅ **Malloc Scribble** (catches freed memory access)
   - ✅ **Malloc Guard Edges**
   - ✅ **Guard Malloc**
   - ✅ **Zombie Objects** (catches messages to deallocated objects)

### Step 2: Run the App and Reproduce the Freeze

1. Run the app from Xcode (⌘R)
2. Click on the Timer tab
3. **WATCH THE XCODE CONSOLE** - it will show the exact line that causes the crash
4. Copy the console output and paste it

### Step 3: What to Look For

The console will show something like:
```
Thread 1: EXC_BAD_ACCESS (code=1, address=0x...)
```

Or with Address Sanitizer:
```
==12345==ERROR: AddressSanitizer: heap-use-after-free on address 0x...
```

**This will point to the EXACT line of code** causing the freeze.

## Common Causes (What I Suspect)

Based on the code structure, likely culprits:

### 1. Timer Publisher Issue (Already Fixed)
The timer auto-connecting before view is ready.
**Status:** ✅ Fixed in TimerPageView.swift

### 2. EventsCountStore Memory Issue (Already Fixed) 
Creating new instance instead of @StateObject.
**Status:** ✅ Fixed in RootsApp.swift

### 3. Background Thread Publishing (LIKELY CULPRIT)
Look for any of these in Timer-related files:
```swift
DispatchQueue.global().async {
    self.somePublishedProperty = value  // ❌ WRONG - must be on main thread
}

Task.detached {
    await someViewModel.update()  // ❌ Check if this publishes @Published properties
}
```

### 4. Dangling Timer References
```swift
Timer.scheduledTimer(...)  // Not stored, can't be cancelled
```

### 5. Unowned/Weak Capture Issues
```swift
.sink { [unowned self] in  // ❌ Can crash if self is deallocated
    self.doSomething()
}
```

## What to Send Me

After running with diagnostics enabled, send:

1. **Exact console output** when the freeze happens
2. **Screenshot** of the Xcode debugging view showing the paused thread
3. **Which diagnostic** (Address Sanitizer, Thread Sanitizer, etc.) caught it

This will tell us the EXACT line causing the issue.

---
**Note:** The fixes I made are good preventative measures, but we need the diagnostic output to find the actual freeze cause.
