# Planner Improvements

## Planner slot collision & overflow handling
- The planner currently allows multiple tasks to stack into the same time slot (e.g., 10:00–10:30), with no notion of collisions or overflow. This reduces trust in the schedule when the day contains many tasks.
- Goals
  - Introduce basic collision handling and overflow representation: only one task per 30-minute slot (for v1).
  - Tasks that cannot be placed in today’s working hours should be marked as unschedulable/overflow.
- Tasks
  - Add estimatedMinutes to PlannerTask (or derive from category/difficulty as fallback).
  - Compute slotsNeeded = max(1, ceil(estimatedMinutes / 30)).
  - Implement a packing pass: iterate tasks sorted by schedule_index; for each task, search for slotsNeeded contiguous free slots. If found, assign task to those slots. If not, mark task as unscheduledToday.
  - Update UI: visually differentiate scheduled tasks vs overflow/unscheduled tasks for that day.
  - Add logging/metrics: number of overflow tasks per day; average utilization of slots.

## Overdue task boost
- Overdue tasks are currently treated identically to tasks due today (due_factor=1), with no explicit boost for being late. This can make overdue items compete evenly with “due today but still on time” tasks.
- Goals
  - Introduce a small but explicit boost for overdue tasks so they consistently rank above non-overdue tasks of comparable priority and category.
- Tasks
  - Add an overdueBoost constant in planner weights (e.g., 0.05–0.15).
  - For tasks where today > due_date: set an isOverdue flag and compute schedule_index = clamp(base_urgency + overdueBoost, 0, 1).
  - Add visual indication in UI for overdue tasks (e.g., subtle badge).
  - Add tests: overdue low-priority vs non-overdue low-priority; overdue medium vs non-overdue high to check relative behavior.

## Externalize planner weights into config
- Horizon days, weights for priority/due/category, and energy weight are currently hard-coded. This makes tuning behavior difficult and brittle.
- Goals
  - Move planner constants into a centralized configuration object that can later be surfaced to user settings.
- Tasks
  - Define PlannerWeights struct with: horizonDays, priorityWeight, dueWeight, categoryWeight, energyWeight, overdueBoost.
  - Replace literals in planning logic with PlannerWeights fields.
  - Store default PlannerWeights in a shared, testable location.
  - Add debug view/flag to print current weights and per-task computed scores.
