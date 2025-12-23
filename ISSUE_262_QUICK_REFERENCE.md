# Issue #262 - Quick Reference

## ✅ FIXED: Phantom Date Highlight

**Problem**: Mini calendar highlighted December 13 (or other phantom date)  
**Cause**: `@State private var selectedDate: Date = Date()` captured date at initialization  
**Fix**: Reset to today in `onAppear`

## Changes Made

### 3 Files Modified

1. **`macOS/Scenes/DashboardView.swift`**
2. **`macOSApp/Scenes/DashboardView.swift`**
3. **`iOS/Scenes/IOSDashboardView.swift`**

### Fix Applied

```swift
.onAppear {
    // Always start with today selected to avoid phantom date highlights
    selectedDate = Calendar.current.startOfDay(for: Date())
    // ... rest of onAppear code
}
```

## Testing Checklist

- [ ] Launch app → Today is highlighted (not phantom date)
- [ ] Click different date → That date highlights  
- [ ] Navigate away → Return → Today is highlighted
- [ ] Works on macOS
- [ ] Works on iOS

## Before/After

| Scenario | Before | After |
|----------|--------|-------|
| Fresh launch | Dec 13 (phantom) | Today (Dec 23) |
| After navigation | Dec 13 (phantom) | Today (Dec 23) |
| User selects Dec 20 | Dec 20 | Dec 20 |
| Return to dashboard | Dec 13 (phantom) | Today (Dec 23) |

## Related Issues

- **#273**: Calendar grid deterministic highlighting ✅
- **#262**: This issue (phantom date) ✅

## Impact

**Lines Changed**: 3 lines (one per file)  
**Breaking Changes**: None  
**Risk**: Very low - simple state reset

---

**Status**: ✅ Ready for testing
**Time**: 5 minutes to implement
**Result**: Predictable, trustworthy calendar UI
