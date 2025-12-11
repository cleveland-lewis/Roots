import Foundation

enum FeedbackAction: String, Codable {
    case kept
    case rescheduled
    case deleted
    case shortened
    case extended
}

struct BlockFeedback: Codable {
    let blockId: UUID
    let taskId: UUID
    let courseId: UUID?
    let type: TaskType
    let start: Date
    let end: Date
    let completion: Double   // 0.0–1.0
    let action: FeedbackAction
}

final class SchedulerFeedbackStore {
    static let shared = SchedulerFeedbackStore()
    private init() { loadFromDisk() }

    private(set) var feedback: [BlockFeedback] = []
    private var fileURL: URL? = {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let appDir = dir.appendingPathComponent("Roots", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("scheduler_feedback.json")
    }()

    func append(_ item: BlockFeedback) {
        feedback.append(item)
        saveToDisk()
    }

    func loadFromDisk() {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            feedback = try decoder.decode([BlockFeedback].self, from: data)
        } catch {
            print("Failed to load feedback: \(error)")
            feedback = []
        }
    }

    func saveToDisk() {
        guard let url = fileURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(feedback)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            print("Failed to save feedback: \(error)")
        }
    }

    func clear() {
        feedback = []
        saveToDisk()
    }
}
