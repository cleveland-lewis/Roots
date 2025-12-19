# Accessibility Implementation Guide

## Overview

This document describes the complete accessibility infrastructure for the Roots app, covering VoiceOver support, Reduce Motion, keyboard navigation, color contrast, and testing.

## Architecture

### Core Components

1. **AccessibilityCoordinator** (`SharedCore/Utilities/AccessibilityCoordinator.swift`)
   - Centralized singleton monitoring all system accessibility settings
   - Real-time updates via NotificationCenter observers
   - Provides unified access to all accessibility states

2. **AnimationPolicy** (`SharedCore/Utilities/AnimationPolicy.swift`)
   - Manages animation behavior based on Reduce Motion setting
   - Context-aware animation selection (essential vs decorative)
   - Automatic reduction/disabling of non-essential animations

3. **MaterialPolicy** (`SharedCore/DesignSystem/Components/MaterialPolicy.swift`)
   - Accessibility-aware material and background resolution
   - Replaces glass materials with opaque surfaces when needed
   - Increases border contrast when Increase Contrast is enabled

4. **VoiceOverLabels** (`SharedCore/Utilities/VoiceOverLabels.swift`)
   - Centralized, semantic accessibility label generation
   - Consistent labeling patterns across the app
   - Context-aware hints and values

5. **KeyboardNavigation** (`SharedCore/Utilities/KeyboardNavigation.swift`) [macOS only]
   - App-wide keyboard shortcuts
   - Focus management utilities
   - Escape/Return/Tab handling

## Usage Guidelines

### Reduce Motion

Use `AnimationPolicy` for all animations:

```swift
import SwiftUI

struct MyView: View {
    @ObservedObject private var animationPolicy = AnimationPolicy.shared
    
    var body: some View {
        MyContent()
            .animation(animationPolicy.animation(for: .decorative), value: someState)
    }
}

// Or use the convenience modifier
MyContent()
    .animationPolicy(.decorative, value: someState)
```

**Animation Contexts:**
- `.essential` - Always shown (selection, focus changes)
- `.decorative` - Disabled with Reduce Motion (hover effects, springs)
- `.chart` - Disabled with Reduce Motion (chart drawing)
- `.continuous` - Disabled with Reduce Motion (shimmer, pulsing)
- `.navigation` - Simplified with Reduce Motion
- `.listTransition` - Disabled with Reduce Motion

### Reduce Transparency / Increase Contrast

Use `MaterialPolicy` for backgrounds:

```swift
struct MyCard: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let policy = MaterialPolicy(preferences: preferences)
        
        CardContent()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(policy.cardMaterial(colorScheme: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.primary.opacity(policy.borderOpacity),
                        lineWidth: policy.borderWidth
                    )
            )
    }
}

// Or use the convenience modifier
CardContent()
    .materialPolicyBackground(cornerRadius: 12, type: .card)
    .materialPolicyBorder(cornerRadius: 12)
```

**Material Types:**
- `.card` - Regular material or opaque card background
- `.hud` - Ultra-thin material or opaque HUD background
- `.popup` - Thick material or opaque popup background

### VoiceOver Support

Use `VoiceOverLabels` for consistent, semantic labeling:

```swift
Button("Add") {
    // action
}
.voiceOver(VoiceOverLabels.addButton(for: "Event"))

// For custom content
Text("\(minutes):\(seconds)")
    .voiceOver(VoiceOverLabels.timerDisplay(minutes: minutes, seconds: seconds))

// For list items
EventRow(event: event)
    .voiceOver(VoiceOverLabels.eventItem(
        title: event.title,
        time: formatTime(event.startDate),
        course: event.course?.name
    ))
```

**Available Label Generators:**
- `addButton(for:)`, `editButton(for:)`, `deleteButton(for:)`
- `closeButton()`, `cancelButton()`, `saveButton()`
- `navigationButton(to:)`, `previousButton(for:)`, `nextButton(for:)`
- `startTimerButton()`, `pauseTimerButton()`, `resumeTimerButton()`, `stopTimerButton()`
- `timerDisplay(minutes:seconds:)`
- `eventItem(title:time:course:)`
- `dateCell(date:eventCount:)`
- `assignmentItem(title:course:dueDate:isCompleted:)`
- `gradeItem(course:grade:points:)`
- `gpaDisplay(gpa:)`
- `chartSummary(title:dataPoints:range:)`
- `textField(label:value:placeholder:)`
- `picker(label:value:)`
- `toggle(label:isOn:)`

### Dynamic Type

Use semantic font styles instead of hard-coded sizes:

```swift
// ❌ Don't do this
Text("Label")
    .font(.system(size: 14))

// ✅ Do this
Text("Label")
    .font(.standardBody)

// Or use the style modifier
Text("Label")
    .standardBodyStyle()
```

**Available Semantic Fonts:**
- `.tinyIcon` (6pt equivalent)
- `.extraSmallCaption` (10pt equivalent)
- `.smallCaption` (12pt equivalent)
- `.standardCaption` (13pt equivalent)
- `.standardBody` (14-17pt equivalent)
- `.strongSubheadline` (17pt medium equivalent)
- `.largeNumber` (34pt equivalent)
- `.extraLargeNumber` (48pt equivalent)
- `.timerDisplay` (60pt monospaced equivalent)

All of these scale with Dynamic Type automatically.

### Keyboard Navigation (macOS)

App-wide keyboard shortcuts are defined in `KeyboardNavigation.swift`:

- **Cmd+N** - Add Event
- **Cmd+Shift+N** - Add Course
- **Cmd+A** - Add Assignment
- **Cmd+Option+F** - Toggle Focus Mode
- **Cmd+Left/Right Arrow** - Previous/Next Day
- **Cmd+Option+Left/Right Arrow** - Previous/Next Week
- **Cmd+T** - Go to Today
- **Escape** - Close popups/modals
- **Tab** - Navigate forward
- **Shift+Tab** - Navigate backward

For custom keyboard handling in views:

```swift
MyPopupView()
    .keyboardNavigation(
        onEscape: { dismiss() },
        onReturn: { save() }
    )
```

### Color Contrast

Follow WCAG guidelines:
- **AA Standard:** 4.5:1 for normal text, 3:1 for large text (18pt+)
- **AAA Standard:** 7:1 for normal text, 4.5:1 for large text

Test contrast in unit tests:

```swift
func testButtonContrast() {
    let meetsAA = AccessibilityTestHelpers.assertMeetsWCAGAA(
        foreground: .white,
        background: .blue,
        isLargeText: false
    )
    XCTAssertTrue(meetsAA)
}
```

### Touch Targets

Minimum sizes:
- **iOS/iPadOS:** 44x44 points
- **macOS:** 28x28 points

Test in unit tests:

```swift
func testButtonSize() {
    let size = CGSize(width: 44, height: 44)
    XCTAssertTrue(AccessibilityTestHelpers.assertMeetsMinimumTouchTarget(size: size))
}
```

## Testing

### Unit Tests

See `RootsTests/AccessibilityInfrastructureTests.swift` for infrastructure tests:
- AnimationPolicy behavior
- MaterialPolicy behavior
- Contrast ratio calculations
- Touch target validation
- VoiceOver label generation

### UI Tests

Create UI tests in `RootsUITests/` to verify:
- VoiceOver can reach all interactive elements
- All buttons have accessibility labels
- Keyboard navigation reaches all controls
- Focus order is logical

Example:

```swift
func testVoiceOverLabels() {
    let app = XCUIApplication()
    app.launch()
    
    let addButton = app.buttons["Add Event"]
    assertAccessible(addButton)
    XCTAssertFalse(addButton.label.isEmpty)
}

func testKeyboardNavigation() {
    let app = XCUIApplication()
    app.launch()
    
    app.typeKey("\t", modifierFlags: [])
    
    let focusedElement = app.buttons.firstMatch
    XCTAssertTrue(focusedElement.hasFocus)
}
```

### Manual Testing

Run through the manual QA checklist:

1. **VoiceOver:**
   - Enable VoiceOver (Cmd+F5 on macOS, triple-tap home on iOS)
   - Navigate through all major screens
   - Verify all interactive elements are labeled
   - Verify hints are helpful and not redundant

2. **Reduce Motion:**
   - Enable in System Settings > Accessibility > Display > Reduce Motion
   - Navigate through app
   - Verify decorative animations are disabled or minimal
   - Verify essential transitions still work

3. **Increase Contrast:**
   - Enable in System Settings > Accessibility > Display > Increase Contrast
   - Verify borders are more visible
   - Verify text is more readable

4. **Reduce Transparency:**
   - Enable in System Settings > Accessibility > Display > Reduce Transparency
   - Verify glass materials are replaced with opaque backgrounds
   - Verify content is still visible

5. **Keyboard Navigation (macOS):**
   - Navigate using Tab/Shift+Tab
   - Verify all interactive elements are reachable
   - Test keyboard shortcuts
   - Verify Escape closes popups

6. **Dynamic Type:**
   - Change text size in System Settings
   - Verify all text scales appropriately
   - Verify no text is clipped
   - Verify layouts adjust properly

## Debug Tools

In Debug builds, access the Accessibility Debug view:
- **Keyboard shortcut:** Cmd+Option+Shift+D
- Shows current system settings
- Allows simulation of accessibility features
- Live preview of accessibility states

To add to your app:

```swift
#if DEBUG
import SwiftUI

struct ContentView: View {
    @State private var showingAccessibilityDebug = false
    
    var body: some View {
        MainContent()
            .sheet(isPresented: $showingAccessibilityDebug) {
                AccessibilityDebugView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showAccessibilityDebug)) { _ in
                showingAccessibilityDebug = true
            }
    }
}
#endif
```

## Best Practices

1. **Always use semantic fonts** instead of hard-coded sizes
2. **Always use AnimationPolicy** for animations
3. **Always use MaterialPolicy** for glass/material backgrounds
4. **Always use VoiceOverLabels** for consistent accessibility labels
5. **Test with actual accessibility features enabled**
6. **Ensure minimum touch target sizes**
7. **Verify color contrast meets WCAG AA minimum**
8. **Provide keyboard shortcuts for all major actions (macOS)**
9. **Test with VoiceOver regularly during development**
10. **Write UI tests for accessibility compliance**

## Checklist for New Features

When implementing a new feature, ensure:

- [ ] All interactive elements have accessibility labels
- [ ] All buttons meet minimum touch target size
- [ ] Text uses semantic font styles (Dynamic Type compatible)
- [ ] Animations use AnimationPolicy
- [ ] Glass materials use MaterialPolicy
- [ ] Color contrast meets WCAG AA
- [ ] VoiceOver can navigate all content
- [ ] Keyboard shortcuts work (macOS)
- [ ] Focus order is logical
- [ ] Unit tests verify accessibility compliance
- [ ] Manual testing with accessibility features enabled

## Resources

- [Apple Human Interface Guidelines - Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [SwiftUI Accessibility Documentation](https://developer.apple.com/documentation/swiftui/view-accessibility)
- [Testing for Accessibility on iOS](https://developer.apple.com/documentation/accessibility/testing_for_accessibility_on_ios)

## Support

For questions or issues with accessibility implementation:
1. Review this documentation
2. Check existing tests for examples
3. Use the AccessibilityDebugView to diagnose issues
4. Refer to Apple's accessibility documentation
