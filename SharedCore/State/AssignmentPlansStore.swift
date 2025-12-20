import Foundation
import Combine

/// Store for managing assignment plans
/// Handles persistence, refresh triggers, and plan lifecycle
@MainActor
final class AssignmentPlansStore: ObservableObject {
    static let shared = AssignmentPlansStore()
    
    @Published private(set) var plans: [UUID: AssignmentPlan] = [:]
    @Published private(set) var isLoading = true
    @Published var lastRefreshDate: Date?
    
    private let storageURL: URL
    private let settings: PlanGenerationSettings
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("RootsPlans", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        self.storageURL = folder.appendingPathComponent("assignment_plans.json")
        self.settings = .default
        
        load()
        isLoading = false
    }
    
    // MARK: - Plan Access
    
    func plan(for assignmentId: UUID) -> AssignmentPlan? {
        plans[assignmentId]
    }
    
    func hasPlan(for assignmentId: UUID) -> Bool {
        plans[assignmentId] != nil
    }
    
    // MARK: - Plan Generation
    
    /// Generate or regenerate a plan for a single assignment
    func generatePlan(for assignment: Assignment, force: Bool = false) {
        if !force && hasPlan(for: assignment.id) {
            return
        }
        
        let plan = AssignmentPlanEngine.generatePlan(for: assignment, settings: settings)
        plans[assignment.id] = plan
        save()
    }
    
    /// Generate plans for multiple assignments
    func generatePlans(for assignments: [Assignment], force: Bool = false) {
        for assignment in assignments {
            generatePlan(for: assignment, force: force)
        }
    }
    
    /// Regenerate all plans (manual refresh)
    func regenerateAllPlans(for assignments: [Assignment]) {
        generatePlans(for: assignments, force: true)
        lastRefreshDate = Date()
    }
    
    // MARK: - Plan Lifecycle
    
    /// Update an existing plan
    func updatePlan(_ plan: AssignmentPlan) {
        plans[plan.assignmentId] = plan
        save()
    }
    
    /// Mark a step as completed
    func completeStep(stepId: UUID, in assignmentId: UUID) {
        guard var plan = plans[assignmentId] else { return }
        
        if let stepIndex = plan.steps.firstIndex(where: { $0.id == stepId }) {
            var step = plan.steps[stepIndex]
            step.isCompleted = true
            step.completedAt = Date()
            plan.steps[stepIndex] = step
            
            if plan.isFullyCompleted {
                plan.status = .completed
            }
            
            plans[assignmentId] = plan
            save()
        }
    }
    
    /// Mark a step as incomplete
    func uncompleteStep(stepId: UUID, in assignmentId: UUID) {
        guard var plan = plans[assignmentId] else { return }
        
        if let stepIndex = plan.steps.firstIndex(where: { $0.id == stepId }) {
            var step = plan.steps[stepIndex]
            step.isCompleted = false
            step.completedAt = nil
            plan.steps[stepIndex] = step
            
            if plan.status == .completed {
                plan.status = .active
            }
            
            plans[assignmentId] = plan
            save()
        }
    }
    
    /// Delete a plan
    func deletePlan(for assignmentId: UUID) {
        plans.removeValue(forKey: assignmentId)
        save()
    }
    
    /// Archive old plans when assignments are deleted
    func archivePlans(for assignmentIds: [UUID]) {
        for id in assignmentIds {
            if var plan = plans[id] {
                plan.status = .archived
                plans[id] = plan
            }
        }
        save()
    }
    
    // MARK: - Refresh Triggers
    
    /// Regenerate plans after an event is added that affects availability
    func refreshPlansAfterEventAdd(assignments: [Assignment]) {
        generatePlans(for: assignments, force: true)
        lastRefreshDate = Date()
    }
    
    // MARK: - Persistence
    
    private func save() {
        do {
            let payload = PlansPayload(plans: Array(plans.values))
            let data = try JSONEncoder().encode(payload)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            print("Failed to save assignment plans: \(error)")
        }
    }
    
    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let payload = try JSONDecoder().decode(PlansPayload.self, from: data)
            
            self.plans = Dictionary(uniqueKeysWithValues: payload.plans.map { ($0.assignmentId, $0) })
        } catch {
            print("Failed to load assignment plans: \(error)")
        }
    }
    
    private struct PlansPayload: Codable {
        var plans: [AssignmentPlan]
    }
}
