import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Shared Planning Models
// These types are available on all platforms (macOS, iOS, watchOS)

public enum AssignmentCategory: String, CaseIterable, Codable, Identifiable {
    case reading, exam, homework, practiceHomework, quiz, review, project
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .project: return "Project"
        case .exam: return "Exam"
        case .quiz: return "Quiz"
        case .homework, .practiceHomework: return "Homework"
        case .reading: return "Reading"
        case .review: return "Review"
        }
    }
}

public enum AssignmentUrgency: String, Codable, CaseIterable, Hashable, Identifiable {
    case low, medium, high, critical
    
    public var id: String { rawValue }
    
    #if canImport(SwiftUI)
    public var color: SwiftUI.Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    #endif
}

public enum AssignmentStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case notStarted
    case inProgress
    case completed
    case archived
    
    public var id: String { rawValue }
    
    public var label: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
}

public struct PlanStepStub: Codable, Hashable, Identifiable {
    public var id: UUID
    public var title: String
    public var expectedMinutes: Int
    
    public init(id: UUID = UUID(), title: String = "", expectedMinutes: Int = 0) {
        self.id = id
        self.title = title
        self.expectedMinutes = expectedMinutes
    }
}

public struct Assignment: Identifiable, Codable, Hashable {
    public let id: UUID
    public var courseId: UUID?
    public var title: String
    public var dueDate: Date
    public var estimatedMinutes: Int
    public var weightPercent: Double?
    public var category: AssignmentCategory
    public var urgency: AssignmentUrgency
    public var isLockedToDueDate: Bool
    public var plan: [PlanStepStub]
    
    // Optional UI/tracking fields
    public var status: AssignmentStatus?
    public var courseCode: String?
    public var courseName: String?
    public var notes: String?

    public init(
        id: UUID = UUID(),
        courseId: UUID? = nil,
        title: String = "",
        dueDate: Date = Date(),
        estimatedMinutes: Int = 60,
        weightPercent: Double? = nil,
        category: AssignmentCategory = .practiceHomework,
        urgency: AssignmentUrgency = .medium,
        isLockedToDueDate: Bool = false,
        plan: [PlanStepStub] = [],
        status: AssignmentStatus? = nil,
        courseCode: String? = nil,
        courseName: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.weightPercent = weightPercent
        self.category = category
        self.urgency = urgency
        self.isLockedToDueDate = isLockedToDueDate
        self.plan = plan
        self.status = status
        self.courseCode = courseCode
        self.courseName = courseName
        self.notes = notes
    }
}

// Event categorization used across platforms
public enum EventCategoryStub: String, Codable, CaseIterable {
    case homework, classSession, study, exam, meeting, other
}

// MARK: - Planner Integration

extension Assignment {
    /// Planner-specific computed properties for scheduling algorithm
    public var plannerPriorityWeight: Double {
        // Convert urgency to priority weight (0...1 scale)
        switch urgency {
        case .low: return 0.2
        case .medium: return 0.6
        case .high: return 0.8
        case .critical: return 1.0
        }
    }
    
    public var plannerEstimatedMinutes: Int {
        estimatedMinutes
    }
    
    public var plannerDueDate: Date? {
        dueDate
    }
    
    public var plannerCourseId: UUID? {
        courseId
    }
    
    public var plannerCategory: AssignmentCategory {
        category
    }
    
    /// Difficulty estimation for planner (0...1 scale)
    /// Based on category and estimated time
    public var plannerDifficulty: Double {
        let baseForCategory: Double = {
            switch category {
            case .exam: return 0.9
            case .project: return 0.8
            case .quiz: return 0.7
            case .homework, .practiceHomework: return 0.6
            case .reading: return 0.5
            case .review: return 0.4
            }
        }()
        
        // Adjust by time estimate
        let timeAdjustment: Double = {
            if estimatedMinutes < 30 { return -0.1 }
            if estimatedMinutes > 120 { return 0.1 }
            return 0.0
        }()
        
        return min(1.0, max(0.0, baseForCategory + timeAdjustment))
    }
}
