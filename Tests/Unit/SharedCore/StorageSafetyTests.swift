import XCTest
@testable import Roots

final class StorageSafetyTests: XCTestCase {
    private var originalTasks: [AppTask] = []

    override func setUp() {
        super.setUp()
        originalTasks = AssignmentsStore.shared.tasks
        AssignmentsStore.shared.tasks = []
    }

    override func tearDown() {
        AssignmentsStore.shared.tasks = originalTasks
        super.tearDown()
    }

    @MainActor
    func testDeleteCourseReassignsTasksToUnassignedWithoutLoss() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("storage_safety_\(UUID().uuidString)")
            .appendingPathComponent("courses.json")
        let coursesStore = CoursesStore(storageURL: tempURL)

        let semester = Semester(
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 90),
            isCurrent: true,
            notes: ""
        )
        coursesStore.addSemester(semester)

        let courseId = UUID()
        let course = Course(id: courseId, title: "Biology", code: "BIO101", semesterId: semester.id, isArchived: false)
        coursesStore.addCourse(course)

        let keepTask = AppTask(
            id: UUID(),
            title: "Keep",
            courseId: UUID(),
            due: nil,
            estimatedMinutes: 30,
            minBlockMinutes: 15,
            maxBlockMinutes: 60,
            difficulty: 0.4,
            importance: 0.5,
            type: .reading,
            locked: false
        )
        let reassignedTask = AppTask(
            id: UUID(),
            title: "Reassign",
            courseId: courseId,
            due: nil,
            estimatedMinutes: 45,
            minBlockMinutes: 15,
            maxBlockMinutes: 60,
            difficulty: 0.6,
            importance: 0.7,
            type: .project,
            locked: false
        )
        AssignmentsStore.shared.tasks = [keepTask, reassignedTask]

        coursesStore.deleteCourse(course)

        XCTAssertEqual(AssignmentsStore.shared.tasks.count, 2)
        let updated = AssignmentsStore.shared.tasks.first { $0.id == reassignedTask.id }
        XCTAssertNotNil(updated)
        XCTAssertNil(updated?.courseId)
        let untouched = AssignmentsStore.shared.tasks.first { $0.id == keepTask.id }
        XCTAssertEqual(untouched?.courseId, keepTask.courseId)
    }
}
