import Foundation
import Combine

struct StoredScheduledSession: Identifiable, Codable, Hashable {
    let id: UUID
    let assignmentId: UUID?
    let title: String
    let dueDate: Date
    let estimatedMinutes: Int
    let isLockedToDueDate: Bool
    let category: AssignmentCategory?
    let start: Date
    let end: Date
}

struct StoredOverflowSession: Identifiable, Codable, Hashable {
    let id: UUID
    let assignmentId: UUID?
    let title: String
    let dueDate: Date
    let estimatedMinutes: Int
    let isLockedToDueDate: Bool
    let category: AssignmentCategory?
}

@MainActor
final class PlannerStore: ObservableObject {
    static let shared = PlannerStore()

    @Published var isLoading: Bool = true
    @Published private(set) var scheduled: [StoredScheduledSession] = []
    @Published private(set) var overflow: [StoredOverflowSession] = []

    private let storageURL: URL

    private init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("RootsPlanner", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        self.storageURL = folder.appendingPathComponent("planner_sessions.json")
        load()
        isLoading = false
    }

    func persist(scheduled: [ScheduledSession], overflow: [PlannerSession]) {
        self.scheduled = scheduled.map {
            StoredScheduledSession(
                id: $0.id,
                assignmentId: $0.session.assignmentId,
                title: $0.session.title,
                dueDate: $0.session.dueDate,
                estimatedMinutes: $0.session.estimatedMinutes,
                isLockedToDueDate: $0.session.isLockedToDueDate,
                category: $0.session.category,
                start: $0.start,
                end: $0.end
            )
        }
        self.overflow = overflow.map {
            StoredOverflowSession(
                id: $0.id,
                assignmentId: $0.assignmentId,
                title: $0.title,
                dueDate: $0.dueDate,
                estimatedMinutes: $0.estimatedMinutes,
                isLockedToDueDate: $0.isLockedToDueDate,
                category: $0.category
            )
        }
        save()
    }

    func reset() {
        scheduled.removeAll()
        overflow.removeAll()
        save()
    }

    private func save() {
        do {
            let payload = Persisted(scheduled: scheduled, overflow: overflow)
            let data = try JSONEncoder().encode(payload)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            print("Failed to save planner sessions: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let payload = try JSONDecoder().decode(Persisted.self, from: data)
            scheduled = payload.scheduled
            overflow = payload.overflow
        } catch {
            print("Failed to load planner sessions: \(error)")
        }
    }

    private struct Persisted: Codable {
        var scheduled: [StoredScheduledSession]
        var overflow: [StoredOverflowSession]
    }
}
