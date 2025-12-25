# Study Hours Tracking: Timer Session Integration

## Overview
Study hours tracking is **fully integrated** with the timer system. Every completed timer session automatically records study time when the `trackStudyHours` setting is enabled.

---

## How It Works (Step-by-Step)

### 1. User Starts Timer Session
**File**: `SharedCore/State/TimerPageViewModel.swift`
- User selects activity and starts Pomodoro/Timer/Stopwatch
- `startSession()` creates new `FocusSession` with unique UUID
- Session begins tracking elapsed time

### 2. User Completes Session
**File**: `SharedCore/State/TimerPageViewModel.swift:197-233`

```swift
func endSession(completed: Bool) {
    guard var s = currentSession else { return }
    s.state = completed ? .completed : .cancelled
    s.endedAt = Date()
    s.actualDuration = sessionElapsed  // 👈 Duration captured here
    
    insertPastSession(s)        // Save to past sessions list
    upsertSessionInStore(s)     // Persist to CoreData
    
    // 🎯 STUDY HOURS TRACKING HAPPENS HERE
    if completed, let actualDuration = s.actualDuration {
        let durationMinutes = Int(actualDuration / 60)
        StudyHoursTracker.shared.recordCompletedSession(
            sessionId: s.id,        // Unique session UUID
            durationMinutes: durationMinutes  // Actual time spent
        )
    }
    // ... rest of cleanup
}
```

**Key Points**:
- Only `completed == true` sessions count (not cancelled)
- `actualDuration` is the real elapsed time (not planned duration)
- Session UUID ensures no double-counting

### 3. Study Hours Tracker Records Time
**File**: `SharedCore/Services/Analytics/StudyHoursTracker.swift:42-68`

```swift
public func recordCompletedSession(sessionId: UUID, durationMinutes: Int) {
    // 1. Check if tracking is enabled
    guard AppSettingsModel.shared.trackStudyHours else { return }
    
    // 2. Prevent double-counting (idempotency)
    guard !completedSessionIds.contains(sessionId) else { return }
    
    // 3. Handle date rollovers (midnight, week, month)
    checkAndResetIfNeeded()
    
    // 4. Update totals
    totals.todayMinutes += durationMinutes
    totals.weekMinutes += durationMinutes
    totals.monthMinutes += durationMinutes
    
    // 5. Mark session as recorded
    completedSessionIds.insert(sessionId)
    
    // 6. Persist to disk
    saveTotals()
    saveCompletedSessionIds()
}
```

**Guarantees**:
- ✅ Same session never counted twice (UUID tracking)
- ✅ Survives app restarts (persisted to JSON)
- ✅ Automatic daily/weekly/monthly rollover
- ✅ Setting can be toggled anytime (respects current state)

### 4. Dashboard Displays Updated Totals
**Files**: 
- `iOS/Scenes/IOSDashboardView.swift:131-176`
- `macOSApp/Scenes/DashboardView.swift:275-320`

```swift
@ObservedObject private var tracker = StudyHoursTracker.shared

private var studyHoursCard: some View {
    RootsCard(...) {
        HStack {
            studyHoursStat(
                label: "Today",
                value: StudyHoursTotals.formatMinutes(tracker.totals.todayMinutes)
            )
            // ... week and month stats
        }
    }
}
```

**Live Updates**:
- `tracker.totals` is `@Published` property
- Dashboard cards use `@ObservedObject` binding
- UI automatically refreshes when session completes
- No manual refresh needed

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. USER COMPLETES TIMER SESSION                             │
│    (Pomodoro/Timer/Stopwatch)                                │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. TimerPageViewModel.endSession(completed: true)            │
│    - Captures actualDuration = sessionElapsed               │
│    - Calls StudyHoursTracker.recordCompletedSession()       │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. StudyHoursTracker.recordCompletedSession()               │
│    ✓ Checks trackStudyHours setting                         │
│    ✓ Prevents double-counting (session UUID)                │
│    ✓ Updates totals (today/week/month)                      │
│    ✓ Persists to disk (JSON files)                          │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Dashboard UI Updates Automatically                        │
│    - @Published totals trigger SwiftUI refresh              │
│    - Cards show updated hours instantly                      │
│    - No manual action required                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Persistence & Idempotency

### Storage Location
```
~/Library/Application Support/RootsAnalytics/
├── study_hours.json          # Current totals + lastResetDate
└── completed_sessions.json    # Array of recorded session UUIDs
```

### Idempotency Strategy
**Problem**: Sessions might be loaded from CoreData on app restart  
**Solution**: Track all recorded session UUIDs in `completed_sessions.json`

```swift
private var completedSessionIds: Set<UUID> = []

// When recording:
guard !completedSessionIds.contains(sessionId) else { 
    return  // Already recorded, skip
}

completedSessionIds.insert(sessionId)
saveCompletedSessionIds()  // Persist immediately
```

**Result**: Even if a session is loaded 100 times, it only counts once.

---

## Date Rollover Logic

**File**: `StudyHoursTracker.swift:79-97`

```swift
private func checkAndResetIfNeeded() {
    let now = Date()
    
    // Daily rollover (midnight)
    if lastResetDay < today {
        totals.todayMinutes = 0
    }
    
    // Weekly rollover (Sunday → Monday, configurable)
    if !calendar.isDate(lastResetDate, equalTo: now, toGranularity: .weekOfYear) {
        totals.weekMinutes = 0
    }
    
    // Monthly rollover (1st of month)
    if !calendar.isDate(lastResetDate, equalTo: now, toGranularity: .month) {
        totals.monthMinutes = 0
    }
    
    totals.lastResetDate = now
}
```

**Behavior**:
- Checked on **every** `recordCompletedSession()` call
- Not a background timer (simpler, more reliable)
- Longer periods preserved during shorter rollovers (week keeps accumulating through days)

---

## Testing the Integration

### Manual Test
1. Enable "Track Study Hours" in Settings → Courses & Planner
2. Go to Timer page
3. Start any timer (Pomodoro/Timer/Stopwatch)
4. Let it run for 1-2 minutes
5. Complete the session (don't cancel)
6. Navigate to Dashboard
7. ✅ Study Hours card should show updated "Today" minutes

### Logs to Watch
```
[StudyHoursTracker] Recorded session: 2 minutes. Today: 2m, Week: 2m
```

### Verify Persistence
1. Complete a session
2. Force quit the app
3. Relaunch
4. Dashboard should still show the same totals
5. Complete another session
6. Total should increase (not reset)

---

## Common Issues & Solutions

### Issue: "Study hours not updating"
**Check**:
1. Is `trackStudyHours` setting enabled? (Settings → Courses & Planner)
2. Did you complete the session? (Cancelled sessions don't count)
3. Check logs for "Recorded session" message

### Issue: "Hours reset unexpectedly"
**Cause**: Date rollover is working correctly
- Daily totals reset at midnight (expected)
- Weekly totals reset on week boundary (expected)
- Monthly totals reset on 1st of month (expected)

### Issue: "Same session counted multiple times"
**Should not happen** due to idempotency
- Check `completed_sessions.json` has session UUIDs
- Each UUID should appear only once in totals

---

## Future Enhancements

1. **Course Breakdown**: Track hours per course/activity (data structure ready)
2. **Historical Trends**: Keep weekly/monthly history (currently only current period)
3. **iCloud Sync**: Sync totals across devices
4. **Analytics Charts**: Visual representation of study patterns
5. **Goal Setting**: Daily/weekly hour targets with progress

---

## Code References

| Component | File | Line |
|-----------|------|------|
| Timer completion | `TimerPageViewModel.swift` | 197-233 |
| Recording call | `TimerPageViewModel.swift` | 224-229 |
| Tracker logic | `StudyHoursTracker.swift` | 42-68 |
| Persistence | `StudyHoursTracker.swift` | 104-156 |
| iOS Dashboard | `IOSDashboardView.swift` | 131-176 |
| macOS Dashboard | `DashboardView.swift` | 275-320 |

---

**Status**: ✅ Fully integrated and tested  
**Last Updated**: December 25, 2024  
**Build Status**: All platforms compile successfully
