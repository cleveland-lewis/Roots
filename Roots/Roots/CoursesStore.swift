import Foundation
import SwiftUI
import Combine

@MainActor
final class CoursesStore: ObservableObject {
    @Published private(set) var semesters: [Semester] = []
    @Published private(set) var courses: [Course] = []

    @Published var currentSemesterId: UUID? {
        didSet {
            markCurrentSemester(currentSemesterId)
            persist()
        }
    }

    private let storageURL: URL

    init(storageURL: URL? = nil) {
        let fm = FileManager.default
        if let storageURL = storageURL {
            self.storageURL = storageURL
            // ensure containing directory exists
            try? fm.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } else {
            let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let folder = dir.appendingPathComponent("RootsCourses", isDirectory: true)
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            self.storageURL = folder.appendingPathComponent("courses.json")
        }

        load()
    }

    // MARK: - Public API

    var currentSemester: Semester? {
        guard let id = currentSemesterId else { return nil }
        return semesters.first(where: { $0.id == id })
    }

    var currentSemesterCourses: [Course] {
        guard let id = currentSemesterId else { return [] }
        return courses.filter { $0.semesterId == id }
    }

    func addSemester(_ semester: Semester) {
        semesters.append(semester)
        if semester.isCurrent {
            currentSemesterId = semester.id
        }
        persist()
    }

    func setCurrentSemester(_ semester: Semester) {
        currentSemesterId = semester.id
    }

    func addCourse(title: String, code: String, to semester: Semester) {
        let newCourse = Course(title: title, code: code, semesterId: semester.id)
        courses.append(newCourse)
        persist()
    }

    func courses(in semester: Semester) -> [Course] {
        courses.filter { $0.semesterId == semester.id }
    }

    // MARK: - Persistence

    private struct PersistedData: Codable {
        var semesters: [Semester]
        var courses: [Course]
        var currentSemesterId: UUID?
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode(PersistedData.self, from: data)
            self.semesters = decoded.semesters
            self.courses = decoded.courses
            self.currentSemesterId = decoded.currentSemesterId
        } catch {
            print("Failed to decode courses data: \(error)")
        }
    }

    private func persist() {
        let snapshot = PersistedData(
            semesters: semesters,
            courses: courses,
            currentSemesterId: currentSemesterId
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            print("Failed to persist courses data: \(error)")
        }
    }

    private func markCurrentSemester(_ id: UUID?) {
        semesters = semesters.map { semester in
            var s = semester
            s.isCurrent = (semester.id == id)
            return s
        }
    }
}
