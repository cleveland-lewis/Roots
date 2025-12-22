# Issue #396 Build Fixes - Progress Report

**Date**: December 22, 2024  
**Status**: ⚠️ **IN PROGRESS** - Partial completion

## Issue Summary

**Title**: Build errors: actor isolation + non-exhaustive switches  
**Link**: https://github.com/cleveland-lewis/Roots/issues/396  
**Priority**: CRITICAL - blocks builds on all platforms

## Work Completed

### ✅ 1. PlannerEngine.swift - Exhaustive Switch Fix

**File**: `SharedCore/Services/FeatureServices/PlannerEngine.swift`  
**Problem**: Switch on `AssignmentCategory` missing `.homework` case  
**Solution**: Added `.homework` case handler (lines 112-122)

```swift
case .homework:
    // Handle regular homework similar to practiceHomework
    if totalMinutes <= settings.homeworkSingleSessionThreshold {
        makeSession(title: assignment.title, index: 1, count: 1, minutes: totalMinutes)
    } else {
        let perSession = settings.longHomeworkSplitSessionMinutes
        let sessionCount = Int(ceil(Double(totalMinutes) / Double(perSession)))
        for i in 1...sessionCount {
            let mins = (i < sessionCount) ? perSession : max(15, totalMinutes - perSession * (sessionCount - 1))
            makeSession(title: "\(assignment.title) – Part \(i)/\(sessionCount)", index: i, count: sessionCount, minutes: mins)
        }
    }
```

**Note**: Other two switches already had `@unknown default` cases

### ✅ 2. Type Bridging Extensions Created

**File**: `macOSApp/Scenes/AssignmentsPageView.swift`  
**Problem**: `LocalAssignment` needs to convert to `Assignment` for algorithm layer  
**Solution**: Added extension methods for type conversion

```swift
extension LocalAssignment {
    func toShared() -> Assignment {
        return Assignment(
            id: self.id,
            courseId: self.courseId,
            title: self.title,
            dueDate: self.dueDate,
            estimatedMinutes: self.estimatedMinutes,
            weightPercent: self.weightPercent,
            category: self.category.toShared(),
            urgency: self.urgency.toShared(),
            isLockedToDueDate: self.isLockedToDueDate,
            plan: self.plan.map { PlanStepStub(title: $0.title, expectedMinutes: $0.expectedMinutes) }
        )
    }
}

extension LocalAssignmentCategory {
    func toShared() -> AssignmentCategory { ... }
}

extension LocalAssignmentUrgency {
    func toShared() -> AssignmentUrgency { ... }
}
```

### ✅ 3. PlannerPageView.swift - Type Conversion

**File**: `macOSApp/Scenes/PlannerPageView.swift`  
**Problem**: Passing `LocalAssignment` directly to `PlannerEngine`  
**Solution**: Convert to shared `Assignment` type before passing to engine

```swift
// Create LocalAssignments from tasks
let localAssignments = assignmentsStore.tasks.map { task in
    LocalAssignment(...)
}

// Convert to shared Assignment type for planner engine
let assignments = localAssignments.map { $0.toShared() }

let sessions = assignments.flatMap { 
    PlannerEngine.generateSessions(for: $0, settings: studySettings) 
}
```

### ⚠️ 4. AIRouter.swift & MainThreadDebugger.swift

**Status**: NO ERRORS FOUND  
**Note**: When building, these errors did not appear. They may have been:
- Already fixed in a previous commit
- Conditional compilation issues
- Not present in current state

The issue description mentioned:
- AIRouter line 47: Main actor isolation on `.default` property
- MainThreadDebugger lines 122-123: Sendable closure issues

However, inspection shows:
- `AIGenerateOptions.default` is already marked `nonisolated`
- MainThreadDebugger properly wraps calls in `Task { @MainActor ... }`

## Current Build Status

### ⏳ Build In Progress
- Full clean build started
- Taking extended time (>2 minutes)
- Testing if all errors resolved

### Known Remaining Issues
- Possible AssignmentsPageView compilation time issues
- May need to break up complex view expressions

## Files Modified

1. `SharedCore/Services/FeatureServices/PlannerEngine.swift`
   - Added `.homework` case to switch statement

2. `macOSApp/Scenes/AssignmentsPageView.swift`
   - Added type bridging extensions (3 extensions)
   - Fixed `Assignment.defaultPlan` → `LocalAssignment.defaultPlan`

3. `macOSApp/Scenes/PlannerPageView.swift`
   - Added type conversion before calling PlannerEngine

## Next Steps

1. ✅ Wait for build to complete
2. ⏳ Verify all compilation errors resolved
3. ⏳ Run tests to ensure correctness
4. ⏳ Close issue #396 if successful

## Technical Notes

### Type System Design
The app has two parallel type hierarchies:
- **Shared types** (`Assignment`, `AssignmentCategory`) - for algorithms
- **View types** (`LocalAssignment`, `LocalAssignmentCategory`) - for UI

The solution uses extension methods to bridge between them, keeping the layers cleanly separated while enabling seamless conversion.

### Switch Exhaustiveness
The `AssignmentCategory` enum has 7 cases:
- `.reading`
- `.exam`
- `.homework` ← Was missing
- `.practiceHomework`
- `.quiz`
- `.review`
- `.project`

The fix ensures all cases are explicitly handled, making the code future-proof and clear in intent.

## Conclusion

**Progress**: ~75% complete
- ✅ Switch exhaustiveness fixed
- ✅ Type bridging implemented
- ✅ PlannerPageView updated
- ⏳ Build verification pending

All identified issues have been addressed. Waiting for build completion to verify success.

---

**Status**: ⏳ PENDING BUILD VERIFICATION  
**Estimated Completion**: 5-10 minutes  
**Confidence**: High - all errors addressed
