# Haptics and Sensory Feedback Guide

## Overview

Roots uses haptic feedback on macOS to provide tactile responses for user interactions. All haptic feedback respects user preferences and accessibility settings.

## Haptic Types

### HapticsManager

The `HapticsManager` provides system-level haptic feedback using CoreHaptics:

- **Warning**: Subtle feedback for warnings or important notifications
- **Error**: Strong feedback for errors or critical alerts

**Usage:**
```swift
HapticsManager.shared.play(.warning)
HapticsManager.shared.play(.error)
```

### SensoryFeedback

The `SensoryFeedback` modifier provides SwiftUI-friendly haptic feedback:

- **Success**: Positive feedback for successful operations
- **Warning**: Feedback for warnings
- **Error**: Feedback for errors
- **Selection**: Feedback for UI selections

**Usage:**
```swift
@State private var triggerHaptic = false

Button("Action") {
    triggerHaptic = true
}
.sensoryFeedback(.success, trigger: $triggerHaptic)
```

## Accessibility & User Preferences

### Automatic Respecting of Settings

All haptic feedback automatically respects:

1. **Enable Haptic Feedback Toggle** (`preferences.enableHaptics`)
   - Users can disable all haptics via Settings → Interface → Interactions
   
2. **Reduce Motion** (`preferences.reduceMotion`)
   - When enabled, all haptic feedback is disabled
   - Respects user accessibility needs

### Implementation

Both `HapticsManager` and `SensoryFeedback` check these settings before playing any haptic feedback by reading from UserDefaults:

```swift
let enableHaptics = UserDefaults.standard.bool(forKey: "preferences.enableHaptics")
let reduceMotion = UserDefaults.standard.bool(forKey: "preferences.reduceMotion")
```

## Best Practices

### When to Use Haptics

✅ **Do use haptics for:**
- Error states and validation failures
- Successful completions of important actions
- Destructive actions (e.g., deletions)
- State changes that benefit from tactile confirmation

❌ **Don't use haptics for:**
- Every button press or interaction
- Frequent/repetitive actions
- Background operations
- Non-essential feedback

### Haptic Intensity Guidelines

- **Success/Selection**: Light, subtle feedback
- **Warning**: Medium feedback to draw attention
- **Error**: Strong, distinct feedback for critical alerts

## Testing

### Test with Settings Disabled

Always test your features with haptics disabled:

1. Go to Settings → Interface → Interactions
2. Disable "Enable Haptic Feedback"
3. Verify your feature works correctly without haptics

### Test with Reduce Motion

Test with Reduce Motion enabled:

1. Go to Settings → Interface → Accessibility
2. Enable "Reduce Motion"
3. Verify haptics are disabled automatically

## macOS Limitations

macOS haptics are provided by the trackpad's Force Touch capabilities:

- Not all Mac devices support haptics (external mice, older trackpads)
- Haptic patterns are more limited than iOS
- The `HapticsManager` uses `NSHapticFeedbackManager` as fallback

## Related Files

- `SharedCore/Services/FeatureServices/HapticsManager.swift`
- `SharedCore/Services/FeatureServices/SensoryFeedback.swift`
- `SharedCore/State/AppPreferences.swift`
- `macOSApp/Views/InterfaceSettingsView.swift`
