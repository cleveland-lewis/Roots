import Foundation

@MainActor
enum StorageRetentionManager {
    struct Result {
        let deletedCount: Int
        let deletedByType: [StorageEntityType: Int]
    }

    static func apply(
        policy: StorageRetentionPolicy,
        coursesStore: CoursesStore,
        assignmentsStore: AssignmentsStore,
        practiceStore: PracticeTestStore,
        aggregateStore: StorageAggregateStore = .shared,
        now: Date = Date()
    ) -> Result {
        guard policy != .never else {
            return Result(deletedCount: 0, deletedByType: [:])
        }

        var deletedByType: [StorageEntityType: Int] = [:]

        func recordDeletion(type: StorageEntityType, date: Date) {
            aggregateStore.recordDeletion(type: type, date: date)
            deletedByType[type, default: 0] += 1
        }

        let semesterMap: [UUID: Semester] = Dictionary(uniqueKeysWithValues: coursesStore.semesters.map { ($0.id, $0) })
        let courseMap: [UUID: Course] = Dictionary(uniqueKeysWithValues: coursesStore.courses.map { ($0.id, $0) })

        let expiredSemesterIds: Set<UUID> = {
            if policy.isSemesterBased {
                return Set(
                    coursesStore.semesters
                        .filter { policy.isExpired(primaryDate: $0.endDate, semesterEnd: $0.endDate, now: now) }
                        .map(\.id)
                )
            }
            return []
        }()

        // Courses + related data
        for course in coursesStore.courses {
            let semesterEnd = semesterMap[course.semesterId]?.endDate
            let primaryDate = semesterEnd ?? now
            let isExpired = policy.isSemesterBased
                ? expiredSemesterIds.contains(course.semesterId)
                : policy.isExpired(primaryDate: primaryDate, semesterEnd: semesterEnd, now: now)

            guard isExpired else { continue }
            recordDeletion(type: .course, date: primaryDate)
            coursesStore.deleteCourse(course)
            coursesStore.deleteCourseAssets(courseId: course.id)
        }

        // Semesters
        for semester in coursesStore.semesters {
            let isExpired = policy.isSemesterBased
                ? expiredSemesterIds.contains(semester.id)
                : policy.isExpired(primaryDate: semester.endDate, semesterEnd: semester.endDate, now: now)
            guard isExpired else { continue }
            recordDeletion(type: .semester, date: semester.endDate)
            coursesStore.permanentlyDeleteSemester(semester.id)
        }

        // Assignments
        for task in assignmentsStore.tasks {
            let course = task.courseId.flatMap { courseMap[$0] }
            let semesterEnd = course.flatMap { semesterMap[$0.semesterId]?.endDate }
            let primaryDate = task.due ?? now
            let isExpired = policy.isSemesterBased
                ? (course?.semesterId).map { expiredSemesterIds.contains($0) } ?? false
                : policy.isExpired(primaryDate: primaryDate, semesterEnd: semesterEnd, now: now)
            guard isExpired else { continue }
            recordDeletion(type: .assignment, date: primaryDate)
            assignmentsStore.removeTask(id: task.id)
        }

        // Practice tests
        for test in practiceStore.tests {
            let course = courseMap[test.courseId]
            let semesterEnd = course.flatMap { semesterMap[$0.semesterId]?.endDate }
            let primaryDate = test.createdAt
            let isExpired = policy.isSemesterBased
                ? (course?.semesterId).map { expiredSemesterIds.contains($0) } ?? false
                : policy.isExpired(primaryDate: primaryDate, semesterEnd: semesterEnd, now: now)
            guard isExpired else { continue }
            recordDeletion(type: .practiceTest, date: primaryDate)
            practiceStore.deleteTest(test.id)
        }

        // Course outline nodes
        for node in coursesStore.outlineNodes {
            let course = courseMap[node.courseId]
            let semesterEnd = course.flatMap { semesterMap[$0.semesterId]?.endDate }
            let primaryDate = node.createdAt
            let isExpired = policy.isSemesterBased
                ? (course?.semesterId).map { expiredSemesterIds.contains($0) } ?? false
                : policy.isExpired(primaryDate: primaryDate, semesterEnd: semesterEnd, now: now)
            guard isExpired else { continue }
            recordDeletion(type: .courseOutline, date: primaryDate)
            coursesStore.deleteOutlineNode(node.id)
        }

        // Course files
        for file in coursesStore.courseFiles {
            let course = courseMap[file.courseId]
            let semesterEnd = course.flatMap { semesterMap[$0.semesterId]?.endDate }
            let primaryDate = file.createdAt
            let isExpired = policy.isSemesterBased
                ? (course?.semesterId).map { expiredSemesterIds.contains($0) } ?? false
                : policy.isExpired(primaryDate: primaryDate, semesterEnd: semesterEnd, now: now)
            guard isExpired else { continue }
            recordDeletion(type: .courseFile, date: primaryDate)
            coursesStore.deleteFile(file.id)
        }

        let deletedCount = deletedByType.values.reduce(0, +)
        return Result(deletedCount: deletedCount, deletedByType: deletedByType)
    }
}
