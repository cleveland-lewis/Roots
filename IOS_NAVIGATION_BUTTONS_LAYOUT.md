# iOS/iPadOS Navigation Button Layout Implementation

## Overview
Implemented adaptive navigation button positioning for iOS and iPadOS that responds to device type and navigation state.

## Changes Made

### 1. IOSAppShell.swift - Adaptive Button Visibility
**Location**: `iOS/Root/IOSAppShell.swift`

**Key Changes**:
- Added `@Environment(\.horizontalSizeClass)` detection to distinguish iPhone (compact) vs iPad (regular)
- Implemented `shouldShowButtons` logic:
  - **iPhone (compact width)**: Hide hamburger/quick-action buttons when navigated (back button present)
    - Buttons visible only when `navigation.path.isEmpty` (at root level)
  - **iPad (regular width)**: Always show buttons (even when navigated)
- Added top padding adjustment:
  - iPad: No padding (aligns with tab bar)
  - iPhone: 10pt padding (slight offset from top)

**Rationale**:
- On iPhone, the back button replaces navigation buttons to reduce clutter
- On iPad, there's enough screen space to show both navigation buttons and content hierarchy

### 2. IOSNavigationChrome - Environment Detection
**Location**: `iOS/Root/IOSNavigationCoordinator.swift`

**Key Changes**:
- Added `@Environment(\.horizontalSizeClass)` to the modifier
- Prepared for future adaptive toolbar content positioning

**Future Enhancement**:
- Can be extended to show page-specific actions differently on iPad vs iPhone

### 3. IOSPlannerView - Bottom Floating Button (iPad)
**Location**: `iOS/Scenes/IOSCorePages.swift`

**Key Changes**:
- Added `@Environment(\.horizontalSizeClass)` detection
- Implemented iPad-specific bottom floating "Generate Plan" button:
  - Full-width button with accent color
  - Positioned at bottom with shadow
  - Extra 80pt bottom padding in ScrollView to prevent content overlap
- iPhone keeps the toolbar sparkles button (top-right)
- Removed redundant "Generate Plan" button from `planHeader`

**Button Locations by Device**:
- **iPhone**: Sparkles icon in top-right toolbar
- **iPad**: Full-width floating button at bottom of screen

## Navigation Button Behavior Summary

### iPhone (Compact Width)
```
Root Level (Tab):
  ┌─────────────────────────┐
  │ ☰              +        │ ← Buttons visible
  │                         │
  │   [Content]             │
  │                         │
  └─────────────────────────┘

Navigated State (Back button):
  ┌─────────────────────────┐
  │ ← Back                  │ ← No hamburger/+ buttons
  │                         │
  │   [Content]             │
  │                         │
  └─────────────────────────┘
```

### iPad (Regular Width)
```
Any State:
  ┌─────────────────────────┐
  │ ☰              +        │ ← Always visible
  │                         │
  │   [Content]             │
  │                         │
  │                         │
  │   [Generate Plan] 💫   │ ← Bottom button (Planner only)
  └─────────────────────────┘
```

## Settings Integration
- Hamburger and quick-action buttons are hidden in Settings views via `hideNavigationButtons: true`
- This applies to both iPhone and iPad
- Settings uses native back navigation without custom overlays

## Technical Implementation Details

### Size Class Detection
```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

private var isPad: Bool {
    horizontalSizeClass == .regular
}
```

### Navigation State Detection
```swift
private var shouldShowButtons: Bool {
    if hideNavigationButtons { return false }
    
    // iPhone: hide when navigated
    if horizontalSizeClass == .compact {
        return navigation.path.isEmpty
    }
    
    // iPad: always show
    return true
}
```

### Bottom Floating Button Pattern (iPad)
```swift
ZStack(alignment: .bottom) {
    ScrollView {
        // Content with bottom padding
    }
    .padding(.bottom, isPad ? 80 : 0)
    
    if isPad {
        // Floating button
    }
}
```

## Benefits
1. **Cleaner iPhone UI**: Back button not competing with hamburger menu
2. **Consistent iPad Experience**: Navigation always accessible regardless of depth
3. **Better Touch Targets**: Bottom buttons on iPad are easier to reach
4. **Platform-Appropriate Design**: Follows iOS HIG for navigation patterns

## Testing Checklist
- [x] Build succeeds on iOS Simulator
- [ ] iPhone: Hamburger/+ buttons hide when navigating into a page
- [ ] iPhone: Hamburger/+ buttons reappear at root tab level
- [ ] iPad: Hamburger/+ buttons always visible
- [ ] iPad: Planner shows floating bottom "Generate Plan" button
- [ ] iPhone: Planner shows toolbar sparkles button
- [ ] Settings hides all navigation buttons on both devices

## Future Enhancements
1. Add more page-specific bottom buttons on iPad (e.g., "Add Course", "Filter")
2. Implement split-view navigation on iPad for deeper hierarchies
3. Add animation transitions for button visibility changes
4. Consider moving quick-actions to a context-aware FAB on iPhone
