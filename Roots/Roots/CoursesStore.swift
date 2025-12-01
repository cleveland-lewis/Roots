import SwiftUI
import Combine

struct Semester: Identifiable, Hashable {
    let id: UUID
    var name: String
}

struct Course: Identifiable, Hashable {
    let id: UUID
    var name: String
    var code: String
    var instructor: String
    var term: String
    var color: Color
    var credits: Int
    var isArchived: Bool
    var semesterId: UUID?
}

final class CoursesStore: ObservableObject {
    @Published var courses: [Course] = []
    @Published var semesters: [Semester] = []
    @Published var currentSemesterId: UUID? = nil

    var currentSemesterCourses: [Course] {
        guard let sid = currentSemesterId else { return [] }
        return courses.filter { $0.semesterId == sid && !$0.isArchived }
    }

    // Semester management
    func addSemester(_ semester: Semester) {
        semesters.append(semester)
    }

    func setCurrentSemester(_ id: UUID?) {
        currentSemesterId = id
    }

    // Course CRUD
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
