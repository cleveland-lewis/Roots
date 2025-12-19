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
    let type: ScheduleBlockType
    let isLocked: Bool
    let isUserEdited: Bool

    init(id: UUID,
         assignmentId: UUID?,
         title: String,
         dueDate: Date,
         estimatedMinutes: Int,
         isLockedToDueDate: Bool,
         category: AssignmentCategory?,
         start: Date,
         end: Date,
         type: ScheduleBlockType = .task,
         isLocked: Bool = false,
         isUserEdited: Bool = false) {
        self.id = id
        self.assignmentId = assignmentId
        self.title = title
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.isLockedToDueDate = isLockedToDueDate
        self.category = category
        self.start = start
        self.end = end
        self.type = type
        self.isLocked = isLocked
        self.isUserEdited = isUserEdited
    }

    private enum CodingKeys: String, CodingKey {
        case id, assignmentId, title, dueDate, estimatedMinutes, isLockedToDueDate, category, start, end, type, isLocked, isUserEdited
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        assignmentId = try container.decodeIfPresent(UUID.self, forKey: .assignmentId)
        title = try container.decode(String.self, forKey: .title)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        estimatedMinutes = try container.decode(Int.self, forKey: .estimatedMinutes)
        isLockedToDueDate = try container.decode(Bool.self, forKey: .isLockedToDueDate)
        category = try container.decodeIfPresent(AssignmentCategory.self, forKey: .category)
        start = try container.decode(Date.self, forKey: .start)
        end = try container.decode(Date.self, forKey: .end)
        type = try container.decodeIfPresent(ScheduleBlockType.self, forKey: .type) ?? .task
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        isUserEdited = try container.decodeIfPresent(Bool.self, forKey: .isUserEdited) ?? false
    }
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

enum ScheduleBlockType: String, Codable, CaseIterable {
    case task
    case event
    case study
    case breakTime
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
        let preserved = Dictionary(grouping: self.scheduled.filter { $0.isUserEdited }, by: {
            PlannerSessionKey(assignmentId: $0.assignmentId, title: $0.title)
        })
        self.scheduled = scheduled.map {
            var mapped = StoredScheduledSession(
                id: $0.id,
                assignmentId: $0.session.assignmentId,
                title: $0.session.title,
                dueDate: $0.session.dueDate,
                estimatedMinutes: $0.session.estimatedMinutes,
                isLockedToDueDate: $0.session.isLockedToDueDate,
                category: $0.session.category,
                start: $0.start,
                end: $0.end,
                type: .task,
                isLocked: $0.session.isLockedToDueDate,
                isUserEdited: false
            )
            if let match = preserved[PlannerSessionKey(assignmentId: mapped.assignmentId, title: mapped.title)]?.first {
                mapped = StoredScheduledSession(
                    id: mapped.id,
                    assignmentId: mapped.assignmentId,
                    title: mapped.title,
                    dueDate: mapped.dueDate,
                    estimatedMinutes: mapped.estimatedMinutes,
                    isLockedToDueDate: mapped.isLockedToDueDate,
                    category: mapped.category,
                    start: match.start,
                    end: match.end,
                    type: match.type,
                    isLocked: match.isLocked,
                    isUserEdited: true
                )
            }
            return mapped
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

    private struct PlannerSessionKey: Hashable {
        let assignmentId: UUID?
        let title: String
    }

    func updateScheduledSession(_ updated: StoredScheduledSession) {
        guard let idx = scheduled.firstIndex(where: { $0.id == updated.id }) else { return }
        scheduled[idx] = updated
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
