# Roots

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

## Getting Started (Local Development)

### Requirements

- macOS (recent version; same as current Xcode support target)
- Xcode (latest stable; Swift and SwiftUI toolchain)
- Git

### Clone and Open

```bash
git clone git@github.com:cleveland-lewis/Roots.git
cd Roots
open TreyDashboard.xcodeproj    # or the main .xcodeproj/.xcworkspace for the app
```

Then:
	1.	Select the Roots (or equivalent) scheme in Xcode.
	2.	Choose a target (Mac app).
	3.	Build & run (⌘R).

If you use Swift Package Manager dependencies, Xcode will resolve them on first open.

⸻

Running Tests

Once test targets are added and wired:

cd Roots
xcodebuild \
  -project TreyDashboard.xcodeproj \
  -scheme Roots \
  -destination 'platform=macOS' \
  test

This same command (or a similar one) is used in CI workflows to run the test suite on each push / PR.

⸻

Security

Security for this project is handled with:
	•	GitHub CodeQL code scanning for Swift.
	•	Dependency review on pull requests.
	•	Dependabot for updating:
	•	GitHub Actions
	•	Swift dependencies

See SECURITY.md￼ for how to report vulnerabilities.

⸻

Contributing

This repository is primarily open for:
	•	Issue reporting
	•	Suggestions
	•	Code review of specific changes

The core app is intended to be a paid product (e.g., via the Mac App Store), so contributions may be selectively merged. If you open a PR:
	1.	Keep changes small and focused.
	2.	Do not introduce additional third-party dependencies without discussion.
	3. 	Ensure all tests pass and CI workflows are green.

⸻

License

This project is licensed under the Business Source License (BUSL-1.1).
	•	Source code is available for review, learning, and internal use under BUSL terms.
	•	Commercial redistribution or competing SaaS/hosted services are restricted as per the license.
	•	See LICENSE￼ for full details.

If you are unsure whether your intended use is permitted under BUSL-1.1, consult a legal professional.

---
