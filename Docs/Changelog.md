Changelog

2025-11-30T16:54:25.499Z - Implemented theme and LiquidGlassBackground fixes; centralized AppPaths; added data-inventory and data-storage-policy docs; added NetworkStatusMonitor and offline guards. (See Ticket_064, Ticket_063, Ticket_040)
2025-11-30T16:54:25.499Z - Fixed theme persistence: Settings now propagate system color scheme to ThemeManager when switching to Auto; LiquidGlassBackground follows ThemeManager tokens to avoid dark-only cards.
2025-11-30T16:59:43.399Z - Improved system appearance detection using platform APIs (NSApp/UITraitCollection) so Auto mode reflects real OS appearance after toggling manual modes.
2025-11-30T17:07:34.554Z - Enforced main-thread publishing: added MainThread helper, marked ThemeManager @MainActor, and guarded DashboardViewModel load mutations on main actor. (See Ticket_058)
2025-11-30T17:10:57.822Z - Converted all sliders to Apple-style UI: standardized Slider usage, accessibility labels/values, padding, tinting to Color.accentColor, and added iOS haptics for value changes.
2025-11-30T20:57:14.671Z - Completed main-thread publishing fixes (Ticket_058): added MainThread helper, marked ThemeManager @MainActor, ensured UI-published mutations occur on main actor, and added related asserts.

2025-11-30T21:20:40.867Z - Ticket_066: Added SettingsCard component and wired persistence for theme and appearance-related settings (persisting accent, theme preference, reduce motion); film grain intentionally left unchanged per ticket notes.

2025-11-30T21:31:06.827Z - Ticket_066 Progress: Wrapped Settings sections in SettingsCard groups to enforce section inset padding and consistent inter-group spacing.

2025-11-30T21:34:12.727Z - Ticket_066 Progress: Applied spacing tokens and typography normalization; updated toggles/pills to system fonts and ensured sliders use Color.accentColor tint.

2025-11-30T21:35:04.903Z - Ticket_066 Progress: Created SettingsViewModel and wired Theme/Accent/ReduceMotion bindings to the ViewModel; synchronized values into ThemeManager on SettingsView appear.

2025-11-30T21:37:22.931Z - Ticket_066 Progress: ViewModel now applies ThemeManager updates immediately; SettingsGroup enforces left content margin tokens and semibold section headers.

2025-11-30T21:38:38.441Z - Ticket_066 Progress: Slider rows aligned to shared baseline and vertical padding increased to improve spacing; Film Grain layout adjusted for baseline alignment only.

2025-12-01T00:26:48.232Z - AppKit window helper: Added explicit AppWindowCreator to programmatically host ContentView when Bundle.main.bundleIdentifier is nil. Changes include using NSHostingController as the window's contentViewController, adding .fullSizeContentView to the style mask, setting collectionBehavior to [.fullScreenPrimary, .fullScreenAuxiliary], ensuring hosting view autoresizes with the window, and setting NSApp activationPolicy to .regular when needed. Debug prints and the programmatic auto-fullscreen toggle used during development were removed; recommended to run the app from Xcode (.app bundle) for full native fullscreen behavior.
24. 2025-12-01T00:30:32.655Z - Visual: Increased contrast for dark theme text tokens to improve readability; DesignSystem.Colors.Dark.textSecondary set to white at 90% opacity and textTertiary set to 70% opacity.

25. 2025-12-01T00:33:17.753Z - Debug: WindowInspector reports styleMask: titled, closable, miniaturizable, resizable, fullSizeContentView and collectionBehavior: fullScreenPrimary. Still seeing "Unable to obtain a task name port right for pid" error during fullscreen toggle — investigation continuing.
25. 2025-12-01T00:33:17.753Z - Debug: WindowInspector reports styleMask and collectionBehavior values; fullSizeContentView present and collectionBehavior shows fullScreenPrimary. Still seeing "Unable to obtain a task name port right for pid" error during fullscreen toggle — investigation continuing.
