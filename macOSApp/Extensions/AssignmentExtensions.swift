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

// MARK: - Assignment Status Tracking

/// UI-only status wrapper for tracking assignment completion state
/// This is not persisted - derived from other properties or stored separately
enum AssignmentStatus: String, CaseIterable, Identifiable, Codable {
    case notStarted, inProgress, completed, archived
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
}

// MARK: - Presentation Wrapper

/// Thin presentation wrapper for AssignmentsPageView UI needs
/// References the shared Assignment model without duplicating storage
struct AssignmentPresentation: Identifiable {
    let assignment: Assignment
    var status: AssignmentStatus
    var courseCode: String
    var courseName: String
    var notes: String
    
    var id: UUID { assignment.id }
    
    init(
        assignment: Assignment,
        status: AssignmentStatus = .notStarted,
        courseCode: String = "",
        courseName: String = "",
        notes: String = ""
    ) {
        self.assignment = assignment
        self.status = status
        self.courseCode = courseCode
        self.courseName = courseName
        self.notes = notes
    }
}

#endif
