# 🎓 Roots School Dashboard  
*A fully Apple-native academic and cognitive management suite optimized for ADHD/ASD learning profiles.*

Roots is a SwiftUI macOS/iPadOS application designed for cognitively lightweight, friction-free school organization. It unifies your calendar, assignments, courses, analytics, and study timers into one adaptive system that reduces overwhelm and strengthens executive functioning. Every component follows Apple’s Human Interface Guidelines, using system materials, SF Symbols, dynamic type, and responsive layout behavior.

---

## 🌱 Overview

Roots acts as your academic command center:

- **Courses** — Meetings, assignments, exams, syllabus elements, and quick actions.  
- **Assignments** — Category-based planning, time estimation, notes, and status tracking.  
- **Calendar** — Apple-native month calendar with sidebar events, metrics, and event detail popovers.  
- **Timer** — Pomodoro/Timer/Stopwatch with analytics and stacked bar charts for studying.  
- **Planner** — Scheduling engine (in development) for auto-generated study blocks.  
- **Settings** — True macOS window with editable profiles, semesters, and interface controls.

Roots is built for clarity, stability, and neurodivergent-friendly workflows.

---

# 🚀 Quick Start (Development)

### 1. Clone and open in Xcode
```bash
git clone <your-repo-url>
open Roots.xcodeproj

2. Build & run

No external dependencies required — the entire system uses SwiftUI, Combine, and Foundation.

⸻

📚 Courses
	•	Clean list of active courses
	•	Detail pane with:
	•	Meetings
	•	Assignments & exams
	•	Syllabus metadata
	•	Quick Actions: Add Assignment, Add Exam, Add Grade, View Plan
	•	Course editor popup:
	•	Course code, title, instructor, location
	•	Semester picker
	•	Color selector with ring indicator
	•	Global controls in Settings:
	•	Delete courses
	•	Archive courses
	•	Manage semesters

⸻

📝 Assignments
	•	Spreadsheet-style assignment dashboard
	•	New Assignment popup includes:
	•	Title
	•	Course dropdown (linked to active semester)
	•	Category dropdown (Homework, Reading, Quiz, Exam/Test, Project, Review)
	•	Estimated time
	•	Due date
	•	Urgency
	•	Notes
	•	All popups use RootsPopupContainer for consistent cards, materials, and corner radius
	•	Planner/Omodoro replaced with two equal action buttons:
Planner and Timer

⸻

🗓 Calendar (Apple-Native)

A full native calendar experience:
	•	Built with NavigationSplitView
	•	Stable sidebar listing events for the selected date
	•	Month grid with:
	•	Tappable day cells
	•	Event density bars
	•	Smooth selection animations
	•	Metrics row above the calendar:
	•	Average items per day
	•	Total items this month
	•	Busiest day
	•	EventDetailView popover with:
	•	Title
	•	Date & time
	•	Location
	•	Notes
	•	“View Device’s Calendar” button launches macOS Calendar.app

All interactions avoid layout shifting and window resizing.

⸻

⏱ Timer System
	•	Pomodoro, Timer, and Stopwatch modes
	•	Activity selection
	•	“Current Activity” card with inline editing
	•	Analytics panel with:
	•	Today’s total study time
	•	Today by category (stacked bar chart)
	•	This week by category (stacked bar chart)
	•	Each chart supports expand mode via a corner chevron

⸻

📊 Analytics & Metrics
	•	Event-density for calendar days
	•	Timer usage (stacked study-time charts)
	•	Assignment load distribution
	•	Category-linked effort estimation
	•	Weekly performance insights

Built with Swift Charts and semantic color helpers.

⸻

⚙️ Settings (macOS-native Window)
	•	Dedicated resizable window with titlebar, toolbar, close/min/max buttons
	•	Navigation sidebar (General, Courses, Semesters, Interface, Profiles)
	•	Breadcrumb-style path (General > Interface)
	•	Left-aligned global text fields
	•	Minimum window sizes enforced to prevent collapsing/wrapping
	•	Edit or archive courses and semesters directly inside Settings

⸻

🏛 Architecture

Core Components
	•	RootsCard — Standard cards
	•	RootsPopupContainer — Unified popup styling
	•	RootsIconButton — Circular accent buttons
	•	RootsFormRow — Consistent alignment for settings/forms
	•	MetricCard / MetricsRow — Reusable analytics UI
	•	MonthCalendarView — Tappable Apple-style month grid
	•	SidebarView — Event list for selected date
	•	EventDetailView — Popover/sheet
	•	CalendarMetrics — Compute avg items, totals, busiest day

State & Models

All models use:
	•	UUID identifiers
	•	Identifiable, Codable, ObservableObject
	•	Migration-safe UUID modeling
	•	Persistence via JSON stores with debounce protection

Helpers
	•	DateTimeHelpers
	•	EventDensityHelper
	•	WindowSizeHelper
	•	ModelMigration

⸻

🔒 Privacy

All computation is local:
	•	No external API calls
	•	No analytics or telemetry
	•	All student data stored on-device only

⸻

🧪 Project Structure

Roots/
│
├── Models/
├── Views/
│   ├── Calendar/
│   ├── Courses/
│   ├── Assignments/
│   ├── Timer/
│   ├── Settings/
│
├── Components/
│   ├── Cards/
│   ├── Popups/
│   ├── Buttons/
│   ├── Metrics/
│
├── Helpers/
├── Persistence/
├── Resources/
└── README.md


⸻

🧭 Roadmap
	•	Complete UUID migration across all models
	•	Add Planning Profiles to Settings
	•	Full Planner engine: auto-scheduling SuggestedBlocks
	•	Improved semester tools
	•	Optional local AI study support (summaries, workload predictions)

⸻

🐞 Troubleshooting

Settings window resizes unexpectedly
→ Ensure minimum frames via WindowSizeHelper.

Calendar shifts when selecting a date
→ Confirm the calendar grid uses stable frames and no GeometryReader that affects layout.

Popup corners look mismatched
→ Wrap all popups in RootsPopupContainer.

Courses not appearing in assignment dropdown
→ Verify active semester → courses filtering in Settings.

⸻

🎯 Philosophy

Roots is built around clarity, predictability, and reduced cognitive strain.
Everything is designed to:
	•	minimize overwhelm
	•	support executive functioning
	•	maintain visual and spatial stability
	•	reduce micro-decisions
	•	provide consistent structure

This is a dashboard designed to help you think less, do more, and stay grounded.

⸻
