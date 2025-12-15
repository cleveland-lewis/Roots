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
    var sequenceEnforcementEnabled: Bool  // NEW: Toggle for dependency enforcement
    
    init(
        id: UUID = UUID(),
        assignmentId: UUID,
        generatedAt: Date = Date(),
        version: Int = 1,
        status: PlanStatus = .draft,
        steps: [PlanStep] = [],
        sequenceEnforcementEnabled: Bool = false
    ) {
        self.id = id
        self.assignmentId = assignmentId
        self.generatedAt = generatedAt
        self.version = version
        self.status = status
        self.steps = steps
        self.sequenceEnforcementEnabled = sequenceEnforcementEnabled
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
    var prerequisiteIds: [UUID]  // NEW: Steps that must be completed before this one
    
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
        notes: String? = nil,
        prerequisiteIds: [UUID] = []
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
        self.prerequisiteIds = prerequisiteIds
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
    
    /// Whether this step has prerequisites
    var hasPrerequisites: Bool {
        !prerequisiteIds.isEmpty
    }
}

// MARK: - Dependency Management

extension AssignmentPlan {
    /// Check if a step is blocked by incomplete prerequisites
    func isStepBlocked(_ step: PlanStep) -> Bool {
        guard sequenceEnforcementEnabled else { return false }
        guard step.hasPrerequisites else { return false }
        
        // Step is blocked if any prerequisite is not completed
        for prereqId in step.prerequisiteIds {
            if let prereq = steps.first(where: { $0.id == prereqId }) {
                if !prereq.isCompleted {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Get all prerequisites for a given step
    func getPrerequisites(for step: PlanStep) -> [PlanStep] {
        step.prerequisiteIds.compactMap { prereqId in
            steps.first(where: { $0.id == prereqId })
        }
    }
    
    /// Get all steps that depend on the given step (dependents)
    func getDependents(for step: PlanStep) -> [PlanStep] {
        steps.filter { $0.prerequisiteIds.contains(step.id) }
    }
    
    /// Detect cycles in the dependency graph
    /// Returns nil if no cycle, or array of step IDs forming a cycle
    func detectCycle() -> [UUID]? {
        var visited = Set<UUID>()
        var recursionStack = Set<UUID>()
        var cyclePath: [UUID] = []
        
        func hasCycle(stepId: UUID, path: [UUID]) -> Bool {
            guard let step = steps.first(where: { $0.id == stepId }) else { return false }
            
            if recursionStack.contains(stepId) {
                // Found cycle - capture the cycle path
                if let cycleStart = path.firstIndex(of: stepId) {
                    cyclePath = Array(path[cycleStart...]) + [stepId]
                }
                return true
            }
            
            if visited.contains(stepId) {
                return false
            }
            
            visited.insert(stepId)
            recursionStack.insert(stepId)
            
            for prereqId in step.prerequisiteIds {
                if hasCycle(stepId: prereqId, path: path + [stepId]) {
                    return true
                }
            }
            
            recursionStack.remove(stepId)
            return false
        }
        
        for step in steps {
            if !visited.contains(step.id) {
                if hasCycle(stepId: step.id, path: []) {
                    return cyclePath
                }
            }
        }
        
        return nil
    }
    
    /// Perform topological sort of steps based on dependencies
    /// Returns sorted steps or nil if cycle detected
    func topologicalSort() -> [PlanStep]? {
        // Check for cycles first
        if detectCycle() != nil {
            return nil
        }
        
        var result: [PlanStep] = []
        var visited = Set<UUID>()
        
        func visit(stepId: UUID) {
            guard let step = steps.first(where: { $0.id == stepId }) else { return }
            
            if visited.contains(stepId) {
                return
            }
            
            visited.insert(stepId)
            
            // Visit all prerequisites first (depth-first)
            for prereqId in step.prerequisiteIds {
                visit(stepId: prereqId)
            }
            
            result.append(step)
        }
        
        // Visit all steps
        for step in steps {
            visit(stepId: step.id)
        }
        
        return result
    }
    
    /// Set up linear chain dependencies based on sequence index
    /// This creates a simple A→B→C→D dependency chain
    mutating func setupLinearChain() {
        let sorted = sortedSteps
        
        for (index, var step) in sorted.enumerated() {
            if index > 0 {
                // Each step depends on the previous one
                step.prerequisiteIds = [sorted[index - 1].id]
            } else {
                // First step has no prerequisites
                step.prerequisiteIds = []
            }
            
            // Update the step in the array
            if let stepIndex = steps.firstIndex(where: { $0.id == step.id }) {
                steps[stepIndex] = step
            }
        }
    }
    
    /// Clear all dependencies
    mutating func clearAllDependencies() {
        for index in steps.indices {
            steps[index].prerequisiteIds = []
        }
    }
}
