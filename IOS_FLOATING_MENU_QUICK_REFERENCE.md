# iOS Floating Menu - Quick Reference Guide

## Component Architecture

```
FloatingMenuPanel (Container)
├── Scrim (tap-to-dismiss)
└── Panel (dark material)
    └── Content (ScrollView or VStack)
        └── FloatingMenuRow(s)
            ├── Optional checkmark (left)
            ├── Title (left-aligned)
            ├── Spacer
            ├── Icon (right-aligned, SF Symbol)
            └── Separator (optional)
```

## Usage Examples

### Basic Menu Row
```swift
FloatingMenuRow(
    title: "Dashboard",
    icon: "rectangle.grid.2x2"
) {
    // Action
}
```

### Row with Checkmark (Current Selection)
```swift
FloatingMenuRow(
    title: "Dashboard",
    icon: "rectangle.grid.2x2",
    isChecked: true
) {
    // Action
}
```

### Row Without Separator (Last Item)
```swift
FloatingMenuRow(
    title: "Settings",
    icon: "gearshape",
    showSeparator: false
) {
    // Action
}
```

### Complete Menu Panel
```swift
@State private var showMenu = false

Button("Open Menu") {
    showMenu.toggle()
}
.overlay(alignment: .topLeading) {
    if showMenu {
        FloatingMenuPanel(
            isPresented: $showMenu,
            width: 280,
            maxHeight: 500
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    FloatingMenuRow(
                        title: "Option 1",
                        icon: "star"
                    ) {
                        // Action
                        showMenu = false
                    }
                    
                    FloatingMenuSectionDivider()
                    
                    FloatingMenuRow(
                        title: "Settings",
                        icon: "gearshape",
                        showSeparator: false
                    ) {
                        // Action
                        showMenu = false
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .offset(x: 0, y: 52)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showMenu)
    }
}
```

## Design Tokens

### Colors
- **Row background (pressed)**: `Color.white.opacity(0.15)`
- **Text**: `Color.white`
- **Icon**: `Color.white.opacity(0.6)`
- **Separator**: `Color.white.opacity(0.15)`
- **Section divider**: `Color.white.opacity(0.2)`
- **Header text**: `Color.white.opacity(0.6)`

### Typography
- **Row title**: 17pt, regular weight, system font
- **Icon**: 20pt, regular weight
- **Checkmark**: 16pt, semibold weight
- **Section header**: 13pt, semibold weight, uppercase

### Spacing
- **Row height**: 48pt minimum
- **Row padding**: 16pt horizontal, 14pt vertical
- **Separator inset**: 16pt leading (48pt with checkmark)
- **Section divider height**: 8pt
- **Panel corner radius**: 16pt (continuous)
- **Menu offset from button**: 52pt vertical

### Shadows
- **Primary**: black 30% opacity, 20pt radius, Y-offset 10pt
- **Edge**: black 10% opacity, 2pt radius, Y-offset 1pt

## Accessibility Labels

### Menu Buttons
```swift
.accessibilityLabel("Open menu")
.accessibilityLabel("Quick add")
```

### Menu Rows
Labels automatically inherit from title text. For custom behavior:
```swift
FloatingMenuRow(title: "Dashboard", icon: "rectangle.grid.2x2") {
    // ...
}
.accessibilityLabel("Navigate to Dashboard")
.accessibilityHint("Double tap to open")
```

## Animation Configuration

### Spring Animation
```swift
.animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingMenu)
```

### Transition
```swift
.transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
```
- Anchor should match overlay alignment (`.topLeading` or `.topTrailing`)

## Menu Positioning

### Left-Anchored (Hamburger)
```swift
.overlay(alignment: .topLeading) {
    // Menu panel
}
.offset(x: 0, y: 52)
```

### Right-Anchored (Quick Actions)
```swift
.overlay(alignment: .topTrailing) {
    // Menu panel
}
.offset(x: 0, y: 52)
```

## Common SF Symbol Icons

### Navigation
- Dashboard: `rectangle.grid.2x2`
- Calendar: `calendar`
- Planner: `square.and.pencil`
- Tasks: `checklist`
- Courses: `book.closed`
- Grades: `chart.bar.doc.horizontal`
- Timer: `timer`
- Practice: `list.clipboard`

### Actions
- Add: `plus`
- Add Assignment: `plus.square.on.square`
- Add Grade: `number.circle`
- Auto Schedule: `calendar.badge.clock`
- Settings: `gearshape`

### States
- Checkmark: `checkmark`
- Close: `xmark.circle.fill`

## Platform Constraints

### iOS Only
All components are wrapped in `#if os(iOS)` for iOS/iPadOS only.

### Minimum Versions
- Requires iOS 17+ (uses `onChange` with two-parameter closure)
- Compatible with iPhone and iPad

## Best Practices

1. **Always dismiss menus after selection**
   ```swift
   action: {
       handleAction()
       showMenu = false  // ✅
   }
   ```

2. **Use ScrollView for long menus**
   - Set `maxHeight` on FloatingMenuPanel
   - Wrap rows in ScrollView for overflow

3. **Group related items with section dividers**
   ```swift
   ForEach(navigationItems) { item in
       FloatingMenuRow(...)
   }
   FloatingMenuSectionDivider()
   ForEach(settingsItems) { item in
       FloatingMenuRow(...)
   }
   ```

4. **Use appropriate anchor alignment**
   - Left buttons → `.topLeading`
   - Right buttons → `.topTrailing`
   - Center buttons → `.top`

5. **Maintain consistent icon semantics**
   - Navigation items: use page-specific icons
   - Actions: use action-specific icons
   - Don't mix icon styles within same menu

## Testing Checklist

- [ ] Menu appears with smooth animation
- [ ] Tap outside dismisses menu
- [ ] All icons visible and properly aligned
- [ ] Separators appear between rows (except last)
- [ ] Press state shows white overlay (not blue)
- [ ] VoiceOver reads items correctly
- [ ] Works in light and dark mode
- [ ] ScrollView activates for long lists
- [ ] Menu positioning correct for button location
- [ ] All actions execute and dismiss menu

## Troubleshooting

### Menu doesn't appear
- Check `isPresented` binding is toggled
- Verify overlay alignment matches button position
- Ensure menu content isn't empty

### Menu appears in wrong location
- Adjust `.offset()` Y-value based on button size
- Check overlay alignment (`.topLeading` vs `.topTrailing`)
- Consider safe area insets

### Blue highlight on press
- Verify using `FloatingMenuButtonStyle`
- Check no default `.buttonStyle()` applied elsewhere

### Dark mode issues
- FloatingMenuPanel forces dark colorScheme internally
- Don't override with additional `.environment()` modifiers

### Separator not showing
- Check `showSeparator: true` (default)
- Verify separator color opacity sufficient
- Last item should have `showSeparator: false`

## Migration from Old Menus

### Before (Popover)
```swift
.popover(isPresented: $showMenu) {
    VStack {
        Button("Item") { }
    }
}
```

### After (FloatingMenuPanel)
```swift
.overlay(alignment: .topLeading) {
    if showMenu {
        FloatingMenuPanel(isPresented: $showMenu) {
            FloatingMenuRow(title: "Item", icon: "star") { }
        }
        .offset(y: 52)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showMenu)
    }
}
```
