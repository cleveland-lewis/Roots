#if os(macOS)
import SwiftUI

// MARK: - macOS-specific UI Extensions for Shared Assignment Types

extension AssignmentUrgency {
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

extension AssignmentStatus {
    var label: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
}

#endif
