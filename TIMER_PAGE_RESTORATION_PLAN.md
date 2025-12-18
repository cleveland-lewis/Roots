# TimerPageView Gradual Restoration Plan

## Current Status
✅ Simple version works perfectly
❌ Full version causes infinite loop/deadlock

## Restoration Strategy
Add components incrementally, testing after each addition to pinpoint the exact cause.

## Phase 1: Environment Objects (one at a time)
1. Add @EnvironmentObject var settings: AppSettingsModel
2. Test - if works, add next
3. Add @EnvironmentObject var assignmentsStore: AssignmentsStore
4. Test
5. Add @EnvironmentObject var calendarManager: CalendarManager
6. Test
7. Add @EnvironmentObject var appModel: AppModel
8. Test
9. Add @EnvironmentObject var settingsCoordinator: SettingsCoordinator
10. Test

## Phase 2: State Variables (groups)
1. Add basic @State variables (mode, activities, etc.)
2. Test
3. Add timer-related @State (isRunning, remainingSeconds, etc.)
4. Test

## Phase 3: Computed Properties
1. Add simple computed properties
2. Test
3. Add complex computed properties (collections, filtered, etc.)
4. Test

## Phase 4: Body Content
1. Replace Text with actual ScrollView structure
2. Test
3. Add topBar
4. Test
5. Add mainGrid (simplified)
6. Test
7. Add bottomSummary
8. Test

## Phase 5: View Modifiers
1. Add .onAppear
2. Test
3. Add .onChange handlers
4. Test
5. Add other modifiers
6. Test

After each phase, if deadlock occurs, we know exactly what caused it!
