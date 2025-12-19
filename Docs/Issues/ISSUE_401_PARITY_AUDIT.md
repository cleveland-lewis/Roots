# ISSUE-401 Parity Audit — iOS/iPadOS Timer vs macOS

## Scope
- Timer / Pomodoro / Stopwatch parity
- AlarmKit loud alarm (iOS/iPadOS only)
- Live Activity (iOS/iPadOS only)

## macOS Timer features (current)
- Modes: Timer, Pomodoro, Stopwatch
- Activity management: list, search, collections filter, pinned items
- Notes per activity (TextEditor)
- Session history list
- Start/Pause/Resume/Stop/Skip segment
- Activity selection + quick actions
- Persisted state (activities, collections, sessions, durations)

## iOS Timer features (current)
- Modes: Timer, Pomodoro, Stopwatch
- Activity management: add/select/delete (basic list)
- Session history (recent sessions)
- Start/Pause/Resume/Stop/Skip segment
- Live Activity sync hook present
- AlarmKit toggle in settings (not implemented)
- Persisted state via shared TimerPageViewModel

## Delta checklist (to close)
- UI parity
- [x] Activity notes editor (per activity)
- [x] Collections filter + pinned items + search
  - [ ] Activity list grouping (Pinned / All)
  - [ ] Additional activity detail panel (selected activity)
  - [ ] Match macOS layout for iPad split view
- AlarmKit
  - [ ] Implement AlarmKit scheduling/cancel in `IOSTimerAlarmScheduler`
  - [ ] Handle authorization + fallback messaging
  - [ ] Default to enabled if authorized
- Live Activity
  - [x] Live Activity update hooks in iOS timer view
  - [ ] Verify update throttling and end on stop
- Testing
  - [ ] iOS smoke test: start timer → background → Live Activity → completion

## Notes
- AlarmKit API still TODO in codebase; block until API usage is finalized.
- Live Activity manager updated recently; verify on device once build passes.

## Smoke Test (iOS)
1. Start a Pomodoro session.
2. Lock device; verify Live Activity appears.
3. Pause and resume; verify Live Activity updates.
4. Stop session; verify Live Activity ends.
5. Start a Timer; background the app; verify completion alert (AlarmKit if authorized, notification fallback otherwise).
