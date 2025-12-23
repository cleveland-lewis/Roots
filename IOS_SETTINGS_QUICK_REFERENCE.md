# iOS Settings - Quick Reference

## Settings Section Order

```
📱 Settings
│
├── ⚙️  1. GENERAL
│   ├── 🕐 24-hour time (Toggle)
│   ├── ⚡️ Energy panel (Toggle)
│   ├── 🌅 Workday start time (Time Picker)
│   └── 🌆 Workday end time (Time Picker)
│
├── 🎨 2. INTERFACE
│   └── ◐ High contrast (Toggle)
│
├── ⭐️ 3. STARRED TABS
│   ├── Dashboard (Tap to star/unstar)
│   ├── Calendar (Tap to star/unstar)
│   ├── Planner (Tap to star/unstar)
│   ├── Tasks (Tap to star/unstar)
│   ├── Courses (Tap to star/unstar)
│   ├── Timer (Tap to star/unstar)
│   └── Practice (Tap to star/unstar)
│   [Max 5 starred, Dashboard required]
│
├── 📑 4. TAB BAR PAGES
│   ├── Dashboard (Toggle) [Required]
│   ├── Calendar (Toggle)
│   ├── Planner (Toggle)
│   ├── Tasks (Toggle)
│   ├── Courses (Toggle)
│   ├── Timer (Toggle)
│   ├── Practice (Toggle)
│   └── 🔄 Restore defaults (Button)
│
├── 📅 5. CALENDAR
│   └── 📆 School calendar → Picker (Navigation)
│
├── ⏱  6. TIMER
│   └── ⏱  Timer display → Style Picker (Navigation)
│
└── ℹ️  7. ABOUT
    ├── ℹ️  Version: 1.0.0 (Static)
    └── 🔨 Build: [Bundle version] (Static)
```

## Settings by Category

### User Preferences (Modifiable)
- **General**: 4 settings
  - 24-hour time ✓
  - Energy panel ✓
  - Workday start ✓
  - Workday end ✓
- **Interface**: 1 setting
  - High contrast ✓
- **Starred Tabs**: 7 options (5 max)
- **Tab Bar Pages**: 7 toggles + 1 button
- **Calendar**: 1 navigation
- **Timer**: 1 navigation

**Total modifiable settings: 21**

### Information Display (Read-only)
- **About**: 2 values
  - Version
  - Build

## Icon & Color Reference

| Setting                | Icon                      | Color  |
|------------------------|---------------------------|--------|
| 24-hour time           | `clock`                   | Blue   |
| Energy panel           | `bolt.circle`             | Orange |
| Workday start          | `sunrise`                 | Orange |
| Workday end            | `sunset`                  | Purple |
| High contrast          | `circle.lefthalf.filled`  | Gray   |
| Starred tabs           | (page icons)              | Blue   |
| Tab bar pages          | (page icons)              | Blue   |
| Restore defaults       | `arrow.counterclockwise`  | Gray   |
| School calendar        | `calendar`                | Red    |
| Timer display          | `timer`                   | Red    |
| Version                | `info.circle`             | Blue   |
| Build                  | `hammer`                  | Gray   |

## Localization Keys

### Section Headers
```
settings.section.general
settings.section.interface
settings.section.starred_tabs
settings.section.tab_bar_pages
settings.section.calendar
settings.section.timer
settings.section.about
```

### Setting Labels
```
settings.general.use_24h
settings.general.show_energy
settings.general.high_contrast
settings.workday.start_time
settings.workday.end_time
settings.calendar.school
settings.timer.display
settings.about.version
settings.about.build
```

### Accessibility
```
settings.a11y.use_24h
settings.a11y.show_energy
settings.a11y.high_contrast
settings.a11y.workday_start
settings.a11y.workday_end
```

### Footer Text
```
settings.starred_tabs.footer
settings.calendar.selected_hint
```

### Buttons & Actions
```
settings.tabbar.restore_defaults
settings.tabbar.required
settings.tabbar.cannot_disable_hint
settings.starred_tabs.limit
```

### Search
```
settings.search
settings.title
```

## Starred Tabs vs Tab Bar Pages

### Starred Tabs
- **Purpose**: Quick access favorites
- **Limit**: Maximum 5 starred
- **Visual**: Yellow star icon
- **Required**: At least Dashboard
- **Function**: Shows in top-level navigation

### Tab Bar Pages
- **Purpose**: Full visibility control
- **Limit**: No limit (all can be visible)
- **Visual**: Toggle switches
- **Required**: Dashboard cannot be disabled
- **Function**: Controls what appears in tab bar

### Key Difference
- **Starred** = "Favorites" (subset)
- **Tab Bar** = "All visible pages" (full set)

## Common User Tasks

### Change Time Format
1. Open Settings
2. Go to **General** section (first)
3. Toggle **24-hour time**

### Set Work Hours
1. Open Settings
2. Go to **General** section (first)
3. Adjust **Workday start time**
4. Adjust **Workday end time**

### Star a Favorite Page
1. Open Settings
2. Go to **Starred Tabs** section (third)
3. Tap page to toggle star (max 5)

### Hide a Page from Tab Bar
1. Open Settings
2. Go to **Tab Bar Pages** section (fourth)
3. Toggle page off (Dashboard required)

### Connect Calendar
1. Open Settings
2. Go to **Calendar** section (fifth)
3. Tap **School calendar**
4. Select calendar from list

### Change Timer Style
1. Open Settings
2. Go to **Timer** section (sixth)
3. Tap **Timer display**
4. Select style (Digital/Analog/Progress)

### Check App Version
1. Open Settings
2. Scroll to **About** section (last)
3. View **Version** and **Build**

### Restore Default Tabs
1. Open Settings
2. Go to **Tab Bar Pages** section (fourth)
3. Scroll to bottom
4. Tap **Restore defaults**

## Search Tips

Settings are searchable by:
- Section name ("General", "Timer", etc.)
- Setting title ("24-hour", "calendar", etc.)
- Related terms (search is case-insensitive)

Examples:
- Search "time" → Shows 24-hour, Workday start/end
- Search "calendar" → Shows Calendar section
- Search "star" → Shows Starred Tabs section
- Search "version" → Shows About section

## Design Patterns

### Toggle Row
```swift
HStack {
    SettingsIconTile (rounded square with icon)
    Text (setting name)
    Spacer
    Toggle (switch)
}
```

### Navigation Row
```swift
HStack {
    SettingsIconTile (rounded square with icon)
    Text (setting name)
    Spacer
    Text (current value) .secondary
    Chevron (automatic)
}
```

### Value Row
```swift
HStack {
    SettingsIconTile (rounded square with icon)
    Text (setting name)
    Spacer
    Text (value) .secondary
}
```

### Starred Tab Row
```swift
HStack {
    SettingsIconTile (rounded square with icon)
    Text (page name)
    Spacer
    if starred {
        Image (star.fill) .yellow
    }
}
```

## Implementation Notes

### Settings Storage
- Uses `@AppStorage` for persistence
- Bindings directly to `AppSettingsModel`
- Changes save automatically

### Visual Hierarchy
- Sections use `List` with `.insetGrouped` style
- Icon tiles are 28×28pt rounded squares
- Icons are 14pt semibold
- Colors have 20% opacity backgrounds

### Accessibility
- All toggles have labels
- Custom accessibility hints where needed
- VoiceOver announces states
- Dynamic Type supported

### State Management
- `tabBarPrefs` initialized in `onAppear`
- `availableCalendars` loaded in `onAppear`
- Search text filters sections dynamically

## Migration from Old Structure

### What Changed
| Old Section | New Location | Notes |
|-------------|--------------|-------|
| Workday | General | Merged - related to general scheduling |
| High Contrast | Interface | Moved from General |
| (all others) | Same | Order adjusted only |

### What Stayed the Same
- All setting values preserved
- All functionality intact
- All bindings unchanged
- All localization keys unchanged

## FAQ

**Q: Why is "Workday" not a separate section?**
A: Workday times are general scheduling settings used across the app, so they belong in General rather than being isolated.

**Q: Why is "Interface" mostly empty?**
A: It's designed for future expansion (theme, colors, fonts) and keeps visual settings logically grouped.

**Q: What's the difference between starred and visible tabs?**
A: Starred tabs (max 5) are your favorites. Visible tabs control what appears in the tab bar at all.

**Q: Can I disable all tabs?**
A: No, Dashboard is always required to ensure the app has a home screen.

**Q: How do I add more settings?**
A: Add rows to the appropriate section array using the `SettingsRow` builder pattern.

## Code Reference

### Location
`iOS/Scenes/IOSCorePages.swift` → `IOSSettingsView`

### Adding a New Toggle
```swift
.toggle(
    title: NSLocalizedString("settings.key", comment: "Label"),
    icon: "icon.name",
    color: .blue,
    isOn: $settings.bindingName,
    a11y: NSLocalizedString("settings.a11y.key", comment: "A11y")
)
```

### Adding a New Section
```swift
settingsSection(
    title: NSLocalizedString("settings.section.name", comment: "Section"),
    rows: [
        // SettingsRow items
    ],
    footer: Text("Optional footer") // optional
)
```
