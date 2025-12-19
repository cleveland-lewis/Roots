import SwiftUI

/// Centralized VoiceOver label generation for consistent accessibility across the app
/// Provides semantic, context-aware labels for all interactive elements
public struct VoiceOverLabels {
    
    // MARK: - Common Actions
    
    public static func addButton(for itemType: String) -> AccessibilityContent {
        AccessibilityContent(
            label: "Add \(itemType)",
            hint: "Opens form to create a new \(itemType)"
        )
    }
    
    public static func editButton(for itemType: String) -> AccessibilityContent {
        AccessibilityContent(
            label: "Edit \(itemType)",
            hint: "Opens form to edit this \(itemType)"
        )
    }
    
    public static func deleteButton(for itemType: String) -> AccessibilityContent {
        AccessibilityContent(
            label: "Delete \(itemType)",
            hint: "Removes this \(itemType)"
        )
    }
    
    public static func closeButton() -> AccessibilityContent {
        AccessibilityContent(
            label: "Close",
            hint: "Dismisses current view"
        )
    }
    
    public static func cancelButton() -> AccessibilityContent {
        AccessibilityContent(
            label: "Cancel",
            hint: "Cancels current action and closes"
        )
    }
    
    public static func saveButton() -> AccessibilityContent {
        AccessibilityContent(
            label: "Save",
            hint: "Saves changes and closes"
        )
    }
    
    // MARK: - Navigation
    
    public static func navigationButton(to destination: String) -> AccessibilityContent {
        AccessibilityContent(
            label: destination,
            hint: "Navigate to \(destination)"
        )
    }
    
    public static func previousButton(for context: String) -> AccessibilityContent {
        AccessibilityContent(
            label: "Previous \(context)",
            hint: "Go to previous \(context)"
        )
    }
    
    public static func nextButton(for context: String) -> AccessibilityContent {
        AccessibilityContent(
            label: "Next \(context)",
            hint: "Go to next \(context)"
        )
    }
    
    // MARK: - Timer/Focus
    
    public static func startTimerButton() -> AccessibilityContent {
        AccessibilityContent(
            label: "Start Timer",
            hint: "Begins countdown timer"
        )
    }
    
    public static func pauseTimerButton() -> AccessibilityContent {
        AccessibilityContent(
            label: "Pause Timer",
            hint: "Pauses active timer"
        )
    }
    
    public static func resumeTimerButton() -> AccessibilityContent {
        AccessibilityContent(
            label: "Resume Timer",
            hint: "Continues paused timer"
        )
    }
    
    public static func stopTimerButton() -> AccessibilityContent {
        AccessibilityContent(
            label: "Stop Timer",
            hint: "Stops and resets timer"
        )
    }
    
    public static func timerDisplay(minutes: Int, seconds: Int) -> AccessibilityContent {
        let minutesText = minutes == 1 ? "minute" : "minutes"
        let secondsText = seconds == 1 ? "second" : "seconds"
        
        return AccessibilityContent(
            label: "Timer",
            value: "\(minutes) \(minutesText), \(seconds) \(secondsText)",
            hint: nil
        )
    }
    
    // MARK: - Calendar/Events
    
    public static func eventItem(title: String, time: String, course: String?) -> AccessibilityContent {
        var label = "\(title) at \(time)"
        if let course = course {
            label += ", \(course)"
        }
        
        return AccessibilityContent(
            label: label,
            hint: "Double tap to view details"
        )
    }
    
    public static func dateCell(date: Date, eventCount: Int) -> AccessibilityContent {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: date)
        
        let eventsText = eventCount == 1 ? "event" : "events"
        let value = eventCount > 0 ? "\(eventCount) \(eventsText)" : "No events"
        
        return AccessibilityContent(
            label: dateString,
            value: value,
            hint: "Double tap to view day"
        )
    }
    
    // MARK: - Assignments
    
    public static func assignmentItem(
        title: String,
        course: String,
        dueDate: Date,
        isCompleted: Bool
    ) -> AccessibilityContent {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dueDateString = formatter.string(from: dueDate)
        
        let statusText = isCompleted ? "Completed" : "Not completed"
        let label = "\(title), \(course), due \(dueDateString), \(statusText)"
        
        return AccessibilityContent(
            label: label,
            hint: "Double tap to view details"
        )
    }
    
    // MARK: - Grades
    
    public static func gradeItem(
        course: String,
        grade: String,
        points: String?
    ) -> AccessibilityContent {
        var label = "\(course), grade \(grade)"
        if let points = points {
            label += ", \(points)"
        }
        
        return AccessibilityContent(
            label: label,
            hint: "Double tap to view details"
        )
    }
    
    public static func gpaDisplay(gpa: Double) -> AccessibilityContent {
        AccessibilityContent(
            label: "Grade Point Average",
            value: String(format: "%.2f", gpa),
            hint: nil
        )
    }
    
    // MARK: - Charts
    
    public static func chartSummary(
        title: String,
        dataPoints: Int,
        range: String?
    ) -> AccessibilityContent {
        var label = "\(title), \(dataPoints) data points"
        if let range = range {
            label += ", \(range)"
        }
        
        return AccessibilityContent(
            label: label,
            hint: "Chart displaying \(title.lowercased())"
        )
    }
    
    public static func chartDataPoint(
        value: String,
        label: String
    ) -> AccessibilityContent {
        AccessibilityContent(
            label: label,
            value: value,
            hint: nil
        )
    }
    
    // MARK: - Forms
    
    public static func textField(
        label: String,
        value: String?,
        placeholder: String?
    ) -> AccessibilityContent {
        var content = AccessibilityContent(
            label: label,
            value: value ?? placeholder ?? "",
            hint: "Text field"
        )
        
        if value == nil, let placeholder = placeholder {
            content.hint = "Text field, \(placeholder)"
        }
        
        return content
    }
    
    public static func picker(
        label: String,
        value: String
    ) -> AccessibilityContent {
        AccessibilityContent(
            label: label,
            value: value,
            hint: "Picker, double tap to change"
        )
    }
    
    public static func toggle(
        label: String,
        isOn: Bool
    ) -> AccessibilityContent {
        AccessibilityContent(
            label: label,
            value: isOn ? "On" : "Off",
            hint: "Toggle switch"
        )
    }
}

// MARK: - Accessibility Content Structure

public struct AccessibilityContent {
    let label: String
    let value: String?
    var hint: String?
    
    init(label: String, value: String? = nil, hint: String? = nil) {
        self.label = label
        self.value = value
        self.hint = hint
    }
}

// MARK: - View Extensions

extension View {
    /// Apply VoiceOver labels from AccessibilityContent
    public func voiceOver(_ content: AccessibilityContent) -> some View {
        self
            .accessibilityLabel(content.label)
            .modifier(OptionalValueModifier(value: content.value))
            .modifier(OptionalHintModifier(hint: content.hint))
    }
}

private struct OptionalValueModifier: ViewModifier {
    let value: String?
    
    func body(content: Content) -> some View {
        if let value = value {
            content.accessibilityValue(value)
        } else {
            content
        }
    }
}

private struct OptionalHintModifier: ViewModifier {
    let hint: String?
    
    func body(content: Content) -> some View {
        if let hint = hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}
