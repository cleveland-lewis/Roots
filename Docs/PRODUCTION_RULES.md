# Production Rules for Roots

Non-negotiables before anything ships:

1. `main` always builds with **zero compiler warnings**.
2. All test targets pass (unit, integration, UI smoke).
3. No TODO/FIXME in release-critical areas (Dashboard, Courses, Assignments, Planner, Grades).
4. No placeholder UI in Dashboard metrics, Calendar/Planner events, or Grades views.
5. Any bug fix must add or update at least one test that would fail before the fix.
