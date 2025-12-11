TICKET-003 — Theme Toggles (Critical)

Title
	•	Fix theme toggle behavior (Light/Dark/Auto) and persistence

Goal
	•	Ensure theme toggles behave like a native Apple app: choosing Light, Dark, or Auto updates the UI immediately, persists reliably, and keeps all views in sync with ThemeManager and system appearance.

⸻

1. Problem Overview

Right now, you have some combination of:
	•	Light / Dark / Auto controls present in UI (e.g., segmented control or buttons)
	•	A ThemeManager (or equivalent) that:
	•	Tracks preference
	•	May not be consistently applied across all views
	•	Issues likely include:
	•	Toggling buttons that do not update the displayed theme immediately
	•	Some screens ignoring theme changes
	•	Theme preferences not persisting or restoring correctly after relaunch
	•	Auto mode not clearly separated from explicit Light/Dark choices

This ticket makes theme behavior:
	•	Deterministic
	•	Centralized
	•	Persistent
	•	Predictable across the whole app

⸻

2. Success Criteria (Expanded Acceptance Criteria)

You already defined:
	•	Tapping Light, Dark, or Auto updates ThemeManager state and UI immediately.
	•	Theme choice is persisted between launches.
	•	No UI components show incorrect colors after switching themes.

Expanded into concrete checks:
	•	When the user taps a theme option:
	•	ThemeManager.preference is updated on the main thread
	•	ThemeManager publishes a change and all SwiftUI views that depend on it recompute immediately
	•	When the app relaunches:
	•	Previously selected theme mode (Light/Dark/Auto) is loaded from persistence
	•	The root view hierarchy is created with the correct theme from the first frame (no flash)
	•	All major screens respect theme:
	•	Dashboard
	•	Calendar
	•	Assignments
	•	Settings
	•	Popups / sheets
	•	There is no permanent “stuck in Light mode” or “half-dark view” issue after toggling.

⸻

3. Conceptual Model

Define a single source of truth:
	•	ThemePreference (enum)
	•	ThemeManager (ObservableObject)
	•	ThemeManager decides:
	•	What the user preference is (Light, Dark, Auto)
	•	What the effective color scheme is (.light or .dark) at any time

Theme behavior must align with:
	•	TICKET-004 (Auto mode behavior / OS sync)
	•	TICKET-045 (Settings persistence)

This ticket focuses on:
	•	Correct toggling
	•	Display consistency
	•	Persistence of the preference

⸻

4. Data Model

4.1 Theme Preference Enum

enum ThemePreference: String, Codable {
    case light
    case dark
    case system   // “Auto” in UI
}

4.2 ThemeManager

final class ThemeManager: ObservableObject {
    @Published var preference: ThemePreference {
        didSet {
            persistPreference(preference)
            updateEffectiveColorScheme()
        }
    }

    @Published private(set) var effectiveColorScheme: ColorScheme

    init(storage: ThemeStorage = UserDefaultsThemeStorage()) {
        let storedPref = storage.loadPreference() ?? .system
        self.preference = storedPref
        self.effectiveColorScheme = ThemeManager.resolveColorScheme(for: storedPref)
        self.storage = storage
    }

    private let storage: ThemeStorage

    func setPreference(_ newPref: ThemePreference) {
        preference = newPref
    }

    private func persistPreference(_ pref: ThemePreference) {
        storage.savePreference(pref)
    }

    private func updateEffectiveColorScheme() {
        effectiveColorScheme = ThemeManager.resolveColorScheme(for: preference)
    }

    static func resolveColorScheme(for pref: ThemePreference) -> ColorScheme {
        switch pref {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            // For now: read from UIScreen / NSApp / traitCollection
            // Later: refined in TICKET-004
            return SystemAppearance.currentColorScheme()
        }
    }
}

4.3 Storage Abstraction

protocol ThemeStorage {
    func loadPreference() -> ThemePreference?
    func savePreference(_ pref: ThemePreference)
}

struct UserDefaultsThemeStorage: ThemeStorage {
    private let key = "ThemePreference"

    func loadPreference() -> ThemePreference? {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        return ThemePreference(rawValue: raw)
    }

    func savePreference(_ pref: ThemePreference) {
        UserDefaults.standard.set(pref.rawValue, forKey: key)
    }
}


⸻

5. UI Specification

5.1 Controls

Location:
	•	Settings → Appearance section
	•	Optional quick-toggle on dashboard or nav bar

Control type:
	•	Native segmented control or pill toggle:
	•	Segment 1: Light
	•	Segment 2: Dark
	•	Segment 3: Auto

SwiftUI example:

struct ThemePreferencePicker: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Picker("Appearance", selection: $themeManager.preference) {
            Text("Light").tag(ThemePreference.light)
            Text("Dark").tag(ThemePreference.dark)
            Text("Auto").tag(ThemePreference.system)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Appearance Mode")
    }
}

5.2 Visual Feedback

When user changes theme:
	•	The current screen should animate the change:
	•	If using .preferredColorScheme(themeManager.effectiveColorScheme) on the root:
	•	All child views re-render with new colors
	•	No need to manually refresh individual subviews

⸻

6. Propagation & Integration

6.1 Root Injection

The ThemeManager should be created at the app entry point:

@main
struct RootsApp: App {
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.effectiveColorScheme)
        }
    }
}

Key rule:
	•	Only the root should apply .preferredColorScheme.
	•	Children should not override it unless they have a very specific reason.

6.2 View Usage

For any view that needs to react to theme changes (e.g., to choose colors from DesignSystem):

struct DashboardView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack {
            // Use DesignSystem colors keyed off theme
        }
    }
}

But do not read system colorScheme directly for logic that should respect user preference; instead use themeManager.effectiveColorScheme.

⸻

7. Theme Resolution Behavior

7.1 Light Mode
	•	When preference == .light:
	•	effectiveColorScheme == .light
	•	preferredColorScheme(.light) applied at root
	•	No dependence on system appearance

7.2 Dark Mode
	•	When preference == .dark:
	•	effectiveColorScheme == .dark
	•	preferredColorScheme(.dark) at root
	•	No dependence on system appearance

7.3 Auto/System Mode
	•	When preference == .system:
	•	effectiveColorScheme must follow system appearance:
	•	macOS: NSApp.effectiveAppearance
	•	iOS/iPadOS: traitCollection or UITraitCollection.current.userInterfaceStyle
	•	Integration with TICKET-004:
	•	On system appearance change, recalc effectiveColorScheme
	•	Only when preference == .system, not for manual modes

This ticket (003) ensures toggles correctly set preference and that effective scheme is computed consistently; TICKET-004 tightens live system-sync behavior.

⸻

8. Persistence Behavior

8.1 On Set
	•	When user taps a theme option:
	•	ThemeManager.preference changes
	•	ThemeManager writes to ThemeStorage
	•	ThemeManager updates effectiveColorScheme
	•	Root .preferredColorScheme re-applies automatically

8.2 On Launch
	•	When app starts:
	•	ThemeManager.init loads saved preference
	•	If nil, fallback to .system
	•	Root is created with correct effectiveColorScheme immediately:
	•	Avoiding a “flash” from system-default to user preference

8.3 On Reset

If the app supports a “Reset Settings” or “Reset App” action (TICKET-035):
	•	Theme preference is set back to .system
	•	Storage key is cleared
	•	ThemeManager re-resolves from system appearance

⸻

9. Interactions with Other Tickets
	•	TICKET-004 — Auto Appearance:
	•	Builds on ThemeManager.preference == .system
	•	Focuses on listening to OS changes and responding in real time
	•	TICKET-027 — Apply preferredColorScheme globally:
	•	Ensures .preferredColorScheme(themeManager.effectiveColorScheme) is consistently applied in top-level containers
	•	TICKET-026 — Visual verification:
	•	Temporary debug overlay showing preference and effectiveColorScheme
	•	TICKET-045 — Settings persistence:
	•	Guarantees theme settings are included in the global persistence audit

⸻

10. Testing Strategy

10.1 Unit Tests
	•	ThemeManager initialization:
	•	With no stored preference → defaults to .system
	•	With stored "light" → preference .light, correct effectiveColorScheme
	•	With stored "dark" → preference .dark, correct scheme
	•	Preference change:
	•	Calling setPreference(.light):
	•	Updates preference
	•	Calls savePreference(.light) in storage
	•	Computes .light scheme
	•	Storage edge cases:
	•	Corrupted value in UserDefaults → fall back to .system safely

10.2 Integration Tests (Manual / UI)
	•	Test 1:
	•	Set theme to Dark
	•	Kill app
	•	Relaunch
	•	Confirm app starts in Dark without transition flash
	•	Test 2:
	•	Change from Light → Dark → Auto:
	•	Confirm each change updates UI immediately
	•	Confirm Date pickers, navigation bars, and cards all re-theme correctly
	•	Test 3:
	•	Navigate through:
	•	Dashboard
	•	Calendar
	•	Assignments
	•	Settings
	•	Confirm no screen retains old colors

⸻

11. Edge Cases & Failure Modes

11.1 User Changes System Theme While in Manual Mode
	•	If preference == .light or .dark:
	•	Ignore system appearance changes
	•	App stays in chosen explicit mode
	•	This avoids confusing “Auto” semantics when user expects manual override.

11.2 Missing EnvironmentObject
	•	Any view using @EnvironmentObject var themeManager: ThemeManager must be under the root environmentObject(themeManager).
	•	Add assertion / debug logging if ThemeManager is missing in view hierarchy during testing.

11.3 Multiple Windows / Scenes

If you later support multiple scenes:
	•	Each scene root must use the same ThemeManager instance (e.g., via @EnvironmentObject at Scene level).
	•	All windows respond to preference changes in lockstep.

⸻

12. Done Definition (Strict)

TICKET-003 is done when:
	•	ThemeManager exposes:
	•	preference: ThemePreference
	•	effectiveColorScheme: ColorScheme
	•	There is a single canonical place in the UI:
	•	Appearance section with Light / Dark / Auto control wired to ThemeManager.preference
	•	Root SwiftUI scene applies:
	•	.environmentObject(themeManager)
	•	.preferredColorScheme(themeManager.effectiveColorScheme)
	•	Switching Light / Dark / Auto:
	•	Immediately re-themes the current screen
	•	Has no layout glitches or half-updated colors
	•	Relaunching the app:
	•	Restores the last chosen preference
	•	Starts in the correct theme with no perceptible flash
	•	Manual testing confirms:
	•	All major screens follow theme
	•	No views ignore changes
	•	Unit tests for ThemeManager:
	•	Initialization
	•	Persistence
	•	Preference switching
	•	Scheme resolution
are passing.

⸻

Next logical one in this cluster is TICKET-004 — Auto Appearance Mode (sync with OS), which will define exactly how system appearance changes are observed and how they update effectiveColorScheme when preference == .system.