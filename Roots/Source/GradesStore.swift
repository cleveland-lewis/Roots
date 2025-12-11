import Foundation
import Combine

struct GradeEntry: Identifiable, Codable, Hashable {
    var id: UUID { courseId }
    let courseId: UUID
    var percent: Double?
    var letter: String?
    var updatedAt: Date
}

@MainActor
final class GradesStore: ObservableObject {
    static let shared = GradesStore()

    @Published var isLoading: Bool = true
    @Published private(set) var grades: [GradeEntry] = []

    private let storageURL: URL

    private init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("RootsGrades", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        self.storageURL = folder.appendingPathComponent("grades.json")
        load()
        isLoading = false
    }

    func grade(for courseId: UUID) -> GradeEntry? {
        grades.first { $0.courseId == courseId }
    }

    func upsert(courseId: UUID, percent: Double?, letter: String?) {
        let now = Date()
        if let idx = grades.firstIndex(where: { $0.courseId == courseId }) {
            grades[idx].percent = percent
            grades[idx].letter = letter
            grades[idx].updatedAt = now
        } else {
            grades.append(GradeEntry(courseId: courseId, percent: percent, letter: letter, updatedAt: now))
        }
        save()
    }

    func remove(courseId: UUID) {
        grades.removeAll { $0.courseId == courseId }
        save()
    }

    func resetAll() {
        grades.removeAll()
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(grades)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            print("Failed to save grades: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode([GradeEntry].self, from: data)
            grades = decoded
        } catch {
            print("Failed to load grades: \(error)")
        }
    }
}
