import SwiftUI
import Combine

struct Course: Identifiable, Hashable {
    let id: UUID
    var name: String
    var code: String
    var instructor: String
    var term: String
    var color: Color
    var credits: Int
    var isArchived: Bool
}

final class CoursesStore: ObservableObject {
    @Published var courses: [Course] = []

    func add(_ course: Course) {
        courses.append(course)
    }

    func update(_ course: Course) {
        guard let idx = courses.firstIndex(where: { $0.id == course.id }) else { return }
        courses[idx] = course
    }

    func delete(_ course: Course) {
        courses.removeAll { $0.id == course.id }
    }
}