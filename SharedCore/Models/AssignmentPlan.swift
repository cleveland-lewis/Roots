import Foundation

/// Represents a persistent plan for completing an assignment
/// Each assignment can have one active plan with ordered steps
struct AssignmentPlan: Codable, Identifiable, Equatable {
    let id: UUID
    let assignmentId: UUID
    let generatedAt: Date
    var version: Int
    var status: PlanStatus
    var steps: [PlanStep]
    
    init(
        id: UUID = UUID(),
        assignmentId: UUID,
        generatedAt: Date = Date(),
        version: Int = 1,
        status: PlanStatus = .draft,
        steps: [PlanStep] = []
    ) {
        self.id = id
        self.assignmentId = assignmentId
        self.generatedAt = generatedAt
        self.version = version
        self.status = status
        self.steps = steps
    }
    
    enum PlanStatus: String, Codable {
        case draft       // Plan created but not activated
        case active      // Plan is currently being followed
        case completed   // All steps completed
        case archived    // Plan superseded by newer version
    }
}

/// Represents a single step in an assignment plan
struct PlanStep: Codable, Identifiable, Equatable {
    let id: UUID
    let planId: UUID
    var title: String
    var estimatedDuration: TimeInterval  // in seconds
    var recommendedStartDate: Date?
    var dueBy: Date?
    var sequenceIndex: Int
    var stepType: StepType
    var isCompleted: Bool
    var completedAt: Date?
    var notes: String?
    
    init(
        id: UUID = UUID(),
        planId: UUID,
        title: String,
        estimatedDuration: TimeInterval,
        recommendedStartDate: Date? = nil,
        dueBy: Date? = nil,
        sequenceIndex: Int,
        stepType: StepType = .task,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.planId = planId
        self.title = title
        self.estimatedDuration = estimatedDuration
        self.recommendedStartDate = recommendedStartDate
        self.dueBy = dueBy
        self.sequenceIndex = sequenceIndex
        self.stepType = stepType
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.notes = notes
    }
    
    enum StepType: String, Codable {
        case task         // General work task
        case reading      // Reading assignment
        case practice     // Practice problems
        case review       // Review material
        case research     // Research/gathering info
        case writing      // Writing component
        case preparation  // Prep for exam/presentation
    }
    
    /// Estimated duration in minutes for UI display
    var estimatedMinutes: Int {
        Int(estimatedDuration / 60)
    }
}

// MARK: - Helper Extensions

extension AssignmentPlan {
    /// Total estimated duration for all steps in the plan
    var totalEstimatedDuration: TimeInterval {
        steps.reduce(0) { $0 + $1.estimatedDuration }
    }
    
    /// Total estimated duration in minutes for UI display
    var totalEstimatedMinutes: Int {
        Int(totalEstimatedDuration / 60)
    }
    
    /// Number of completed steps
    var completedStepsCount: Int {
        steps.filter { $0.isCompleted }.count
    }
    
    /// Progress percentage (0-100)
    var progressPercentage: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(completedStepsCount) / Double(steps.count) * 100
    }
    
    /// Whether all steps are completed
    var isFullyCompleted: Bool {
        !steps.isEmpty && steps.allSatisfy { $0.isCompleted }
    }
    
    /// Get steps sorted by sequence index
    var sortedSteps: [PlanStep] {
        steps.sorted { $0.sequenceIndex < $1.sequenceIndex }
    }
}

extension PlanStep {
    /// Whether this step is overdue
    var isOverdue: Bool {
        guard let dueBy = dueBy, !isCompleted else { return false }
        return Date() > dueBy
    }
    
    /// Whether this step should be started soon based on recommended start date
    var shouldStartSoon: Bool {
        guard let recommendedStart = recommendedStartDate, !isCompleted else { return false }
        let now = Date()
        let oneDayFromNow = now.addingTimeInterval(24 * 60 * 60)
        return recommendedStart <= oneDayFromNow
    }
}
