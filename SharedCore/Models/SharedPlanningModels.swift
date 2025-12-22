import Foundation

// MARK: - Shared Planning Models
// These types are available on all platforms (macOS, iOS, watchOS)

public enum AssignmentCategory: String, CaseIterable, Codable {
    case reading, exam, homework, practiceHomework, quiz, review, project
    
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
}

public struct PlanStepStub: Codable, Hashable {
    public var title: String
    public var expectedMinutes: Int
    
    public init(title: String = "", expectedMinutes: Int = 0) { 
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
        plan: [PlanStepStub] = []
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
    }
}

// Event categorization used across platforms
public enum EventCategoryStub: String, Codable, CaseIterable {
    case homework, classSession, study, exam, meeting, other
}
