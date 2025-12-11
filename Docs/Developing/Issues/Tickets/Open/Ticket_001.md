# TICKET-001 — Project organization & run targets (Critical)

## Category: Project layout and run target cleanup
 
### Goal: One canonical “Roots” app target with a clean, predictable source layout and no duplicate files, so that Xcode opens → build → run is trivial and deterministic.

⸻

1. Current Problem & Context

You currently have:
	•	Multiple source roots, e.g.:
	•	Roots/Source/Main/
	•	Roots/Source/Main/swift-new/
	•	Possibly extra folders under Roots/ or Swift/ created while iterating.
	•	Multiple targets/schemes and/or stale ones:
	•	Old experiments, test harnesses, possibly a web or CLI target.
	•	Duplicate files/types:
	•	The same view/model exists in Source/Main and Source/Main/swift-new or other folders.
	•	Xcode sometimes includes both, causing:
	•	“Invalid redeclaration” compiler errors, or
	•	The wrong version of a file is being used at runtime.

This ticket’s job is to normalise the project to a predictable, Apple-native structure:
	•	Single main app target: Roots
	•	Single module/code root: Roots/Sources/Roots
	•	All platform-specific entry points and configurations are clearly separated.
	•	Only one copy of each type is compiled.

⸻

2. Success Criteria (Acceptance Criteria Expanded)

You already have:

	•	Xcode workspace opens, and one “Roots” target builds and runs the app without manual file repositioning.
	•	No duplicate source files with conflicting definitions remain in the build path.

Expanded into concrete checks:
	1.	Workspace & Target Simplicity
	•	Opening Roots. xcworkspace or Roots.xcodeproj shows:
	•	Exactly one primary app target named Roots for the platform you’re focused on now (e.g., macOS, or macOS + iOS if you’re ready for multiplatform).
	•	The default scheme Roots:
	•	Builds without any target selection gymnastics.
	•	Runs the app directly from Product → Run or ⌘R.
	2.	Canonical Source Layout
	•	All Swift sources for the main app live under:
	•	Roots/Sources/Roots/…
	•	Platform-specific subfolders (optional but recommended), e.g.:
	•	Roots/Sources/Roots/App/
	•	Roots/Sources/Roots/Features/Dashboard/
	•	Roots/Sources/Roots/Features/Calendar/
	•	Roots/Sources/Roots/Shared/Models/
	•	Roots/Sources/Roots/Shared/Services/
	•	No code is compiled from Source/Main or Source/Main/swift-new anymore — those become either:
	•	Deleted, or
	•	Marked as archive/ or legacy/ and excluded from all targets.
	3.	No Duplicate Definitions
	•	Cmd+Shift+F for a representative type name (e.g., RootApp, DashboardView, AIScheduler) returns exactly one active definition that is part of the main target.
	•	Build with -Xfrontend -warn-long-function-bodies=… / static analysis shows no duplicate type names in the same module.
	•	You can search for a class or a struct of key types and verify that the canonical one lives under Sources/Roots.
	4.	Build Settings & File Membership
	•	In Xcode’s File Inspector, no source file outside Sources/Roots is ticked for the Roots target (except maybe test targets).
	•	Any test targets use clearly separated file membership under Tests/RootsTests, etc.
	5.	Clean Incremental Build
	•	Deleting DerivedData and rebuilding from scratch succeeds without:
	•	File not found errors.
	•	Module ambiguity.
	•	Linking errors due to stale references.

⸻

3. Non-Goals

This ticket does not:
	•	Change the functional behavior of the app.
	•	Redesign UI/UX.
	•	Switch persistence technology (e.g., JSON → Core Data).
	•	Implement any new features or business logic.

If, during cleanup, you find logic you want to rewrite, that goes into separate tickets.

⸻

4. Target Final Directory & Module Layout

Recommended final structure:

Roots/
  Roots.xcodeproj
  Roots.xcworkspace (optional)
  Sources/
    Roots/
      App/
        RootsApp.swift
        AppDelegate.swift (if needed)
        SceneDelegate.swift (iOS)
        RootView.swift
      Features/
        Dashboard/
          DashboardView.swift
          DashboardViewModel.swift
        Calendar/
          CalendarView.swift
          CalendarViewModel.swift
        Assignments/
          AssignmentsView.swift
          AssignmentsViewModel.swift
        Settings/
          SettingsView.swift
          SettingsViewModel.swift
      Shared/
        DesignSystem/
          Colors.swift
          Typography.swift
          Components/
        Scheduler/
          AIScheduler.swift
          SchedulerModels.swift
          SchedulerEngine.swift
        Models/
          Course.swift
          Assignment.swift
          CalendarEvent.swift
          TodoTask.swift
        Services/
          AppDataStore.swift
          SchoolCalendarManager.swift
          ThemeManager.swift
          PermissionsService.swift
        Utils/
          Logging.swift
          DateUtils.swift
          ResultExtensions.swift
  Tests/
    RootsTests/
      SchedulerTests.swift
      CalendarIntegrationTests.swift
  archive/
    legacy/
      Source/
        Main/
        Main/swift-new/

Key rule: only Sources/Roots/** is part of the Roots target.

⸻

5. Detailed Implementation Plan

Step 1 — Snapshot & Branch
	1.	Create a Git branch for safety:

git checkout -b feature/project-layout-cleanup


	2.	Commit current state:

git add.
Git commit -m "chore: snapshot project before layout cleanup."



Step 2 — Inventory Existing Targets & Schemes
	1.	Open Xcode → Project Navigator → Roots:
	•	Go to Project→ Targets.
	2.	List current targets:
	•	Example possibilities:
	•	Roots
	•	Roots-macOS
	•	Roots-iOS
	•	WebApp
	•	DemoApp
	3.	Decide:
	•	Primary app target name: Roots
	•	Optional:
	•	RootsTests
	•	RootsUITests
	4.	Remove or disable obsolete targets:
	•	For any experiment target:
	•	Document in commit message.
	•	Option 1: Remove target entirely (recommended).
	•	Option 2: Keep but uncheck all source files (not recommended long-term).

Goal: one main app target you care about right now.

Step 3 — Identify Source Roots & Duplicates

You currently have at least:
	•	Roots/Source/Main/
	•	Roots/Source/Main/swift-new/

Do this:
	1.	In Xcode Project Navigator:
	•	Right-click Source folders → “Show in Finder” and verify actual on-disk paths.
	2.	In Finder or CLI:

find Roots -maxdepth 4 -type d \( -name "Source" -o -name "Sources" -o -name "swift-new" \)


	3.	Build a quick mapping:
	•	Source/Main → older, legacy code?
	•	Source/Main/swift-new → more recent, better-structured SwiftUI app?
	4.	Decide canonical code base:
	•	Almost certainly the swift-new variant is the one to keep.
	•	Mark the other as legacy unless it contains pieces you need.

Step 4 — Create the Canonical Sources/Roots Module
	1.	In Finder:

mkdir -p Roots/Sources/Roots


	2.	In Xcode:
	•	Right-click on the project root → Add Files to "Roots"...
	•	Select Sources folder.
	•	Make sure:
	•	“Create folder references” is unchecked.
	•	“Add to targets” has Roots checked.
	3.	Under Sources/Roots, create subfolders:
	•	App, Features, Shared, etc. (as above).

Step 5 — Move Code from swift-new into Sources/Roots
	1.	In Xcode, under Source/Main/swift-new:
	•	For each file:
	•	Drag it into the appropriate Sources/Roots/... folder.
	•	e.g. ContentView.swift → Sources/Roots/App/RootsApp.swift or RootView.swift
	•	DashboardView.swift → Sources/Roots/Features/Dashboard/
	2.	Ensure that:
	•	“Copy items if needed” is unchecked (you’re moving, not duplicating, if done within project).
	•	File membership for target Roots is checked.
	3.	Keep types consistent:
	•	If you rename ContentView to RootView, do it deliberately and update references in:
	•	RootsApp / @main struct.
	•	Any previews.
	4.	Commit after a meaningful chunk:

git add .
git commit -m "refactor: move swift-new sources into Sources/Roots"



Step 6 — Remove Old Source/Main and Exclude From Target
	1.	Once everything you care about is in Sources/Roots:
	•	In Xcode, find the old Source/Main groups in the navigator.
	•	For each file:
	•	Verify that Target Membership for Roots is unchecked.
	•	Then remove those groups:
	•	Right-click → “Delete” → “Remove References” (do not delete from disk yet if you’re paranoid).
	2.	On disk:
	•	Move old sources to archive/legacy:

mkdir -p archive/legacy
git mv Source archive/legacy/Source


	•	Or just git rm them once you are certain.

	3.	Clean build:

rm -rf ~/Library/Developer/Xcode/DerivedData/*

Then re-open Xcode and build.

Expected: only Sources/Roots is part of the app.

Step 7 — Fix Entry Points & Run Target
	1.	Ensure there is exactly one @main app entry:

@main
struct RootsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}


	2.	Ensure there are no leftover @main declarations:
	•	Search @main in project.
	•	Only RootsApp should exist (unless you have platform-specific @main which must be gated by #if os(...) and separate targets).
	3.	Run:
	•	Choose Roots scheme.
	•	Hit ⌘R.
	•	App runs with the new sources.

If multiple schemes exist:
- Set Roots as default in Scheme dialog.

⸻

1. Build Settings & Module Sanity
	1. In project settings → Build Settings:
    	1. SWIFT_ACTIVE_COMPILATION_CONDITIONS should be minimal (e.g. DEBUG only).
    	2. Remove stale flags like SWIFT_NEW or LEGACY_APP unless actively used.
	2. In Build Phases:
    	1. “Compile Sources” phase for Roots should list only files under Sources/Roots.
	3. Check for duplicate symbols:
    	1. Build.
    	2. If you see errors like “Invalid redeclaration of X”:
    	3. Use the error navigator to jump to source.
    	4. Remove/rename duplicates or ensure only one copy has target membership.

⸻

7. Testing & Verification Plan

7.1 Structural Tests (Manual)
	•	Test 1 — Simple clone & build
	•	Clone repo on a new machine / clean directory.
	•	open Roots/Roots.xcodeproj.
	•	Select Roots scheme → build & run.
	•	Pass if app appears with Dashboard and no build issues.
	•	Test 2 — Search duplicates
	•	Use Cmd+Shift+F for key types (AIScheduler, CalendarEvent, ThemeManager).
	•	Only a single definition per type in the compiled module.

7.2 Xcode Warnings
	•	Enable:
	•	“Treat warnings as errors” during cleanup.
	•	-Wall and strict Swift warnings if feasible.
	•	Fix all:
	•	“Redundant conformance”
	•	“Type redefined”
	•	“Ambiguous use of…”

7.3 Optional: Scripted Check

You can add a simple script to CI (later ticket, but design here):

#!/usr/bin/env bash
set -euo pipefail

# Ensure no active Swift files live under legacy paths
if find. -path "*Source/Main*" -name "*.swift" | grep -q .; then
  echo "Error: Swift files still present in legacy Source/Main paths."
  exit 1
fi

xcodebuild \
  -scheme Roots \
  -sdk macosx \
  -destination 'platform=macOS,arch=x86_64' \
  clean build


⸻

8. Migration & Risk Management

Risks
	1.	Accidentally deleting code you still need
	•	Mitigation: move to archive/ first, don’t permanently delete until stable.
	2.	Breaking relative paths / resources
	•	Some code might refer to bundle paths or file URLs that assumed old layout.
	•	Mitigation: search for Bundle.main.path(forResource: and custom file loading.
	3.	Scheme / target confusion
	•	Old targets might still exist but have weird settings.
	•	Mitigation: either delete them or clearly rename them to Legacy-*.

Rollout Strategy
	1.	Merge TICKET-001 only when:
	•	Project builds cleanly.
	•	You’ve run through a minimal smoke test:
	•	Dashboard shows.
	•	Calendar page opens.
	•	Settings page opens.
	2.	After merge:
	•	All future tickets must assume:
	•	Only Sources/Roots is allowed for app source.
	•	Any new feature must be placed there using the feature folder structure.

⸻

9. Done Definition (Strict)

TICKET-001 is only done when:
	•	Sources/Roots is the sole source root for the app.
	•	Source/Main and Source/Main/swift-new are removed or quarantined under archive/ and excluded from all targets.
	•	Only one app target is used for development (Roots).
	•	Clean build from scratch succeeds immediately without any path or module errors.
	•	A fresh checkout builds and runs using the default scheme without manual target or file jiggling.
	•	You can list all compiled Swift files for Roots and they all live under Sources/Roots.

⸻
