import Foundation
import _Concurrency

enum SyllabusParser {
    static func parseDates(from url: URL, courseId: UUID? = nil) async -> [AppTask] {
        // Simulate parsing delay (2 seconds)
        try? await _Concurrency.Task.sleep(nanoseconds: 2_000_000_000)

        let now = Date()
        let midtermDue = Calendar.current.date(byAdding: .day, value: 14, to: now)
        let finalDue = Calendar.current.date(byAdding: .day, value: 45, to: now)

        let midterm = AppTask(
            id: UUID(),
            title: "Midterm Exam (Parsed)",
            courseId: courseId,
            due: midtermDue,
            estimatedMinutes: 90,
            minBlockMinutes: 45,
            maxBlockMinutes: 90,
            difficulty: 0.6,
            importance: 0.9,
            type: .exam,
            locked: false,
            attachments: [],
            isCompleted: false
        )

        let finalProject = AppTask(
            id: UUID(),
            title: "Final Project (Parsed)",
            courseId: courseId,
            due: finalDue,
            estimatedMinutes: 240,
            minBlockMinutes: 60,
            maxBlockMinutes: 120,
            difficulty: 0.7,
            importance: 1.0,
            type: .project,
            locked: false,
            attachments: [],
            isCompleted: false
        )

        return [midterm, finalProject]
    }
}
