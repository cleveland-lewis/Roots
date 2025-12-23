# iOS Practice Tab Device Filtering

## Summary
Removed the Practice tab from iPhone while keeping it available on iPad by filtering based on horizontal size class.

## Changes Made

### iOS/Root/IOSRootView.swift
- Added `@Environment(\.horizontalSizeClass)` to detect device type
- Modified `starredTabs` computed property to filter out `.practice` tab when `horizontalSizeClass == .compact` (iPhone)
- Practice tab remains visible on iPad where `horizontalSizeClass == .regular`

## Implementation Details

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

private var starredTabs: [RootTab] {
    let starred = settings.starredTabs
    var tabs = starred.isEmpty ? [.dashboard] : starred
    
    // Remove Practice tab on iPhone (compact width)
    if horizontalSizeClass == .compact {
        tabs.removeAll { $0 == .practice }
    }
    
    // Ensure at least Dashboard is present
    return tabs.isEmpty ? [.dashboard] : tabs
}
```

## Behavior

### iPhone (compact horizontal size class)
- Practice tab is automatically removed from the tab bar
- Users cannot select Practice from starred tabs on iPhone
- The tab simply doesn't appear in the UI

### iPad (regular horizontal size class)
- Practice tab remains fully available
- Can be starred and accessed normally
- Functions as before

## Technical Notes

1. **Size class detection**: Uses SwiftUI's built-in `horizontalSizeClass` environment variable which automatically adjusts based on device and orientation
2. **Dynamic filtering**: The tab list updates automatically when the size class changes (e.g., iPad split-screen mode)
3. **Settings compatibility**: Users' starred tab preferences are preserved; the filter only affects display
4. **Fallback safety**: Always ensures at least Dashboard tab is present

## Testing Checklist

- [x] Build succeeds on iOS simulator
- [ ] Verify Practice tab absent on iPhone simulator
- [ ] Verify Practice tab present on iPad simulator
- [ ] Test that other tabs function normally
- [ ] Verify settings don't break when Practice is in starred tabs list

## Files Modified
- `iOS/Root/IOSRootView.swift`

## Build Status
✅ iOS build successful
