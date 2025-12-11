// Documented Interfaces, Assumptions, and Limitations

// Main Interfaces

// User Interfaces
// - DashboardView: Central screen for active stats, schedule, and quick actions.
// - CoursesView: Course management, file/module upload, and course detail.
// - AssignmentsView: Assignment tracking and details (not shown above, but referenced in design).
// - CalendarView: Integrated calendar with event creation, filtering, and AI suggestions.
// - StudyCoachView/EveView: Energy-aware study coach and AI chat interface.
// - SettingsView: Configuration for scheduling, integrations, privacy, and UI.
// - PopupManager: Unified system popup and modal handler for context-edit flows.

// Data and Service Interfaces
// - AppDataStore: In-memory actor-backed repository for courses, assignments, events, etc.
// - SyllabusParser: Extracts structured info from course syllabi (PDF, DOCX, text).
// - CourseMapService: Builds per-course study maps from parsed data.
// - DeviceCalendarManager: Syncs with local device calendar/reminders.
// - FileStorageManager: Handles file imports and links them to courses/tasks.
// - Eve (AI) API Client: Handles chat and AI scheduling with local or remote model endpoints.

// Key Assumptions
// - Platform: macOS; requires SwiftUI, PDFKit, and AppKit (for some file types).
// - Local-First: All user data and analytics are stored locally by default; cloud features are opt-in only.
// - User Role: Primary user is a student (possibly neurodivergent or student-athlete) managing academic workload with minimal friction.
// - Data Model: Courses, assignments, tasks, study sessions, and modules are the primary entities.
// - AI Integration: AI-powered flows are clearly labeled; sending data to remote models is opt-in and privacy-warned (see Settings and Objectives/Ethics docs).
// - Testing: App relies on a mock data store and CI smoke tests for validation; new features should be validated with unit/UI tests.

// Known Limitations
// - Platform: macOS only; not tested or supported on iOS/iPadOS at this time.
// - Cloud Integration: No out-of-the-box cloud sync (files, settings, or data); all cloud features require explicit user activation.
// - External AI: Data sent to external AI models leaves the device and may be processed by third parties. Warning is provided in-app; users should avoid sending confidential materials.
// - Accessibility: Most screens use Apple’s accessibility APIs, but further user testing is needed for neurodivergent-specific needs.
// - Syllabus Parsing: SyllabusParser works best on clear, structured syllabi. Handwritten or image PDFs, and unusual grading formats, may be incompletely parsed.
// - Time Tracking: Study session analytics require manual start/stop; automatic time inference is not yet implemented.
// - Security: App does not currently encrypt local data at rest. Users should ensure their device is secured if handling sensitive data.
// - Error Handling: Some flows (file upload, AI API calls) may surface technical errors in logs or in-app warnings, but comprehensive recovery/UX for every edge case is still in progress.

// ---
// For more, see the full compliance rules in `Rules.md`, and the project's objectives and ethics in `ObjectivesAndEthics.md`.
