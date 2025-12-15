//
//  AssignmentPlanDependencyTests.swift
//  RootsTests
//
//  Created for issue #70 - Task dependencies
//

import Testing
import Foundation
@testable import Roots

@MainActor
struct AssignmentPlanDependencyTests {
    
    @Test func testLinearChainSetup() async throws {
        var plan = AssignmentPlan(assignmentId: UUID(), sequenceEnforcementEnabled: true)
        
        // Add 3 steps
        let step1 = PlanStep(id: UUID(), planId: plan.id, title: "Step 1", estimatedDuration: 3600, sequenceIndex: 0)
        let step2 = PlanStep(id: UUID(), planId: plan.id, title: "Step 2", estimatedDuration: 3600, sequenceIndex: 1)
        let step3 = PlanStep(id: UUID(), planId: plan.id, title: "Step 3", estimatedDuration: 3600, sequenceIndex: 2)
        
        plan.steps = [step1, step2, step3]
        
        // Setup linear chain
        plan.setupLinearChain()
        
        // Verify chain: step1 → step2 → step3
        #expect(plan.steps[0].prerequisiteIds.isEmpty)  // First has no prerequisites
        #expect(plan.steps[1].prerequisiteIds == [step1.id])  // Second depends on first
        #expect(plan.steps[2].prerequisiteIds == [step2.id])  // Third depends on second
    }
    
    @Test func testBlockedSteps() async throws {
        var plan = AssignmentPlan(assignmentId: UUID(), sequenceEnforcementEnabled: true)
        
        let step1 = PlanStep(id: UUID(), planId: plan.id, title: "Step 1", estimatedDuration: 3600, sequenceIndex: 0, isCompleted: false)
        var step2 = PlanStep(id: UUID(), planId: plan.id, title: "Step 2", estimatedDuration: 3600, sequenceIndex: 1, isCompleted: false)
        step2.prerequisiteIds = [step1.id]
        
        plan.steps = [step1, step2]
        
        // Step 2 should be blocked because step 1 is not completed
        #expect(plan.isStepBlocked(step2) == true)
        
        // Complete step 1
        var completedStep1 = step1
        completedStep1.isCompleted = true
        plan.steps[0] = completedStep1
        
        // Step 2 should no longer be blocked
        #expect(plan.isStepBlocked(step2) == false)
    }
    
    @Test func testCycleDetection() async throws {
        var plan = AssignmentPlan(assignmentId: UUID(), sequenceEnforcementEnabled: true)
        
        let step1 = PlanStep(id: UUID(), planId: plan.id, title: "Step 1", estimatedDuration: 3600, sequenceIndex: 0)
        var step2 = PlanStep(id: UUID(), planId: plan.id, title: "Step 2", estimatedDuration: 3600, sequenceIndex: 1)
        var step3 = PlanStep(id: UUID(), planId: plan.id, title: "Step 3", estimatedDuration: 3600, sequenceIndex: 2)
        
        // Create cycle: step1 → step2 → step3 → step1
        step2.prerequisiteIds = [step1.id]
        step3.prerequisiteIds = [step2.id]
        var cycleStep1 = step1
        cycleStep1.prerequisiteIds = [step3.id]
        
        plan.steps = [cycleStep1, step2, step3]
        
        // Should detect cycle
        let cycle = plan.detectCycle()
        #expect(cycle != nil)
        #expect(cycle?.count ?? 0 > 0)
    }
    
    @Test func testTopologicalSort() async throws {
        var plan = AssignmentPlan(assignmentId: UUID(), sequenceEnforcementEnabled: true)
        
        let step1 = PlanStep(id: UUID(), planId: plan.id, title: "Step 1", estimatedDuration: 3600, sequenceIndex: 0)
        var step2 = PlanStep(id: UUID(), planId: plan.id, title: "Step 2", estimatedDuration: 3600, sequenceIndex: 1)
        var step3 = PlanStep(id: UUID(), planId: plan.id, title: "Step 3", estimatedDuration: 3600, sequenceIndex: 2)
        
        // Setup dependencies: step3 depends on step1 and step2
        step2.prerequisiteIds = [step1.id]
        step3.prerequisiteIds = [step1.id, step2.id]
        
        plan.steps = [step3, step2, step1]  // Add in random order
        
        // Topological sort should order them correctly
        let sorted = plan.topologicalSort()
        #expect(sorted != nil)
        
        // step1 should come first, step2 second, step3 last
        if let sorted = sorted {
            #expect(sorted[0].id == step1.id)
            #expect(sorted[1].id == step2.id)
            #expect(sorted[2].id == step3.id)
        }
    }
    
    @Test func testTopologicalSortWithCycle() async throws {
        var plan = AssignmentPlan(assignmentId: UUID(), sequenceEnforcementEnabled: true)
        
        let step1 = PlanStep(id: UUID(), planId: plan.id, title: "Step 1", estimatedDuration: 3600, sequenceIndex: 0)
        var step2 = PlanStep(id: UUID(), planId: plan.id, title: "Step 2", estimatedDuration: 3600, sequenceIndex: 1)
        var cycleStep1 = step1
        
        // Create cycle
        step2.prerequisiteIds = [step1.id]
        cycleStep1.prerequisiteIds = [step2.id]
        
        plan.steps = [cycleStep1, step2]
        
        // Topological sort should return nil due to cycle
        let sorted = plan.topologicalSort()
        #expect(sorted == nil)
    }
    
    @Test func testSequenceEnforcementToggle() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_plan_store_\(UUID().uuidString).json")
        
        let store = AssignmentPlanStore()
        let assignmentId = UUID()
        
        var plan = AssignmentPlan(assignmentId: assignmentId, sequenceEnforcementEnabled: false)
        plan.steps = [
            PlanStep(id: UUID(), planId: plan.id, title: "Step 1", estimatedDuration: 3600, sequenceIndex: 0),
            PlanStep(id: UUID(), planId: plan.id, title: "Step 2", estimatedDuration: 3600, sequenceIndex: 1)
        ]
        
        store.savePlan(plan)
        
        // Initially false
        #expect(store.getPlan(for: assignmentId)?.sequenceEnforcementEnabled == false)
        
        // Toggle to true
        store.toggleSequenceEnforcement(for: assignmentId)
        #expect(store.getPlan(for: assignmentId)?.sequenceEnforcementEnabled == true)
        
        // Should have automatically set up linear chain
        let updatedPlan = store.getPlan(for: assignmentId)
        #expect(updatedPlan?.steps[1].hasPrerequisites == true)
    }
    
    @Test func testGetPrerequisites() async throws {
        var plan = AssignmentPlan(assignmentId: UUID(), sequenceEnforcementEnabled: true)
        
        let step1 = PlanStep(id: UUID(), planId: plan.id, title: "Step 1", estimatedDuration: 3600, sequenceIndex: 0)
        let step2 = PlanStep(id: UUID(), planId: plan.id, title: "Step 2", estimatedDuration: 3600, sequenceIndex: 1)
        var step3 = PlanStep(id: UUID(), planId: plan.id, title: "Step 3", estimatedDuration: 3600, sequenceIndex: 2)
        
        step3.prerequisiteIds = [step1.id, step2.id]
        plan.steps = [step1, step2, step3]
        
        let prerequisites = plan.getPrerequisites(for: step3)
        #expect(prerequisites.count == 2)
        #expect(prerequisites.contains(where: { $0.id == step1.id }))
        #expect(prerequisites.contains(where: { $0.id == step2.id }))
    }
    
    @Test func testGetDependents() async throws {
        var plan = AssignmentPlan(assignmentId: UUID(), sequenceEnforcementEnabled: true)
        
        let step1 = PlanStep(id: UUID(), planId: plan.id, title: "Step 1", estimatedDuration: 3600, sequenceIndex: 0)
        var step2 = PlanStep(id: UUID(), planId: plan.id, title: "Step 2", estimatedDuration: 3600, sequenceIndex: 1)
        var step3 = PlanStep(id: UUID(), planId: plan.id, title: "Step 3", estimatedDuration: 3600, sequenceIndex: 2)
        
        step2.prerequisiteIds = [step1.id]
        step3.prerequisiteIds = [step1.id]
        plan.steps = [step1, step2, step3]
        
        let dependents = plan.getDependents(for: step1)
        #expect(dependents.count == 2)
        #expect(dependents.contains(where: { $0.id == step2.id }))
        #expect(dependents.contains(where: { $0.id == step3.id }))
    }
}
