import XCTest
@testable import SharedCore

final class PlanGraphSchedulerIntegrationTests: XCTestCase {
    private let planStore = AssignmentPlanStore.shared
    private var planAssignmentId: UUID?

    override func tearDown() {
        if let id = planAssignmentId {
            planStore.deletePlan(for: id)
        }
        super.tearDown()
    }

    func testBlockedTasksAreExcludedFromScheduling() {
        let taskId = UUID()
        planAssignmentId = taskId
        planStore.savePlan(makePlanWithBlockedFirstNode(assignmentId: taskId))

        let tasks = [makeTask(id: taskId, dueInDays: 2)]
        let schedulable = PlanGraphSchedulerIntegration.getSchedulableTasks(tasks, planStore: planStore)

        XCTAssertTrue(schedulable.isEmpty)
    }

    func testCompletingPrereqUnblocksTask() {
        let taskId = UUID()
        planAssignmentId = taskId
        planStore.savePlan(makePlanWithCompletedPrereq(assignmentId: taskId))

        let tasks = [makeTask(id: taskId, dueInDays: 2)]
        let schedulable = PlanGraphSchedulerIntegration.getSchedulableTasks(tasks, planStore: planStore)

        XCTAssertEqual(schedulable.map(\.id), [taskId])
    }

    func testDependencyAwareScheduleDeterministic() {
        let start = Calendar.current.startOfDay(for: Date())
        let constraints = makeConstraints(start: start)
        let tasks = [
            makeTask(id: UUID(), dueInDays: 1),
            makeTask(id: UUID(), dueInDays: 2)
        ]

        let resultA = AIScheduler.generateDependencyAwareSchedule(
            tasks: tasks,
            fixedEvents: [],
            constraints: constraints,
            planStore: planStore
        )
        let resultB = AIScheduler.generateDependencyAwareSchedule(
            tasks: tasks,
            fixedEvents: [],
            constraints: constraints,
            planStore: planStore
        )

        XCTAssertEqual(resultA.blocks, resultB.blocks)
        XCTAssertEqual(resultA.unscheduledTasks.map(\.id), resultB.unscheduledTasks.map(\.id))
    }

    func testBlockedTasksRemainUnscheduled() {
        let taskId = UUID()
        planAssignmentId = taskId
        planStore.savePlan(makePlanWithBlockedFirstNode(assignmentId: taskId))

        let start = Calendar.current.startOfDay(for: Date())
        let constraints = makeConstraints(start: start)
        let tasks = [makeTask(id: taskId, dueInDays: 2)]

        let result = AIScheduler.generateDependencyAwareSchedule(
            tasks: tasks,
            fixedEvents: [],
            constraints: constraints,
            planStore: planStore
        )

        XCTAssertTrue(result.blocks.isEmpty)
        XCTAssertEqual(result.unscheduledTasks.map(\.id), [taskId])
    }

    private func makePlanWithBlockedFirstNode(assignmentId: UUID) -> AssignmentPlan {
        let planId = UUID()
        let prereqId = UUID()
        let blockedId = UUID()

        let blocked = PlanStep(
            id: blockedId,
            planId: planId,
            title: "Blocked",
            estimatedDuration: 1800,
            sequenceIndex: 0,
            isCompleted: false,
            prerequisiteIds: [prereqId]
        )
        let prereq = PlanStep(
            id: prereqId,
            planId: planId,
            title: "Prereq",
            estimatedDuration: 1800,
            sequenceIndex: 1,
            isCompleted: false
        )

        return AssignmentPlan(
            id: planId,
            assignmentId: assignmentId,
            status: .active,
            steps: [blocked, prereq],
            sequenceEnforcementEnabled: true
        )
    }

    private func makePlanWithCompletedPrereq(assignmentId: UUID) -> AssignmentPlan {
        let planId = UUID()
        let prereqId = UUID()
        let blockedId = UUID()

        let prereq = PlanStep(
            id: prereqId,
            planId: planId,
            title: "Prereq",
            estimatedDuration: 1800,
            sequenceIndex: 0,
            isCompleted: true
        )
        let blocked = PlanStep(
            id: blockedId,
            planId: planId,
            title: "Blocked",
            estimatedDuration: 1800,
            sequenceIndex: 1,
            isCompleted: false,
            prerequisiteIds: [prereqId]
        )

        return AssignmentPlan(
            id: planId,
            assignmentId: assignmentId,
            status: .active,
            steps: [prereq, blocked],
            sequenceEnforcementEnabled: true
        )
    }

    private func makeTask(id: UUID, dueInDays: Int) -> AppTask {
        let due = Calendar.current.date(byAdding: .day, value: dueInDays, to: Date())
        return AppTask(
            id: id,
            title: "Task \(id.uuidString.prefix(4))",
            courseId: nil,
            due: due,
            estimatedMinutes: 60,
            minBlockMinutes: 30,
            maxBlockMinutes: 60,
            difficulty: 0.5,
            importance: 0.6,
            type: .practiceHomework,
            locked: false
        )
    }

    private func makeConstraints(start: Date) -> Constraints {
        Constraints(
            horizonStart: start,
            horizonEnd: Calendar.current.date(byAdding: .day, value: 3, to: start) ?? start,
            dayStartHour: 8,
            dayEndHour: 20,
            maxStudyMinutesPerDay: 240,
            maxStudyMinutesPerBlock: 120,
            minGapBetweenBlocksMinutes: 0,
            doNotScheduleWindows: [],
            energyProfile: [
                8: 0.6, 9: 0.7, 10: 0.75, 11: 0.7,
                12: 0.65, 13: 0.6, 14: 0.6, 15: 0.65,
                16: 0.7, 17: 0.6, 18: 0.5, 19: 0.45, 20: 0.4
            ]
        )
    }
}
