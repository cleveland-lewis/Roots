# Roots

> ⚠️ **SOURCE-VISIBLE FOR INSPECTION ONLY**  
> This repository is **NOT open source**. The code is made available for security auditing, 
> educational review, and inspection purposes only. You may NOT copy, modify, fork, redistribute, 
> reimplement, or use this code in any capacity. All rights reserved. See [LICENSE](LICENSE) for details.

---

Roots is a macOS-native study planner and academic dashboard built with SwiftUI.  
It centralizes courses, assignments, exams, and an automatic scheduler into a single Apple-native interface.
Any LLM usage is limited or allowed by the user and is built to work offline with local LLMs; however, users can utilize their API Keys.

The app is designed for:

- Students who want a serious planner that actually respects time, energy, and due dates.
- Heavy course loads with overlapping exams, quizzes, homeworks, readings, and projects.
- Neurodivergent students who need to be "told" what to do, as if it's coming from a coach or instructor.
---

## Core Features

### Assignment & Course Management

- Course-centric assignment model (Exam, Quiz, Project, Homework, Reading).
- Rich assignment metadata:
  - Priority/importance
  - Difficulty/energy requirement
  - Estimated duration
  - Due date and time
  - Category and course linkage
- Quick actions for:
  - Adding assignments and grades
  - Jumping to planner filters and relevant views

### Planner & Scheduler

- 09:00–21:00 day timeline in 30-minute blocks.
- End-to-end flow:
  - Assignments → study/work sessions → scheduled timeline.
- Study/work session generation:
  - Exams/Quizzes → multiple spaced “Study Sessions”.
  - Homework/Reading → 1–N chunks based on duration.
  - Projects → user-defined or auto-split “Work Sessions”.
- Multi-day scheduling:
  - Sessions scheduled across days up to the due date.
  - Priority-aware ordering using:
    - `schedule_index = 0.5 * priority_factor + 0.4 * due_factor + 0.1 * category_factor`
  - Energy-aware placement:
    - `placement_score = 0.8 * schedule_index + 0.2 * energy_match`
- Overflow handling:
  - Sessions that cannot fit before their due date are pushed into an Overflow queue.

### Dashboard & Views

- Dashboard cards for:
  - Active tasks and schedule overview.
  - GPA / grade summary (once wired to grade components).
  - Quick actions.
- Calendar / planner views:
  - Day timeline with sessions rendered as blocks.
  - Per-course filtering hooks via `plannerCoordinator.selectedCourseFilter`.
- Grades:
  - Local grade overrides (to be migrated to persistent storage).

---

## Architecture Overview

Roots is structured as a SwiftUI app with shared observable stores and coordinator-style view models.

Key pieces (high-level):

- **Stores**
  - `CoursesStore`: courses, course-level metadata, deletion publisher.
  - `AssignmentsStore`: assignments (Exam, Quiz, Project, Homework, Reading) and their state.
  - `PlannerStore` / scheduler-related types:
    - Planner tasks/sessions
    - Overflow queue for unscheduled sessions

- **Scheduler / Planner**
  - Uses a central planning engine:
    - Expands assignments into sessions based on category-specific rules.
    - Computes `schedule_index` per session.
    - Packs sessions across days into 30-minute slots.
    - Uses a user energy profile to influence placement.

- **Views**
  - `DashboardPageView`
  - `AssignmentsPageView`
  - `PlannerPageView` / calendar views
  - Course/assignment detail popups and quick-action sheets

- **Design System**
  - Shared typography, colors, and “glass” card styling to keep everything Apple-native and consistent.

---

## Viewing the Code

This repository is available for inspection only. You may browse the source code 
for security review, educational purposes, or to understand the implementation.

**You may NOT:**
- Clone, fork, or download this repository for any purpose other than temporary inspection
- Build, compile, or run the software
- Modify, adapt, or create derivative works
- Use any portion of this code in other projects
- Reimplement features or algorithms observed in this codebase

The software is distributed as a paid product. This source visibility does not 
grant you permission to use, modify, or redistribute the code.



---

## Security

If you discover a security vulnerability through code inspection, please report it 
responsibly. See [SECURITY.md](SECURITY.md) for reporting procedures.

---

## License

This software is licensed under a **Proprietary Source-Available License**.

**Key Terms:**
- ✅ **Permitted:** Viewing source code for inspection, security review, or educational purposes
- ❌ **Prohibited:** Copying, modification, forking, redistribution, reuse, reimplementation, or any commercial or non-commercial use

**This is NOT open source software.** The code is visible for transparency and security 
auditing only. No permission is granted to use, modify, or distribute this software 
in any form.

See [LICENSE](LICENSE) for complete terms.

For licensing inquiries or commercial use requests, contact Cleveland Lewis.

---
