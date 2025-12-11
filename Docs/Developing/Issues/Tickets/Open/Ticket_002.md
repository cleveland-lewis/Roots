# TICKET-002 — Locking for Scheduler

## Category: Critical

## Title: Locking Model, UI, and Engine Enforcement

### Goal: Implement a unified locking system for events and tasks so the scheduler treats locked items as immutable, preventing movement, deletion, or modification by automated systems.

⸻

1. Overview

The scheduler must respect human intent over algorithmic behavior. A user must be able to mark any event or task as locked, meaning:
	•	The scheduler must never move it
	•	The scheduler must never delete it
	•	The scheduler must treat it as a “hard constraint”
	•	The user interface must clearly represent the locked state
	•	The data model must persist locked state safely and consistently
	•	All engines (calendar engine, task engine, scheduling engine, dashboard UI) must react identically

A locked item is effectively a pinned block of space-time in the app’s semantic model.
Locking is binary, thread-safe, persisted, reversible, and visually obvious.

⸻

2. Success Criteria (Expanded)

The following conditions must be strictly met before TICKET-002 is considered complete:

2.1 Unified data model
	•	All schedulable types (CalendarEvent, TodoTask, Assignment, AIScheduledBlock) include a persistent property:
	•	locked: Bool
	•	This property must be:
	•	Stored in JSON/SQLite/CoreData depending on final persistence choice
	•	Written and read atomically
	•	Fully represented in Codable, hashing, diffing, and mirror representations
	•	Covered by migration tests (TICKET-010)

2.2 User controls
	•	Every schedulable item has:
	•	A Lock / Unlock contextual action
	•	A visible lock indicator
	•	A consistent UI gesture to toggle the state:
	•	⌘L on macOS
	•	Swipe-left on iOS
	•	Context menu entry on both platforms

2.3 Scheduler enforcement
	•	When locking is enabled:
	•	Scheduler treats locked items as hard constraints
	•	Locked items cannot:
	•	Be moved
	•	Be deleted
	•	Be resized
	•	Be overwritten by new suggestions
	•	Be replaced during rescheduling cycles

2.4 Integration consistency
	•	All systems (calendar page, dashboard, task views, daily planner, AI suggestions, Motion-like scheduling engine) read and respect locked == true.
	•	Lock icons appear the same across:
	•	Dashboard
	•	Calendar Day/Week/Month view
	•	Assignment detail view
	•	Task editor
	•	Liquid Glass overlays

2.5 Persistence must survive:
	•	App relaunch
	•	Device reboot
	•	Sync operations
	•	Version migrations

2.6 Automated tests
	•	Regression tests proving:
	•	Scheduler cannot move locked items
	•	Locking persists across reload
	•	Attempted movement yields internal failure states without altering data
	•	Correct UI state restoration

⸻

3. User Stories (Expanded)

3.1 Hard Blocking
	•	As a student with ADHD/ASD, I want to ensure important events (class, exam time, doctor appointments) are absolutely not overridden by AI scheduling.

3.2 Priority Overrides
	•	As a user, I want to lock a deadline I’m afraid of missing so the system won’t shuffle it under the assumption that other tasks matter more.

3.3 Confidence Building
	•	Knowing that locked events will never move reduces cognitive load and prevents scheduler-induced anxiety.

3.4 Scheduler Predictability
	•	Locking prevents the Motion-style AI engine from performing large-scale reflows that break user commitments.

⸻

4. Data Model Specification

4.1 Unified Protocol

protocol Lockable: Identifiable, Codable {
    var locked: Bool { get set }
}

4.2 Event Structure

struct CalendarEvent: Lockable, Codable {
    var id: UUID
    var title: String
    var start: Date
    var end: Date
    var source: EventSource
    var locked: Bool
    var referenceID: UUID?
}

4.3 Task Structure

struct TodoTask: Lockable, Codable {
    var id: UUID
    var title: String
    var dueDate: Date?
    var estimatedMinutes: Int
    var locked: Bool
}

4.4 Suggested Block Structure

struct AIScheduledBlock: Lockable, Codable {
    var id: UUID
    var start: Date
    var end: Date
    var referenceID: UUID
    var locked: Bool
}

4.5 Serialization Rules
	•	locked must always serialize directly:
	•	true → "locked": true
	•	false → "locked": false
	•	No fallback defaults
	•	No omission allowed

4.6 Migration Policy

When loading older data:
	•	If locked is missing → default to false
	•	Migration code must log:
	•	Migrated legacy item X; added locked: false

⸻

5. UI Specification

5.1 Lock iconography

Use SF Symbol:
	•	lock.fill when locked
	•	lock.open when unlocked

Size rules:
	•	Minimum 12pt
	•	Maximum 18pt
	•	Color adapts to theme

5.2 Interaction patterns

macOS
	•	Right-click event → “Lock” / “Unlock”
	•	Press ⌘L
	•	Lock toggle in inspector pane

iOS
	•	Swipe-left → “Lock”
	•	Long press → context menu → “Lock”
	•	In detail sheet → Lock toggle row

5.3 Visual impact

Locked items must visually convey “fixedness”:
	•	Slight border (1px)
	•	Slight desaturation of color
	•	Lock icon in top-right corner
	•	In calendar grid:
	•	Locked events appear “heavier”—lower transparency than suggestion blocks

5.4 Disabled behaviors

For locked items:
	•	Dragging disabled
	•	Resizing handles hidden
	•	Edit button disabled except for:
	•	Notes
	•	Description
	•	Attachment metadata

5.5 Accessibility Requirements
	•	accessibilityLabel = "Locked Event"
	•	VoiceOver reads:
	•	“Event locked. Cannot be moved.”
	•	Haptic feedback when toggling

⸻

6. Scheduler Enforcement (Deep Technical Specification)

6.1 Hard Constraint Definition

A hard constraint is any event where:
	•	event.locked == true
	•	OR event.source == .calendar (external calendars)
	•	OR event.sourceSchool == true && source == .calendar

6.2 Scheduling Pipeline Behavior

During free slot computation:
	•	Locked events populate busyIntervals immutable list

During candidate placement:
	•	Scheduler checks:

if event.locked { rejectMove() }


	•	No AI block can overlap a locked item

During re-run:
	•	When removing stale AI-suggested blocks:
	•	Do not delete locked blocks
	•	Do not modify locked tasks
	•	Do not adjust start/end times

6.3 Scheduler Failure Modes

If the scheduler generates an action that would modify a locked item:
	•	Do not modify user data
	•	Log event to debug log
	•	Hard fail in silent fallback mode
	•	Present non-intrusive UI message:
	•	“Some items are locked and were not moved.”

6.4 Scheduling Graph Rules

Locked events create unbreakable nodes in the scheduling graph:
	•	All freeTime trees must be pruned around these nodes
	•	No candidate can traverse through them
	•	No compression heuristics may override them

6.5 Escalation Behavior

When too many locked items cause free time exhaustion:
	•	Scheduler escalates urgency but stays within constraints
	•	It may compress only unlocked, AI-suggested blocks
	•	It must never compress locked ones
	•	It must flag conflict situations in:
	•	Logs
	•	Possibly Liquid Glass banner for user visibility

⸻

7. Persistence Rules

7.1 Transaction Integrity

All lock/unlock operations must be:
	•	Atomic
	•	Thread-safe
	•	Wrapped in a dataStore transactional commit

7.2 State Restoration

Upon app relaunch:
	•	Locked items load before scheduler re-runs
	•	Scheduler respects locked state immediately
	•	No animations or transitions should override locked placements

7.3 Sync Behavior

If cloud sync is implemented later:
	•	Locked state must be merged deterministically
	•	Last-writer-wins is acceptable
	•	Lock conflicts must not move data
	•	Lock state must never be auto-resolved by scheduler

⸻

8. Automated Testing (Full Enterprise Suite)

8.1 Unit Tests
	•	Lock state toggling
	•	Serialization + decoding
	•	Migration from non-locking versions
	•	Locked event conflict detection
	•	Rescheduling around locked items

8.2 Integration Tests

Simulate:
	•	A locked event at 10–11 AM
	•	Scheduler attempts to place a block
	•	Expected outcome:
	•	New block placed before or after
	•	Locked event untouched

8.3 UI Tests
	•	Lock icon presence
	•	Lock toggle functional
	•	Dragging disabled
	•	Context sheets reflect correct state

8.4 Regression Matrix
	•	Calendar UI
	•	Task UI
	•	Scheduler engine
	•	Synchronization layer
	•	Persistence
	•	Settings view

Each must pass tests proving “locked means locked.”

⸻

9. Risk Analysis

9.1 Risk: Missing locked flag in certain flows
	•	Fix: All creation/edit flows must include locked parameter.

9.2 Risk: Scheduler ignoring locked items in a complex free-time calculation
	•	Fix: Dedicated locked-item test suite.

9.3 Risk: UI desynchronizing from backend
	•	Fix: Use @Published and main-thread publishing (TICKET-058).

9.4 Risk: Conflicts with Motion-style auto-placement
	•	Fix: Hard rule: locked dominates all AI logic.

⸻

10. Done Definition (Strict)

TICKET-002 is complete when:
	•	locked property exists on all schedulable types
	•	UI can toggle lock state
	•	Locked items visually differ from unlocked
	•	All auto-scheduling respects locked constraints
	•	Tests prove:
	•	Locked items cannot move
	•	Locked items survive app relaunch
	•	Locked items survive scheduler re-runs
	•	No drag/sizing possible for locked items
	•	Scheduler logs conflict attempts correctly

⸻
