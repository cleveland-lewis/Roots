#if os(macOS)
import SwiftUI

// MARK: - macOS-specific UI Extensions for Shared Assignment Types

extension AssignmentUrgency {
    var label: String {
        switch self {
        case .low: return String(localized: "assignments.urgency.low")
        case .medium: return String(localized: "assignments.urgency.medium")
        case .high: return String(localized: "assignments.urgency.high")
        case .critical: return String(localized: "assignments.urgency.critical")
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

extension AssignmentCategory {
    var localizedName: String {
        switch self {
        case .project: return String(localized: "assignments.category.project")
        case .exam: return String(localized: "assignments.category.exam")
        case .quiz: return String(localized: "assignments.category.quiz")
        case .homework, .practiceHomework: return String(localized: "assignments.category.homework")
        case .reading: return String(localized: "assignments.category.reading")
        case .review: return String(localized: "assignments.category.review")
        }
    }
}

extension AssignmentStatus {
    var label: String {
        switch self {
        case .notStarted: return String(localized: "assignments.status.not_started")
        case .inProgress: return String(localized: "assignments.status.in_progress")
        case .completed: return String(localized: "assignments.status.completed")
        case .archived: return String(localized: "assignments.status.archived")
        }
    }
}

#endif
