import Foundation

struct Exam {
    let id: UUID
    let title: String
    let courseId: UUID?
    let dueDate: Date
    let weightPercent: Double?

    init(id: UUID = UUID(), title: String, courseId: UUID?, dueDate: Date, weightPercent: Double? = nil) {
        self.id = id
        self.title = title
        self.courseId = courseId
        self.dueDate = dueDate
        self.weightPercent = weightPercent
    }
}

/// Lightweight planner service focused on generating study blocks for exams/projects.
final class PlannerService {
    static let shared = PlannerService()
    private init() {}

    /// Break an exam down into study tasks and return them in reverse-scheduled order.
    func generateStudyBlocks(for exam: Exam, fileURLs: [URL]) -> [AppTask] {
        let calendar = Calendar.current
        let startOfDay = { (date: Date) -> Date in
            calendar.startOfDay(for: date)
        }
        var generated: [AppTask] = []

        // Helper to find a free day by walking backward until the day has ≤ 4h planned.
        func resolveDate(_ date: Date, estimatedMinutes: Int) -> Date {
            var target = date
            while exceedsDailyLoad(on: target, adding: estimatedMinutes) {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: target) else { break }
                target = previous
            }
            return target
        }

        func exceedsDailyLoad(on date: Date, adding minutes: Int) -> Bool {
            let targetDay = startOfDay(date)
            let existingMinutes = AssignmentsStore.shared.tasks
                .filter { task in
                    guard let due = task.due else { return false }
                    return startOfDay(due) == targetDay
                }
                .reduce(0) { $0 + $1.estimatedMinutes }
            let generatedMinutes = generated
                .filter { task in
                    guard let due = task.due else { return false }
                    return startOfDay(due) == targetDay
                }
                .reduce(0) { $0 + $1.estimatedMinutes }
            return existingMinutes + generatedMinutes + minutes > 240 // 4 hours
        }

        struct BlockDefinition {
            let daysBefore: Int
            let titlePrefix: String
            let estimatedMinutes: Int
        }

        let blocks: [BlockDefinition] = [
            .init(daysBefore: 10, titlePrefix: "Concept Review: ", estimatedMinutes: 90),
            .init(daysBefore: 5, titlePrefix: "Practice Test: ", estimatedMinutes: 120),
            .init(daysBefore: 2, titlePrefix: "Cram / Summary Review: ", estimatedMinutes: 75)
        ]

        for block in blocks {
            guard let rawDate = calendar.date(byAdding: .day, value: -block.daysBefore, to: exam.dueDate) else { continue }
            let scheduledDate = resolveDate(rawDate, estimatedMinutes: block.estimatedMinutes)

            var title = "\(block.titlePrefix)\(exam.title)"
            // Attach resource hint when practice test is available.
            if block.titlePrefix.contains("Practice Test"), let firstFile = fileURLs.first {
                title += " (\(firstFile.lastPathComponent))"
            }

            let task = AppTask(
                id: UUID(),
                title: title,
                courseId: exam.courseId,
                due: scheduledDate,
                estimatedMinutes: block.estimatedMinutes,
                minBlockMinutes: 30,
                maxBlockMinutes: 120,
                difficulty: 0.6,
                importance: 0.8,
                type: .exam,
                locked: block.daysBefore == 2, // cram is high priority; keep tight to date
                attachments: []
            )

            generated.append(task)
        }

        // Sort in reverse scheduling order (closest to exam first).
        generated.sort { (a, b) -> Bool in
            guard let dueA = a.due, let dueB = b.due else { return false }
            return dueA > dueB
        }

        return generated
    }
}
