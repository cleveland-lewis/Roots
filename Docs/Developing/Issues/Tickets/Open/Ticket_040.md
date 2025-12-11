# TICKET-040 — Motion-like Scheduling Behavior Specification
**Creation Date:** 2025-11-30  
**Status:** In Progress  
**Criticality:** 3  
**Effort:** XL  
**File Path:** /Users/clevelandlewis/PyCharm/Roots/Documents/Developing/Issues/Tickets/Open/Ticket_040.md

---

## Summary
This ticket defines and implements Motion-like auto-scheduling behavior within the Roots application.  
The goal is to ensure that all unlocked school tasks and app-owned school events are automatically scheduled into free time around fixed constraints while maintaining determinism, predictability, and safety. The scheduler must integrate cleanly with CalendarViewModel, SchoolCalendarManager, persistence layers, and UI components.

---

## Problem Statement
The application requires a fully deterministic, intelligent scheduling engine that can place school tasks and school events into the user's free time while respecting external calendar constraints. Without a complete Motion-like scheduling model, the scheduling engine will place tasks incorrectly or inconsistently, fail to prioritize based on urgency, and potentially override protected or locked events.  
A complete redesign and consolidation of the AIScheduler logic is required to ensure consistency across the app.

---

## Goals
- Implement deterministic Motion-style task/event scheduling for school items.
- Treat external calendar events and locked events as absolute constraints.
- Automatically place unlocked school tasks into free blocks during the user’s defined work hours.
- Support urgency scoring prioritized by due date, remaining minutes, priority flag, and overdue heuristics.
- Produce a log describing how and why each decision was made.
- Support re-running scheduling safely without disrupting fixed or locked events.
- Integrate the scheduler into CalendarViewModel and SchoolCalendarManager.
- Return suggestions in a structured format that can be rendered directly into the UI.
- Maintain strict explainability: every placement must have a documented reason.
- Ensure full testability with deterministic output for identical inputs.

---

## Non-Goals
- User interface styling for suggested blocks (covered under UI tickets).  
- Natural-language parsing or task generation.  
- Support for non-school tasks or personal life management tasks.  
- Adaptive learning or user-behavior modeling.  
- Multi-day optimization beyond the defined planning horizon.  

---

## Technical Requirements
- Hard constraints:
  - External calendar events (source `.calendar`) cannot be moved or removed.
  - Locked items (`locked == true`) cannot be rescheduled.
- Candidate classification:
  - School tasks = assignments or todos whose source is `.assignment` or `.todo` and whose calendarId belongs to SchoolCalendarManager.
- Eligibility rules:
  - Only unlocked tasks belonging to the app may be scheduled.
  - Items with invalid data (missing duration, invalid due dates) must be rejected gracefully.
- Slot generation:
  - Generate daily free-time slots by subtracting busy intervals from user work hours.
  - Exclude sub-minimum-duration time windows.
- Placement logic:
  - Place items in urgency order.
  - Do not split across days unless unavoidable.
  - Assign AI-suggested events as `CalendarEvent` with `id = nil`.
- Scheduler output:
  - Return `(suggestions: [CalendarEvent], log: [SchedulingLogEntry])`.
- Logging:
  - Every decision must record: item, chosen slot, reasoning, constraints involved.
- Determinism:
  - Same input → same output, no exceptions.

---

## Design Notes
- The scheduler is centralized in `AIScheduler.swift`.
- A tie-breaking hierarchy ensures deterministic ordering:
  - Urgency score (descending)
  - Due date (ascending)
  - Remaining minutes (descending)
  - CreatedAt (ascending)
- Truncation rules prevent spanning midnight.
- A safety guard prevents re-running from overwriting user-saved events.
- The scheduler uses a “hard-first” placement model: earliest valid slot wins.

---

## Implementation Plan
- Consolidate all scheduling logic into the unified `AIScheduler.swift` module.
- Implement a structured urgency scoring method that respects overdue and high-priority weights.
- Create a reusable free-slot generator that accepts:
  - fixed events  
  - user work hours  
  - planning horizon  
- Implement candidate ordering using the deterministic sort pipeline.
- Implement block placement:
  - Fit entire task into one contiguous block when possible.
  - If splitting is necessary, split only within the same day unless impossible.
- Build the reason log system (`SchedulingLogEntry`).
- Update CalendarViewModel to:
  - Call `AIScheduler.generateSchedule()`
  - Provide selected school calendars
  - Render suggestions
- Update persistence so AI-suggested events remain separate from user events.
- Ensure compatibility with Settings Persistence, Appearance mode, and Locking model.
- Prepare a migration path if existing saved data conflicts with the scheduler.

---

## Testing Requirements
- Unit tests validating:
  - Free-slot generation  
  - Urgency scoring consistency  
  - Deterministic sort order across identical inputs  
  - Behavior with overdue tasks  
  - Multi-day spanning logic  
- Integration tests validating:
  - Scheduler behavior when new events appear  
  - Correct handling of locked events  
  - Proper behavior when no free slots exist  
  - Safety when user deletes or overrides AI-suggested blocks  
- Edge cases:
  - Tasks longer than available day  
  - Midnight overlap  
  - All-day events  
  - Null/invalid fields  
  - Conflicting overlapping events  

---

## Security & Privacy Considerations
- No sensitive data is transmitted outside the device.
- Scheduler logs may not store personal event titles outside school-related tasks.
- All logging follows the privacy-minimization rules in Ticket-030.
- No event modifications occur unless explicitly allowed by the locking model.

---

## Dependencies
- Depends on:
  - TICKET-002 (Locking Model)  
  - TICKET-011 (Cross-engine/UI consistency)  
  - TICKET-045 (Settings Persistence)  
- Required by:
  - TICKET-047 (Tell Me What To Do Mode)  
  - TICKET-015 (Energy-Aware Scheduling)  
  - TICKET-017 (Logging & Changelog System)  

---

## Acceptance Criteria
The ticket is considered complete when:

- The scheduler deterministically places all eligible school tasks into valid free slots.
- Hard constraints are respected under all conditions.
- The scheduler returns both suggestions and detailed log entries.
- UI integration via CalendarViewModel correctly displays scheduled blocks.
- Unit tests cover all scheduling branches and edge cases.
- Integration tests confirm stable behavior under dynamic calendar changes.
- A changelog entry for the implementation is added both:
  - To this ticket  
  - To the global `Changelog.md`  

---

## Change Log

### 2025-11-30T16:31:18Z — AIScheduler Fixes
- Unified AIScheduler definitions into a single module in `Sources/Roots/Utilities/AIScheduler.swift`.
- Replaced the undefined `Source` type with `CalendarEvent.EventSource` and used `.assignment` / `.todo` appropriately.
- Corrected construction of AI-suggested `CalendarEvent` objects, including nil `id`, and proper population of `courseId`, `location`, `type`, `priority`, and locked flags.
- Removed invalid checks against nonexistent `Assignment.locked` property.
- Updated `CalendarViewModel` integration to use `(suggestions, log)` return values and selected school IDs.
- Result: Scheduler compiles and integrates; requires unit test expansion for validation.