# Roots Roadmap

roadmap.md — UI Revamp Phase (Dashboard + Liquid Glass Popups)

Phase 1 — Foundations & Core Architecture

Goal: Establish the core project foundations, data models, and minimal UI scaffolding to support progressive feature growth.

Tasks
1. Set up project skeleton and CI/CD pipelines.
2. Define global design system primitives:
   - Spacing scale
   - Corner radii
   - Typography tokens
   - Color palette
   - Materials model baseline
3. Create minimal dashboard shell:
   - Sidebar navigation
   - Content area container
4. Implement core data models:
   - Course, Assignment, Exam, Schedule, and Task entities
5. Establish basic persistence layer (DB schema) and simple CRUD
6. Build lightweight UI components:
   - Card primitives (DashboardCard, StatCard)
   - SectionHeader
7. Create a basic dashboard page with placeholder data to validate layout
8. Ensure app builds and runs on macOS with SwiftUI

Acceptance Criteria
1. Project builds without errors and runs on target macOS version.
2. Design system tokens defined and reusable across screens.
3. Dashboard shell renders correctly with consistent typography and spacing.
4. Core data models are in place with basic CRUD operations.

---

Phase 2 — Data Intelligence & Study Automation

Goal: Introduce structured syllabus handling and guided study capabilities to reduce decision fatigue and provide actionable plans.

Tasks
1. Implement Syllabus Parser & Course Map Builder (Feature A)
   - Ingest PDFs, DOCX, or text syllabi
   - Extract course metadata, grading, schedule, and assignments
   - Produce a Course Map view with week-by-week topics and linked readings
   - Auto-create assignments/exams from syllabus data
   - Integrate with Long-Range Academic Planner and Course Dashboard
   - UI: Add Course from Syllabus wizard and Course Map view
2. Implement Study Coach / “Tell Me What To Do” Mode (Feature B)
   - Capture energy level, time window, and state from Assignment Intelligence and Syllabus Map
   - Core logic to select course and task type, and generate a per-block micro-script
   - Zero-choice default flow with optional switch plan
   - Energy-aware task sizing and post-session logging
   - UI: Single button to start guided study; in-session progress; post-session review
3. Integrations
   - Connect Syllabus Parser results to Assignment Intelligence
   - Connect Study Coach with Schedule, Calendar, and Course Map
4. Accessibility & UX improvements
   - Reduced motion and high-contrast support
   - Clear error handling and quick-edit fixes in syllabus parsing

Acceptance Criteria
1. Syllabus data is parsed into a structured Course Map with usable assignments.
2. Study Coach produces a concrete, executable block plan and logs post-session data.
3. All integrations route data correctly between modules.
4. UI is responsive, accessible, and free of major UX blockers.

---

Phase 3 — macOS UI System Overhaul

Goal: Redesign the entire Dashboard UI layout and implement a unified popup interaction architecture using Liquid Glass.

Acceptance Criteria
1. The new UI layout is Apple-quality with consistent spacing, grid logic, card shapes, and hierarchical structure.
2. A unified popup system using Liquid Glass is implemented and reusable across cards.

3.1 — Dashboard Layout Rebuild (SwiftUI)

Goal: Completely restructure the main dashboard to match Apple-quality UI design: consistent spacing, grid logic, card shapes, and hierarchical structure.

Tasks
1. Implement global layout system (Layout namespace: spacing, padding, corner radius).
2. Convert dashboard to a fully responsive two-column layout.
3. Add card grid:
   - Stats row (Active Courses, Due This Week, Completed)
   - Quick Actions panel
   - Today’s Schedule panel
   - Upcoming Assignments list
   - To-Do list
   - Assignment Detail (full-width)
4. Create reusable card components:
   - DashboardCard
   - StatCard
   - QuickActionRow
   - SectionHeader
   - UpcomingAssignmentRow
   - TodoRow
   - AssignmentDetailRow
5. Build DashboardContent container (handles layout, spacing, scroll).
6. Build DashboardScreen root view (sidebar + content area).
7. Ensure all typography, spacing, colors, and corner radii match a unified system.

Acceptance Criteria
1. Layout visually matches the mock screenshot.
2. Card spacing and geometry are consistent across the entire dashboard.
3. Reusable UI components are implemented cleanly.
4. The code compiles fully in SwiftUI with no placeholders.

3.2 — Liquid Glass Popup Architecture

Goal: Introduce a fully unified, reusable popup system using Apple’s new Liquid Glass material.

Reference: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass/

Tasks
1. Build the global popup controller:
   - PopupManager (@Published activePopup)
   - present(), dismiss()
2. Define the new popup types:
   - .assignment, .course, .task, .calendarEvent, .trainingSession, .systemInfo, .energySelect
3. Implement the Liquid Glass background:
   - LiquidGlassBackground
   - Rounded corners + soft highlights + stroke overlay
4. Create the reusable popup container:
   - Dimmed background
   - Disabled interaction behind popup
   - Smooth spring entrance/exit animation
   - Gestures to dismiss
5. Create content views for:
   - Assignment details
   - Course overview
   - Calendar event details
   - Task details
   - Training session
   - System info
   - Energy level picker
6. Implement the global .treyPopups() view modifier.
7. Integrate popup triggers into all dashboard cards.

Acceptance Criteria
1. Tapping any dashboard card activates the correct popup.
2. Popup appears above wallpaper, grain background, cards, and UI chrome.
3. Popup uses true Liquid Glass rendering.
4. Animations feel native to macOS.
5. Code compiles without modification.

3.3 — Integration Requirements

- Ensure the dashboard and popup systems share the same:
  - spacing scale
  - corner radius
  - typography
  - color palette
  - materials system
- Ensure popup events route cleanly from content views to popup manager.
- Make popups accessible (reduced motion, high contrast).

3.4 — Deliverables

- Fully compiling SwiftUI code for all dashboard components
- Fully compiling SwiftUI code for popup system
- New UI system merged into main app target
- Clean, documented, reusable architecture for future screens

---

Notes

- The roadmap now starts with Phase 1 as requested, and progresses through Phase 2 and Phase 3 in sequence.
- If you’d like, I can generate a corresponding tasks.md with actionable dev tasks or automatically create GitHub issues from these phases.
