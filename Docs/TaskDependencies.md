# Task Dependencies (Issue #70)

## Overview
Task dependencies allow you to create sequenced task chains where tasks must be completed in a specific order. This is essential for workflows like exam preparation (Study → Practice → Review) or multi-stage projects.

## Features

### Dependency Enforcement Toggle
- **Enable/Disable**: Toggle "Enforce Task Order" per assignment
- **Auto-Setup**: Automatically creates linear chain (A→B→C→D) when first enabled
- **Persistent**: Setting saved per assignment plan

### Task Ordering
- **Drag-to-Reorder**: Drag tasks up/down to change sequence
- **Visual Feedback**: Live preview during drag
- **Sequence Numbers**: Clear numbering shows task order
- **Automatic Dependencies**: Dependencies rebuild after reordering

### Visual Indicators

**Dependency Markers:**
- Arrow icon (→) indicates task depends on previous task
- Shown next to tasks with prerequisites

**Status Badges:**
- **Completed**: Green checkmark - task finished
- **Blocked**: Orange lock - waiting for prerequisites
- **Available**: No badge - ready to start

**Task States:**
- Orange border highlights blocked tasks
- Sequence numbers show execution order
- Drag handles indicate reorderable items

### Safety Features

**Cycle Detection:**
- Prevents circular dependencies (A→B→C→A)
- Shows alert if cycle would be created
- Reverts invalid changes automatically

**Validation:**
- Real-time dependency checking
- Prevents invalid graph structures
- Maintains data integrity

## User Interface

### Main View
```
┌─────────────────────────────────────┐
│ Task Dependencies                   │
│ Assignment Title                    │
│                                     │
│ [Toggle] Enforce Task Order        │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ ⓘ Task Order Enforced               │
│ Tasks must be completed in sequence │
│                    [Clear Deps]     │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Task Order                          │
│                                     │
│  ① → Read Chapter 5       45 min   │
│  ②   Practice Problems    60 min   │
│  ③ 🔒 Take Practice Exam  90 min  ═│ ← Blocked
│  ④   Review Mistakes      30 min   │
└─────────────────────────────────────┘
```

### Dependency Flow
```
Linear Chain Example:
Study → Practice → Review

Multi-Prerequisite Example:
Read Ch1 ─┐
          ├─→ Write Essay
Read Ch2 ─┘
```

## How It Works

### Data Model
Each `PlanStep` has:
- `prerequisiteIds: [UUID]` - Which tasks must complete first
- `sequenceIndex: Int` - Position in the list

Each `AssignmentPlan` has:
- `sequenceEnforcementEnabled: Bool` - Whether to enforce dependencies

### Algorithms

**Topological Sort:**
- Orders tasks respecting all dependencies
- Returns nil if cycle detected
- Used for schedule generation

**Cycle Detection:**
- DFS with recursion stack
- Captures full cycle path
- Prevents invalid graphs

**Blocked Check:**
- Step blocked if any prerequisite incomplete
- Only applies when enforcement enabled
- Real-time status updates

### Linear Chain Setup
When enforcement enabled for first time:
```swift
plan.setupLinearChain()
// Creates: step1 → step2 → step3 → step4
```

Each task depends on previous task in sequence.

## User Workflows

### Enable Dependencies
1. Open Task Dependency Editor
2. Toggle "Enforce Task Order" ON
3. Linear chain automatically created
4. Dependencies shown with arrows

### Reorder Tasks
1. Click and hold drag handle (≡)
2. Drag task up or down
3. Release to drop in new position
4. Dependencies automatically rebuild

### View Blocked Tasks
1. Tasks with lock icon (🔒) are blocked
2. Orange border highlights blocked state
3. Tooltip shows prerequisites
4. Complete prerequisites to unblock

### Clear Dependencies
1. Click "Clear Dependencies" button
2. Removes all prerequisite relationships
3. Tasks can be completed in any order
4. Enforcement toggle remains on/off as set

## Integration Points

### Current (Phase 2)
- ✅ Standalone editor view
- ✅ Access via direct link/button
- ✅ Full CRUD operations
- ✅ Visual feedback and validation

### Future (Phase 3)
- [ ] Planner page integration
- [ ] Scheduler respects blocking
- [ ] Timeline view shows dependencies
- [ ] Cross-assignment dependencies
- [ ] Completion-gated unlocking

## Technical Details

### Files Modified
- `AssignmentPlan.swift` - Added dependency fields
- `AssignmentPlanStore.swift` - Added dependency methods
- `TaskDependencyEditorView.swift` - New UI (361 lines)
- `AssignmentPlanDependencyTests.swift` - Test suite (179 lines)

### Data Persistence
- Dependencies stored in `prerequisiteIds` array
- Enforcement flag stored in `sequenceEnforcementEnabled`
- Persisted to JSON cache automatically
- Backward compatible with existing plans

### Performance
- O(V + E) cycle detection
- O(V + E) topological sort
- Real-time validation on changes
- Efficient in-memory updates

## Testing

### Test Coverage
- ✅ Linear chain setup
- ✅ Blocked step detection
- ✅ Cycle detection
- ✅ Topological sorting
- ✅ Prerequisite navigation
- ✅ Store operations
- ✅ Edge cases (empty, cycles)

### Manual Testing
1. Create assignment plan with multiple steps
2. Open Task Dependency Editor
3. Toggle enforcement on/off
4. Drag to reorder tasks
5. Complete tasks and verify blocking
6. Attempt to create cycle (should fail)
7. Clear dependencies and verify reset

## Limitations (Phase 2)

### Not Yet Implemented
- Multi-prerequisite graph editor (only linear chains)
- Visual graph/tree view
- Cross-assignment dependencies
- Completion-gated unlocking in UI
- Scheduler integration with blocking
- Analytics on dependency patterns

### Current Constraints
- Linear dependencies only (A→B→C)
- Manual reordering (no AI suggestions)
- No dependency visualization graph
- No bulk dependency operations

## Future Enhancements

### Phase 3 Possibilities
- Gantt chart view
- Dependency graph visualization
- Critical path highlighting
- Estimated completion dates
- Smart reordering suggestions
- Template dependency patterns
- Cross-course dependencies

## Troubleshooting

### "Dependency Cycle Detected" Alert
**Cause**: Attempting to create circular dependency
**Solution**: Review task order and remove circular reference

### Task Appears Blocked Incorrectly
**Check**: 
1. Is enforcement enabled?
2. Are prerequisites actually completed?
3. Is step assigned correct prerequisiteIds?

### Drag-and-Drop Not Working
**Check**:
1. Is plan loaded?
2. Are there tasks in the plan?
3. Try clicking drag handle (≡) specifically

### Dependencies Not Saving
**Check**:
1. Plan exists for assignment?
2. Check console for error logs
3. Verify cache file permissions

## Related Documentation
- `AnimationGuidelines.md` - UI motion system
- `DesignSystem+Motion.swift` - Animation tokens
- `AssignmentPlan.swift` - Data model reference

## Support
For issues or questions:
1. Check console logs for errors
2. Verify plan data structure
3. Run dependency tests
4. Review cycle detection output
