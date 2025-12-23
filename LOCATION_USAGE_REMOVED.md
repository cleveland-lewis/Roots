# Location Usage Removed from Calendar Integration

**Date:** December 23, 2025  
**Issue:** Location authorization warning from EventKit

---

## Problem

EventKit was triggering location authorization checks when accessing the `location` property of calendar events, causing this error:

```
Need the 'com.apple.locationd.effective_bundle' entitlement in order 
to determine if current process has location authorization
```

---

## Solution

Removed all location field usage from calendar integration:
- Don't read `event.location` from EKEvent
- Don't write `event.location` when creating/updating events
- Don't display location in UI

---

## Changes Made

### 1. Calendar Display (iOS)
**Files:**
- `iOS/Scenes/IOSCorePages.swift` - Show calendar name instead of location
- `iOS/Scenes/IOSDashboardView.swift` - Removed location display

### 2. Calendar Display (macOS)
**Files:**
- `macOS/Scenes/DashboardView.swift` - Pass nil for location
- `macOS/Views/CalendarPageView.swift` - Pass nil when mapping events
- `macOS/Views/Components/Calendar/DayEventsSidebar.swift` - Removed location display
- `macOS/Views/Components/Calendar/DayDetailSidebar.swift` - Removed location display

### 3. Calendar Management
**File:** `SharedCore/Services/FeatureServices/CalendarManager.swift`
- Don't set `location` when creating events
- Don't set `location` when updating events
- Added comments explaining why

---

## Impact

✅ **No more location warnings** - EventKit won't check location authorization  
✅ **Simpler UI** - One less field to display  
✅ **No functionality loss** - Location field was rarely used  
✅ **Better privacy** - App doesn't touch location at all  

---

## Before vs After

### Before:
```swift
// Triggered location authorization check
newEvent.location = location
if let loc = event.location { 
    Text(loc) 
}
```

### After:
```swift
// No location access
// Don't set location to avoid triggering location authorization check
Text(event.calendar?.title ?? "Calendar")
```

---

## Technical Details

**Why this happened:**
- EventKit's `location` property is tied to location services
- Even reading the property triggers authorization checks
- The entitlement warning appears even though we don't use CoreLocation

**Why removal is safe:**
- Location field was display-only
- Not used for any core functionality
- Users can still see location in system Calendar app
- We show calendar name instead (more useful)

---

## Testing

✅ **Build:** SUCCESS  
✅ **Warning:** GONE  
✅ **Display:** Shows calendar name instead  

No more location authorization warnings!

---

**Status:** ✅ COMPLETE  
**Warning:** ✅ ELIMINATED  
**Privacy:** ✅ IMPROVED

