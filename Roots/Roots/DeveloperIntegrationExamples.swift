import Foundation

// Examples of extreme-issue detection helpers

func assertCriticalDataExists(_ label: String, exists: Bool, details: String? = nil) {
    if !exists {
        LOG_DATA(.fatal, "MissingCriticalData", "\(label) is missing" + (details.map { " - \($0)" } ?? ""))
    }
}

func reportUnschedulableTasks(_ tasks: [String], semesterId: UUID) {
    if !tasks.isEmpty {
        LOG_SCHEDULER(.error, "UnschedulableTasks", "Could not schedule tasks: \(tasks.joined(separator: ", "))", metadata: ["semester": semesterId.uuidString])
    }
}

func reportExamGenerationFailure(courseId: UUID) {
    LOG_PRACTICE(.error, "NoQuestionsForTopic", "No valid questions available for course \(courseId.uuidString)")
}
