import Foundation
import Combine

/// Manages persistent storage and retrieval of assignment plans
final class AssignmentPlanStore: ObservableObject {
    static let shared = AssignmentPlanStore()
    
    @Published private(set) var plans: [UUID: AssignmentPlan] = [:]  // assignmentId -> AssignmentPlan
    
    private var cacheURL: URL? = {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let folder = dir.appendingPathComponent("RootsAssignments", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("assignment_plans_cache.json")
    }()
    
    private init() {
        loadCache()
    }
    
    // MARK: - Public API
    
    /// Get the active plan for a specific assignment
    func getPlan(for assignmentId: UUID) -> AssignmentPlan? {
        return plans[assignmentId]
    }
    
    /// Save or update a plan for an assignment
    func savePlan(_ plan: AssignmentPlan) {
        var updatedPlan = plan
        
        // If there's an existing plan, archive it and increment version
        if let existingPlan = plans[plan.assignmentId] {
            var archivedPlan = existingPlan
            archivedPlan.status = .archived
            // Keep archived plans for history/undo if needed
            
            updatedPlan.version = existingPlan.version + 1
        }
        
        plans[plan.assignmentId] = updatedPlan
        saveCache()
        
        LOG_DATA(.info, "PlanStore", "Saved plan for assignment \(plan.assignmentId) (version \(updatedPlan.version))")
    }
    
    /// Delete a plan for an assignment
    func deletePlan(for assignmentId: UUID) {
        plans.removeValue(forKey: assignmentId)
        saveCache()
        
        LOG_DATA(.info, "PlanStore", "Deleted plan for assignment \(assignmentId)")
    }
    
    /// Update a specific step in a plan
    func updateStep(_ step: PlanStep, in assignmentId: UUID) {
        guard var plan = plans[assignmentId] else { return }
        
        if let index = plan.steps.firstIndex(where: { $0.id == step.id }) {
            plan.steps[index] = step
            plans[assignmentId] = plan
            saveCache()
            
            LOG_DATA(.debug, "PlanStore", "Updated step \(step.id) in plan for assignment \(assignmentId)")
        }
    }
    
    /// Mark a step as completed
    func completeStep(_ stepId: UUID, in assignmentId: UUID) {
        guard var plan = plans[assignmentId] else { return }
        
        if let index = plan.steps.firstIndex(where: { $0.id == stepId }) {
            plan.steps[index].isCompleted = true
            plan.steps[index].completedAt = Date()
            
            // Check if all steps are now completed
            if plan.isFullyCompleted {
                plan.status = .completed
            }
            
            plans[assignmentId] = plan
            saveCache()
            
            LOG_DATA(.info, "PlanStore", "Completed step \(stepId) in plan for assignment \(assignmentId)")
        }
    }
    
    /// Get all active plans
    func getActivePlans() -> [AssignmentPlan] {
        return plans.values.filter { $0.status == .active }
    }
    
    /// Get all plans that have overdue steps
    func getPlansWithOverdueSteps() -> [AssignmentPlan] {
        return plans.values.filter { plan in
            plan.steps.contains { $0.isOverdue }
        }
    }
    
    // MARK: - Dependency Management
    
    /// Toggle sequence enforcement for a plan
    func toggleSequenceEnforcement(for assignmentId: UUID) {
        guard var plan = plans[assignmentId] else { return }
        
        plan.sequenceEnforcementEnabled.toggle()
        
        // If enabling and no dependencies exist, set up linear chain
        if plan.sequenceEnforcementEnabled && !plan.steps.contains(where: { $0.hasPrerequisites }) {
            plan.setupLinearChain()
        }
        
        plans[assignmentId] = plan
        saveCache()
        
        LOG_DATA(.info, "PlanStore", "Toggled sequence enforcement to \(plan.sequenceEnforcementEnabled) for assignment \(assignmentId)")
    }
    
    /// Update step dependencies
    func updateStepDependencies(_ stepId: UUID, prerequisiteIds: [UUID], in assignmentId: UUID) {
        guard var plan = plans[assignmentId] else { return }
        
        if let index = plan.steps.firstIndex(where: { $0.id == stepId }) {
            plan.steps[index].prerequisiteIds = prerequisiteIds
            
            // Check for cycles
            if let cycle = plan.detectCycle() {
                LOG_DATA(.error, "PlanStore", "Dependency cycle detected: \(cycle). Reverting change.")
                return
            }
            
            plans[assignmentId] = plan
            saveCache()
            
            LOG_DATA(.debug, "PlanStore", "Updated dependencies for step \(stepId) in assignment \(assignmentId)")
        }
    }
    
    /// Setup linear chain dependencies for a plan
    func setupLinearChain(for assignmentId: UUID) {
        guard var plan = plans[assignmentId] else { return }
        
        plan.setupLinearChain()
        plans[assignmentId] = plan
        saveCache()
        
        LOG_DATA(.info, "PlanStore", "Setup linear chain for assignment \(assignmentId)")
    }
    
    /// Clear all dependencies for a plan
    func clearAllDependencies(for assignmentId: UUID) {
        guard var plan = plans[assignmentId] else { return }
        
        plan.clearAllDependencies()
        plans[assignmentId] = plan
        saveCache()
        
        LOG_DATA(.info, "PlanStore", "Cleared all dependencies for assignment \(assignmentId)")
    }
    
    // MARK: - Persistence
    
    private func saveCache() {
        guard let url = cacheURL else {
            LOG_DATA(.error, "PlanStore", "Unable to save cache: cacheURL is nil")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(Array(plans.values))
            try data.write(to: url, options: .atomic)
            LOG_DATA(.debug, "PlanStore", "Saved \(plans.count) plans to cache")
        } catch {
            LOG_DATA(.error, "PlanStore", "Failed to save cache: \(error.localizedDescription)")
        }
    }
    
    private func loadCache() {
        guard let url = cacheURL, FileManager.default.fileExists(atPath: url.path) else {
            LOG_DATA(.info, "PlanStore", "No existing cache file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedPlans = try decoder.decode([AssignmentPlan].self, from: data)
            
            // Convert array to dictionary keyed by assignmentId
            plans = Dictionary(uniqueKeysWithValues: loadedPlans.map { ($0.assignmentId, $0) })
            
            LOG_DATA(.info, "PlanStore", "Loaded \(plans.count) plans from cache")
        } catch {
            LOG_DATA(.error, "PlanStore", "Failed to load cache: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Create a new plan with given steps
    func createPlan(for assignmentId: UUID, steps: [PlanStep]) -> AssignmentPlan {
        let plan = AssignmentPlan(
            assignmentId: assignmentId,
            status: .draft,
            steps: steps
        )
        return plan
    }
    
    /// Activate a plan (set status to active)
    func activatePlan(for assignmentId: UUID) {
        guard var plan = plans[assignmentId] else { return }
        plan.status = .active
        plans[assignmentId] = plan
        saveCache()
        
        LOG_DATA(.info, "PlanStore", "Activated plan for assignment \(assignmentId)")
    }
}
