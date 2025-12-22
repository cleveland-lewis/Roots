import XCTest
@testable import SharedCore

/// Tests for PlanGraph integration with AIScheduler
/// Verifies blocked nodes are never scheduled and auto-unblock on completion
final class PlanGraphSchedulerIntegrationTests: XCTestCase {
    
    var planStore: AssignmentPlanStore!
    
    override func setUp() {
        super.setUp()
        planStore = AssignmentPlanStore.shared
        // Clear existing plans
        planStore.plans.removeAll()
    }
    
    override func tearDown() {
        planStore.plans.removeAll()
        super.tearDown()
    }
    
    // MARK: - Task Filtering Tests
    
    func testGetSchedulableTasks_NoDependencies_AllSchedulable() {
        // Given: Tasks without plans
        let tasks = [
            createTask(id: UUID(), title: "Task 1", isCompleted: false),
            createTask(id: UUID(), title: "Task 2", isCompleted: false),
            createTask(id: UUID(), title: "Task 3", isCompleted: false)
        ]
        
        // When: Getting schedulable tasks
        let schedulable = PlanGraphSchedulerIntegration.getSchedulableTasks(tasks, planStore: planStore)
        
        // Then: All tasks are schedulable
        XCTAssertEqual(schedulable.count, 3)
        XCTAssertEqual(Set(schedulable.map(\.id)), Set(tasks.map(\.id)))
    }
    
    func testGetSchedulableTasks_CompletedTasksExcluded() {
        // Given: Mix of completed and incomplete tasks
        let tasks = [
            createTask(id: UUID(), title: "Task 1", isCompleted: false),
            createTask(id: UUID(), title: "Task 2", isCompleted: true),
            createTask(id: UUID(), title: "Task 3", isCompleted: false)
        ]
        
        // When: Getting schedulable tasks
        let schedulable = PlanGraphSchedulerIntegration.getSchedulableTasks(tasks, planStore: planStore)
        
        // Then: Only incomplete tasks are schedulable
        XCTAssertEqual(schedulable.count, 2)
        XCTAssertFalse(schedulable.contains(where: { $0.isCompleted }))
    }
    
    func testGetSchedulableTasks_EnforcementDisabled_AllSchedulable() {
        // Given: Plan with dependencies but enforcement disabled
        let task1 = createTask(id: UUID(), title: "Task 1", isCompleted: false)
        let task2 = createTask(id: UUID(), title: "Task 2", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: task2.id,
            steps: [
                (task1.id, "Task 1", false),
                (task2.id, "Task 2", false)
            ],
            edges: [(0, 1)], // Task 1 → Task 2
            enforcementEnabled: false
        )
        
        planStore.savePlan(plan)
        
        // When: Getting schedulable tasks
        let schedulable = PlanGraphSchedulerIntegration.getSchedulableTasks([task1, task2], planStore: planStore)
        
        // Then: All tasks are schedulable (enforcement disabled)
        XCTAssertEqual(schedulable.count, 2)
    }
    
    func testGetSchedulableTasks_BlockedByPrerequisite() {
        // Given: Plan with task 2 blocked by task 1
        let task1 = createTask(id: UUID(), title: "Task 1", isCompleted: false)
        let task2 = createTask(id: UUID(), title: "Task 2", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: task2.id,
            steps: [
                (task1.id, "Task 1", false),
                (task2.id, "Task 2", false)
            ],
            edges: [(0, 1)], // Task 1 → Task 2
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        // When: Getting schedulable tasks
        let schedulable = PlanGraphSchedulerIntegration.getSchedulableTasks([task1, task2], planStore: planStore)
        
        // Then: Only task 1 is schedulable (task 2 is blocked)
        XCTAssertEqual(schedulable.count, 1)
        XCTAssertEqual(schedulable.first?.id, task1.id)
    }
    
    func testGetSchedulableTasks_PrerequisiteComplete_UnblocksDependent() {
        // Given: Plan with task 2 blocked by task 1, but task 1 is complete
        let task1 = createTask(id: UUID(), title: "Task 1", isCompleted: true)
        let task2 = createTask(id: UUID(), title: "Task 2", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: task2.id,
            steps: [
                (task1.id, "Task 1", true),  // Complete
                (task2.id, "Task 2", false)
            ],
            edges: [(0, 1)], // Task 1 → Task 2
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        // When: Getting schedulable tasks
        let schedulable = PlanGraphSchedulerIntegration.getSchedulableTasks([task1, task2], planStore: planStore)
        
        // Then: Task 2 is schedulable (task 1 complete)
        XCTAssertEqual(schedulable.count, 1)
        XCTAssertEqual(schedulable.first?.id, task2.id)
    }
    
    func testGetSchedulableTasks_ComplexDependencyChain() {
        // Given: Chain A → B → C → D
        let taskA = createTask(id: UUID(), title: "Task A", isCompleted: true)
        let taskB = createTask(id: UUID(), title: "Task B", isCompleted: true)
        let taskC = createTask(id: UUID(), title: "Task C", isCompleted: false)
        let taskD = createTask(id: UUID(), title: "Task D", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: taskD.id,
            steps: [
                (taskA.id, "Task A", true),
                (taskB.id, "Task B", true),
                (taskC.id, "Task C", false),
                (taskD.id, "Task D", false)
            ],
            edges: [(0, 1), (1, 2), (2, 3)], // A → B → C → D
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        // When: Getting schedulable tasks
        let schedulable = PlanGraphSchedulerIntegration.getSchedulableTasks(
            [taskA, taskB, taskC, taskD],
            planStore: planStore
        )
        
        // Then: Only Task C is schedulable (A and B complete, D blocked by C)
        XCTAssertEqual(schedulable.count, 1)
        XCTAssertEqual(schedulable.first?.id, taskC.id)
    }
    
    // MARK: - Auto-Unblocking Tests
    
    func testGetNewlyUnblockedTasks_SingleDependent() {
        // Given: Task B blocked by Task A
        let taskA = createTask(id: UUID(), title: "Task A", isCompleted: false)
        let taskB = createTask(id: UUID(), title: "Task B", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: taskB.id,
            steps: [
                (taskA.id, "Task A", false),
                (taskB.id, "Task B", false)
            ],
            edges: [(0, 1)], // A → B
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        // When: Task A completes
        var updatedPlan = plan
        var graph = updatedPlan.toPlanGraph()
        if let nodeA = graph.nodes.first(where: { $0.assignmentId == taskA.id }) {
            graph.markNodeCompleted(nodeA.id)
            updatedPlan.applyPlanGraph(graph)
            planStore.savePlan(updatedPlan)
        }
        
        let newlyUnblocked = PlanGraphSchedulerIntegration.getNewlyUnblockedTasks(
            after: taskA.id,
            from: [taskA, taskB],
            planStore: planStore
        )
        
        // Then: Task B is unblocked
        XCTAssertEqual(newlyUnblocked.count, 1)
        XCTAssertEqual(newlyUnblocked.first, taskB.id)
    }
    
    func testGetNewlyUnblockedTasks_MultipleDependents() {
        // Given: Tasks B and C both blocked by Task A
        let taskA = createTask(id: UUID(), title: "Task A", isCompleted: false)
        let taskB = createTask(id: UUID(), title: "Task B", isCompleted: false)
        let taskC = createTask(id: UUID(), title: "Task C", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: taskC.id,
            steps: [
                (taskA.id, "Task A", false),
                (taskB.id, "Task B", false),
                (taskC.id, "Task C", false)
            ],
            edges: [(0, 1), (0, 2)], // A → B, A → C
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        // When: Task A completes
        var updatedPlan = plan
        var graph = updatedPlan.toPlanGraph()
        if let nodeA = graph.nodes.first(where: { $0.assignmentId == taskA.id }) {
            graph.markNodeCompleted(nodeA.id)
            updatedPlan.applyPlanGraph(graph)
            planStore.savePlan(updatedPlan)
        }
        
        let newlyUnblocked = PlanGraphSchedulerIntegration.getNewlyUnblockedTasks(
            after: taskA.id,
            from: [taskA, taskB, taskC],
            planStore: planStore
        )
        
        // Then: Both B and C are unblocked
        XCTAssertEqual(newlyUnblocked.count, 2)
        XCTAssertTrue(newlyUnblocked.contains(taskB.id))
        XCTAssertTrue(newlyUnblocked.contains(taskC.id))
    }
    
    func testGetNewlyUnblockedTasks_PartialPrerequisitesComplete() {
        // Given: Task C requires both A and B, only A completes
        let taskA = createTask(id: UUID(), title: "Task A", isCompleted: false)
        let taskB = createTask(id: UUID(), title: "Task B", isCompleted: false)
        let taskC = createTask(id: UUID(), title: "Task C", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: taskC.id,
            steps: [
                (taskA.id, "Task A", false),
                (taskB.id, "Task B", false),
                (taskC.id, "Task C", false)
            ],
            edges: [(0, 2), (1, 2)], // A → C, B → C
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        // When: Task A completes (B still incomplete)
        var updatedPlan = plan
        var graph = updatedPlan.toPlanGraph()
        if let nodeA = graph.nodes.first(where: { $0.assignmentId == taskA.id }) {
            graph.markNodeCompleted(nodeA.id)
            updatedPlan.applyPlanGraph(graph)
            planStore.savePlan(updatedPlan)
        }
        
        let newlyUnblocked = PlanGraphSchedulerIntegration.getNewlyUnblockedTasks(
            after: taskA.id,
            from: [taskA, taskB, taskC],
            planStore: planStore
        )
        
        // Then: Task C is NOT unblocked (still needs B)
        XCTAssertEqual(newlyUnblocked.count, 0)
    }
    
    // MARK: - Block Validation Tests
    
    func testIsScheduledBlockValid_TaskCompleted_Invalid() {
        // Given: Scheduled block for completed task
        let task = createTask(id: UUID(), title: "Task 1", isCompleted: true)
        let block = ScheduledBlock(
            id: UUID(),
            taskId: task.id,
            start: Date(),
            end: Date().addingTimeInterval(3600)
        )
        
        // When: Validating block
        let isValid = PlanGraphSchedulerIntegration.isScheduledBlockValid(
            block,
            allTasks: [task],
            planStore: planStore
        )
        
        // Then: Block is invalid
        XCTAssertFalse(isValid)
    }
    
    func testIsScheduledBlockValid_TaskBlocked_Invalid() {
        // Given: Task 2 blocked by incomplete Task 1, but has scheduled block
        let task1 = createTask(id: UUID(), title: "Task 1", isCompleted: false)
        let task2 = createTask(id: UUID(), title: "Task 2", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: task2.id,
            steps: [
                (task1.id, "Task 1", false),
                (task2.id, "Task 2", false)
            ],
            edges: [(0, 1)],
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        let block = ScheduledBlock(
            id: UUID(),
            taskId: task2.id,
            start: Date(),
            end: Date().addingTimeInterval(3600)
        )
        
        // When: Validating block
        let isValid = PlanGraphSchedulerIntegration.isScheduledBlockValid(
            block,
            allTasks: [task1, task2],
            planStore: planStore
        )
        
        // Then: Block is invalid (task is blocked)
        XCTAssertFalse(isValid)
    }
    
    func testIsScheduledBlockValid_TaskUnblocked_Valid() {
        // Given: Task 2 with prerequisite complete
        let task1 = createTask(id: UUID(), title: "Task 1", isCompleted: true)
        let task2 = createTask(id: UUID(), title: "Task 2", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: task2.id,
            steps: [
                (task1.id, "Task 1", true),
                (task2.id, "Task 2", false)
            ],
            edges: [(0, 1)],
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        let block = ScheduledBlock(
            id: UUID(),
            taskId: task2.id,
            start: Date(),
            end: Date().addingTimeInterval(3600)
        )
        
        // When: Validating block
        let isValid = PlanGraphSchedulerIntegration.isScheduledBlockValid(
            block,
            allTasks: [task1, task2],
            planStore: planStore
        )
        
        // Then: Block is valid
        XCTAssertTrue(isValid)
    }
    
    func testRemoveInvalidBlocks() {
        // Given: Schedule with mix of valid and invalid blocks
        let task1 = createTask(id: UUID(), title: "Task 1", isCompleted: false)
        let task2 = createTask(id: UUID(), title: "Task 2", isCompleted: false)
        let task3 = createTask(id: UUID(), title: "Task 3", isCompleted: true) // Completed
        
        let plan = createPlanWithDependencies(
            assignmentId: task2.id,
            steps: [
                (task1.id, "Task 1", false),
                (task2.id, "Task 2", false)
            ],
            edges: [(0, 1)],
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        let validBlock = ScheduledBlock(id: UUID(), taskId: task1.id, start: Date(), end: Date().addingTimeInterval(3600))
        let invalidBlock1 = ScheduledBlock(id: UUID(), taskId: task2.id, start: Date(), end: Date().addingTimeInterval(3600)) // Blocked
        let invalidBlock2 = ScheduledBlock(id: UUID(), taskId: task3.id, start: Date(), end: Date().addingTimeInterval(3600)) // Completed
        
        let result = ScheduleResult(
            blocks: [validBlock, invalidBlock1, invalidBlock2],
            unscheduledTasks: [],
            log: []
        )
        
        // When: Removing invalid blocks
        let cleaned = PlanGraphSchedulerIntegration.removeInvalidBlocks(
            from: result,
            allTasks: [task1, task2, task3],
            planStore: planStore
        )
        
        // Then: Only valid block remains
        XCTAssertEqual(cleaned.blocks.count, 1)
        XCTAssertEqual(cleaned.blocks.first?.taskId, task1.id)
        XCTAssertTrue(cleaned.log.contains { $0.contains("Removed 2 invalid blocks") })
    }
    
    // MARK: - Blocked Reason Tests
    
    func testGetBlockedReason_SinglePrerequisite() {
        // Given: Task blocked by single prerequisite
        let task1 = createTask(id: UUID(), title: "Read Chapter 1", isCompleted: false)
        let task2 = createTask(id: UUID(), title: "Practice Quiz", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: task2.id,
            steps: [
                (task1.id, "Read Chapter 1", false),
                (task2.id, "Practice Quiz", false)
            ],
            edges: [(0, 1)],
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        // When: Getting blocked reason
        let reason = PlanGraphSchedulerIntegration.getBlockedReason(for: task2.id, planStore: planStore)
        
        // Then: Reason mentions the prerequisite
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason?.contains("Read Chapter 1") ?? false)
    }
    
    func testGetBlockedReason_MultiplePrerequisites() {
        // Given: Task blocked by multiple prerequisites
        let task1 = createTask(id: UUID(), title: "Task 1", isCompleted: false)
        let task2 = createTask(id: UUID(), title: "Task 2", isCompleted: false)
        let task3 = createTask(id: UUID(), title: "Task 3", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: task3.id,
            steps: [
                (task1.id, "Task 1", false),
                (task2.id, "Task 2", false),
                (task3.id, "Task 3", false)
            ],
            edges: [(0, 2), (1, 2)],
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        // When: Getting blocked reason
        let reason = PlanGraphSchedulerIntegration.getBlockedReason(for: task3.id, planStore: planStore)
        
        // Then: Reason mentions count
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason?.contains("2") ?? false)
        XCTAssertTrue(reason?.contains("prerequisites") ?? false)
    }
    
    func testGetBlockedReason_NotBlocked_ReturnsNil() {
        // Given: Task with no dependencies
        let task = createTask(id: UUID(), title: "Task 1", isCompleted: false)
        
        // When: Getting blocked reason
        let reason = PlanGraphSchedulerIntegration.getBlockedReason(for: task.id, planStore: planStore)
        
        // Then: No reason (not blocked)
        XCTAssertNil(reason)
    }
    
    // MARK: - Statistics Tests
    
    func testGetSchedulingStatistics() {
        // Given: Mix of tasks with different states
        let task1 = createTask(id: UUID(), title: "Task 1", isCompleted: true)
        let task2 = createTask(id: UUID(), title: "Task 2", isCompleted: false)
        let task3 = createTask(id: UUID(), title: "Task 3", isCompleted: false)
        let task4 = createTask(id: UUID(), title: "Task 4", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: task3.id,
            steps: [
                (task2.id, "Task 2", false),
                (task3.id, "Task 3", false)
            ],
            edges: [(0, 1)],
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        // When: Getting statistics
        let stats = PlanGraphSchedulerIntegration.getSchedulingStatistics(
            for: [task1, task2, task3, task4],
            planStore: planStore
        )
        
        // Then: Statistics are correct
        XCTAssertEqual(stats["total_tasks"], 4)
        XCTAssertEqual(stats["completed_tasks"], 1)
        XCTAssertEqual(stats["schedulable_tasks"], 2) // task2, task4
        XCTAssertEqual(stats["blocked_tasks"], 1) // task3
        XCTAssertEqual(stats["tasks_with_dependencies"], 1) // task3
        XCTAssertEqual(stats["tasks_without_dependencies"], 2) // task2, task4
    }
    
    // MARK: - Integration Tests
    
    func testDependencyAwareSchedule_BlockedTasksNotScheduled() {
        // Given: Tasks with dependencies
        let task1 = createTask(id: UUID(), title: "Task 1", estimatedMinutes: 60, isCompleted: false)
        let task2 = createTask(id: UUID(), title: "Task 2", estimatedMinutes: 60, isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: task2.id,
            steps: [
                (task1.id, "Task 1", false),
                (task2.id, "Task 2", false)
            ],
            edges: [(0, 1)],
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        let constraints = createConstraints()
        
        // When: Generating schedule
        let result = AIScheduler.generateDependencyAwareSchedule(
            tasks: [task1, task2],
            fixedEvents: [],
            constraints: constraints,
            planStore: planStore
        )
        
        // Then: Only task 1 is scheduled (task 2 is blocked)
        let scheduledTaskIds = Set(result.blocks.map(\.taskId))
        XCTAssertTrue(scheduledTaskIds.contains(task1.id))
        XCTAssertFalse(scheduledTaskIds.contains(task2.id))
        XCTAssertTrue(result.unscheduledTasks.contains(where: { $0.id == task2.id }))
    }
    
    func testCompleteTaskAndAutoUnblock() {
        // Given: Task B blocked by Task A
        let taskA = createTask(id: UUID(), title: "Task A", isCompleted: false)
        let taskB = createTask(id: UUID(), title: "Task B", isCompleted: false)
        
        let plan = createPlanWithDependencies(
            assignmentId: taskB.id,
            steps: [
                (taskA.id, "Task A", false),
                (taskB.id, "Task B", false)
            ],
            edges: [(0, 1)],
            enforcementEnabled: true
        )
        
        planStore.savePlan(plan)
        
        // When: Completing task A
        let newlyUnblocked = planStore.completeTaskAndAutoUnblock(taskA.id, allTasks: [taskA, taskB])
        
        // Then: Task B is unblocked
        XCTAssertEqual(newlyUnblocked.count, 1)
        XCTAssertEqual(newlyUnblocked.first, taskB.id)
        
        // Verify task B is now schedulable
        let schedulable = PlanGraphSchedulerIntegration.getSchedulableTasks([taskA, taskB], planStore: planStore)
        XCTAssertTrue(schedulable.contains(where: { $0.id == taskB.id }))
    }
    
    // MARK: - Helper Methods
    
    private func createTask(
        id: UUID,
        title: String,
        estimatedMinutes: Int = 60,
        isCompleted: Bool = false
    ) -> AppTask {
        AppTask(
            id: id,
            title: title,
            courseId: UUID(),
            due: Date().addingTimeInterval(86400 * 7),
            estimatedMinutes: estimatedMinutes,
            minBlockMinutes: 25,
            maxBlockMinutes: 90,
            difficulty: 0.5,
            importance: 0.5,
            type: .project,
            locked: false,
            isCompleted: isCompleted
        )
    }
    
    private func createPlanWithDependencies(
        assignmentId: UUID,
        steps: [(UUID, String, Bool)], // (id, title, isCompleted)
        edges: [(Int, Int)], // (fromIndex, toIndex)
        enforcementEnabled: Bool
    ) -> AssignmentPlan {
        var plan = AssignmentPlan(
            id: UUID(),
            assignmentId: assignmentId,
            courseId: UUID(),
            dueDate: Date().addingTimeInterval(86400 * 7),
            generatedAt: Date(),
            steps: [],
            estimatedCompletionDate: Date(),
            status: .active,
            version: 1
        )
        
        // Create steps
        var planSteps: [PlanStep] = []
        for (index, (stepId, title, isCompleted)) in steps.enumerated() {
            let step = PlanStep(
                id: UUID(),
                assignmentId: stepId,
                title: title,
                stepType: .task,
                estimatedDuration: 60,
                sequenceIndex: index,
                prerequisiteIds: [],
                notes: nil,
                recommendedStartDate: nil,
                dueBy: nil,
                isCompleted: isCompleted,
                completedAt: isCompleted ? Date() : nil
            )
            planSteps.append(step)
        }
        
        // Add edges as prerequisites
        for (fromIdx, toIdx) in edges {
            planSteps[toIdx].prerequisiteIds.append(planSteps[fromIdx].id)
        }
        
        plan.steps = planSteps
        plan.sequenceEnforcementEnabled = enforcementEnabled
        
        return plan
    }
    
    private func createConstraints() -> Constraints {
        let now = Date()
        let end = now.addingTimeInterval(86400 * 7)
        
        return Constraints(
            horizonStart: now,
            horizonEnd: end,
            dayStartHour: 9,
            dayEndHour: 21,
            maxStudyMinutesPerDay: 360,
            maxStudyMinutesPerBlock: 90,
            minGapBetweenBlocksMinutes: 10,
            doNotScheduleWindows: [],
            energyProfile: [:]
        )
    }
}
