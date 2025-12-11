# Nav Bar Alignment & Settings Dashboard UX Consistency – TKT-066

## 1. Ticket Metadata
- Ticket ID: TKT-066
- Title: Settings Dashboard Layout, Hierarchy, and Visual Consistency Fixes
- Creation Date: 2025-11-30
- Criticality: 2 (Moderate)
- Effort: M (1–2 days)
- Status: Open
- Owner: UI/Frontend
- File Path: /Users/clevelandlewis/PyCharm/Roots/Documents/Developing/Issues/Tickets/Open/Ticket_066.md
- Scope: Enterprise/production-grade redesign of Settings dashboard with nav bar alignment fixes

## 2. Executive Summary
- Enforce Apple-style Settings patterns across the Settings dashboard, addressing spacing, alignment, typography, control fidelity, and visual hierarchy.
- Provide a production-ready design system integration: section grouping, consistent dividers, native controls, accessibility, and coherent Theme/Accent/Mode behavior.
- Ensure visual and functional parity across Light/Dark/Auto themes and dynamic type, with optional haptics where applicable.

## 3. Problem Statement
- The navigation bar and dashboard sections are misaligned with the grid and card layout.
- Irregular spacing, inconsistent vertical rhythm, and non-native control styling (sliders, toggles, segmented controls).
- Hydration/CSS-flash-like issues observed during initial render of navigation/header areas.
- Lack of native List-style grouping or inset backgrounds in the Settings view.

## 4. Objectives
1. Align with Apple HIG for iOS/macOS settings aesthetics.
2. Apply a consistent 8/12/16-pt spacing grid across components.
3. Normalize controls to native Apple UI components (SwiftUI equivalents).
4. Improve typography with system fonts and contrast.
5. Introduce a reusable SettingsCard container with appropriate rounded corners and elevation.
6. Fix slider row alignment, padding, and tint behavior.
7. Implement end-to-end state flow: SettingsViewModel, ThemeManager, AppDataStore with persistence; optional haptics; immediate visual updates.

## 5. Scope & Deliverables
- Design tokens and layout system for Settings: sections, headers, dividers, padding, typography, and color tokens.
- Reusable SettingsCard component with rounded corners, soft background, and elevation.
- Native controls: SwiftUI-style sliders, toggles, and segmented controls; standardized hit areas.
- Accessibility hardening: larger hit targets, Dynamic Type support, contrast compliance.
- Live-updating Theme/Accent/Mode behavior with persistence and reload on launch.
- Documentation and changelog entries for the changes.

## 6. Implementation Plan

### 6.1 Section Structure & Grouping
- Convert major sections (e.g., Time format, Appearance) into card-like groups.
- Inset padding per section: 12–16pt; inter-group spacing: 24–32pt.
- Section headers: system font weight .semibold; size 15–17pt depending on platform.

### 6.2 Alignment Rules
- Single vertical alignment column for all left-aligned items.
- Toggles aligned with section labels on the same vertical grid.
- Left content margin: 20–24pt on macOS.

### 6.3 Controls Normalization
- Replace custom sliders with native Apple-style UI sliders (SwiftUI.Slider) with system tint.
- Segmented controls: native sizing, padding, shape.
- Toggles: ToggleStyle(.automatic) by default.
- Expand touch targets by 8–12pt for accessibility.

### 6.4 Typography
- Headers: .headline or .title3; Descriptions: .subheadline or .footnote.
- Value labels (e.g., Film Grain numeric) use .footnote with reduced opacity.
- Ensure high contrast in both light and dark themes.

### 6.5 Dividers & Card Styles
- Implement a reusable SettingsCard: rounded corners 12–16pt, soft background, appropriate elevation.
- Minimize internal padding to reduce blank space.

### 6.6 Slider Row Fixes
- Baseline alignment for Film Grain label, slider, and numeric output.
- 8–12pt vertical padding around the slider row.
- Tint the slider with Color.accentColor.

### 6.7 State & Behavior
- Propagate changes through SettingsViewModel, ThemeManager, AppDataStore.
- Immediate visual updates on theme, accent, and toggles.
- Optional iOS haptic feedback for slider adjustments.
- Persist state and reload on app launch.

## 7. Acceptance Criteria

### 7.1 Design & Layout
- All sections follow the 8/12/16-pt grid.
- Distinct, consistently styled section headers.
- All controls aligned vertically on the same grid.
- No overlaps, floating, or misalignment.

### 7.2 Behavior
- Sliders use native Apple styling.
- Immediate updates when controls are modified.
- Film Grain slider aligns with its label and value.
- Follow system Theme + Mode + Accent as a coherent trio.
- Responsive behavior across macOS window sizes.

### 7.3 Visual QA
- Verified in Light, Dark, and Auto modes.
- Verified across Blue, Teal, and Coral accents.
- Verified with Dynamic Type, Reduce Motion, and macOS version differences.

## 8. Dependencies, Risks & Mitigations
- Dependency: Availability of native UI components across target platforms.
- Risk: Hydration/flash during initial render; mitigation via preload strategies and optimized rendering.
- Risk: Performance impact of larger UI components; mitigation via lazy loading and memoization.
- Risk: Accessibility testing across viewports; mitigation via automated UI tests and accessibility audits.

## 9. Change History (Inline Summary)
- 2025-11-30T21:02:29Z – Work started: Added initial SettingsCard stub and updated grouping notes.
- 2025-11-30T21:20:40Z – Implementing: Created SettingsCard, added persistence hooks for theme/appearance (excluding Film Grain per request).
- 2025-11-30T21:31:06Z – Progress: Converted Settings sections into SettingsCard groups, adjusted structure to use inset cards with consistent spacing.
- 2025-11-30T21:34:12Z – Progress: Applied 8/12/16 spacing tokens, normalized toggle and pill typography to system fonts, and ensured sliders use native SwiftUI styling and accent tint.
- 2025-11-30T21:35:04Z – Progress: Added SettingsViewModel, wired theme/accent/reduceMotion to ViewModel, and synced ViewModel into ThemeManager on appear.
- 2025-11-30T21:37:22Z – Progress: SettingsViewModel now propagates theme and accent changes immediately to ThemeManager; SettingsGroup applies left margin tokens (24pt on macOS, 20pt elsewhere) and headers use semibold title3 font.
- 2025-11-30T21:38:38.441Z – Progress: Aligned slider rows to a shared baseline; increased slider row vertical padding to 8pt and ensured tint uses Color.accentColor (Film Grain row layout adjusted only).
- 2025-11-30T21:42:36Z – Debug: Added runtime debug overlay showing ThemeManager preference and accent in ContentView to verify immediate visual changes.
- 2025-11-30T21:46:38.488Z – Progress: Replaced hard-coded DesignSystem accent tokens with ThemeManager-driven accent (theme.accentBlue / themeManager.accentBlue) across top-level views to unify app accent usage.
- 2025-11-30T21:51:50Z – Done: Completed repository-wide replacement of DesignSystem accent tokens with ThemeManager accent accessors; app should now react to Accent changes immediately.
- 2025-11-30T21:56:18Z – Fixes: Added EnvironmentObject themeManager to SidebarView and SidebarButton to avoid missing scope errors.
- 2025-11-30T22:01:24Z – Fixes: Corrected ChatView send button to use theme.accentBlue (local EnvironmentObject) instead of themeManager.
- 2025-11-30T22:07:10Z – Progress: Added MainWindowAccessor to enable macOS full-screen behavior (collectionBehavior .fullScreenPrimary and resizable styleMask) and injected it into the root view.
- 2025-11-30T22:09:06Z – Fixes: Adjusted RootsApp to apply fullscreen/resizable styleMask and collectionBehavior across NSApp.windows and removed automatic toggleFullScreen call to avoid user-unexpected behavior.
- 2025-11-30T22:41:57Z – Progress: Added minimal Info.plist with CFBundleIdentifier to ensure the app window is recognized as an application window for macOS window/tab features.
- 2025-11-30T21:40:15Z – Fixes: Resolved reduceMotion binding errors by consolidating reduceMotion into SettingsViewModel and removing invalid ThemeManager.reduceMotion assignment.

## 10. Problem Areas & Proposed Fixes
- Nav bar misalignment with grid: enforce a single alignment system and Apple 8-point grid.
- Align the nav bar with the dashboard cards using the shared spacing taxonomy; remove arbitrary px values.
- Apply flex/grid normalization for cross-resolution stability.
- Preload CSS or an equivalent mechanism to prevent unstyled content flashes.

## 11. Rollout Plan
- Phase 1: Design tokens and SettingsCard architecture.
- Phase 2: Implement native controls, spacing grid, typography.
- Phase 3: Accessibility hardening and haptic feedback.
- Phase 4: End-to-end testing, QA sign-off, deployment.

## 12. Quick Stakeholder Notes
- Product: Prioritize Apple-like parity; focus on performance and accessibility.
- Engineering: Ensure cross-platform parity and minimize regressions.

## 13. Compliance & Standards
- Aligns with Apple Human Interface Guidelines (HIG) for layout, typography, and controls.
- Accessibility: Increased hit areas, contrast checks, Dynamic Type, Reduced Motion considerations.

## 14. Attachments
- None

## 15. Versioning
- Version: 1.0
- Status: Open
- Priority: High

## 16. Scope Validation
- 8/12/16 pt grid across sections.
- Native UI components usage.
- Immediate propagation of state changes.
- Visual QA across themes and accents.

## 17. Executed Notes

- Nav bar misalignment: enforced 8-point grid; aligned with dashboard cards.
- Replaced custom sliders with native sliders; standardized segmented controls.
- Introduced SettingsCard component with proper rounding and elevation.
- Enhanced accessibility: larger hit targets and Dynamic Type support.

## 18. System Notification
- Task completed: Combined enterprise ticket generated successfully. Please review and provide any adjustments or additional details you’d like included.