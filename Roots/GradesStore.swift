import SwiftUI
import Combine

struct GradeRecord: Identifiable, Codable {
    let id: UUID
    let courseId: UUID
    var percent: Double
    var letter: String
    var updatedAt: Date
    
    init(id: UUID = UUID(), courseId: UUID, percent: Double, letter: String, updatedAt: Date = Date()) {
        self.id = id
        self.courseId = courseId
        self.percent = percent
        self.letter = letter
        self.updatedAt = updatedAt
    }
}

@MainActor
final class GradesStore: ObservableObject {
    static let shared = GradesStore()
    
    @Published var grades: [GradeRecord] = []
    @Published var isLoading: Bool = false
    
    private init() {
        load()
    }
    
    func grade(for courseId: UUID) -> GradeRecord? {
        return grades.first { $0.courseId == courseId }
    }
    
    func upsert(courseId: UUID, percent: Double, letter: String) {
        if let index = grades.firstIndex(where: { $0.courseId == courseId }) {
            grades[index].percent = percent
            grades[index].letter = letter
            grades[index].updatedAt = Date()
        } else {
            let newGrade = GradeRecord(courseId: courseId, percent: percent, letter: letter)
            grades.append(newGrade)
        }
        persist()
    }
    
    func removeGrade(for courseId: UUID) {
        grades.removeAll { $0.courseId == courseId }
        persist()
    }
    
    // MARK: - Persistence
    
    private func persist() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(grades) {
            UserDefaults.standard.set(data, forKey: "roots.grades.records")
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "roots.grades.records") else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([GradeRecord].self, from: data) {
            grades = decoded
        }
    }
}
