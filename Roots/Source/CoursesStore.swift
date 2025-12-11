import Foundation
import SwiftUI
import Combine

@MainActor
final class CoursesStore: ObservableObject {
    static weak var shared: CoursesStore?
    // Publishes course deleted events
    fileprivate let courseDeleted = PassthroughSubject<UUID, Never>()

    @Published private(set) var semesters: [Semester] = []
    @Published private(set) var courses: [Course] = []
    @Published private(set) var currentGPA: Double = 0

    @Published var currentSemesterId: UUID? {
        didSet {
            markCurrentSemester(currentSemesterId)
            persist()
        }
    }

    private let storageURL: URL
    private let cacheURL: URL

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
        let cacheFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("RootsCourses", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        self.cacheURL = cacheFolder.appendingPathComponent("courses_cache.json")

        loadCache()
        load()
        cleanupOldData()
        CoursesStore.shared = self
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    // MARK: - Public API

    var currentSemester: Semester? {
        guard let id = currentSemesterId else { return nil }
        return semesters.first(where: { $0.id == id && $0.deletedAt == nil })
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

    func toggleCurrentSemester(_ semester: Semester) {
        if semester.id == currentSemesterId {
            currentSemesterId = nil
        } else {
            setCurrentSemester(semester)
        }
    }

    func addCourse(title: String, code: String, to semester: Semester) {
        let newCourse = Course(title: title, code: code, semesterId: semester.id, isArchived: false)
        courses.append(newCourse)
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func resetAll() {
        semesters.removeAll()
        courses.removeAll()
        currentSemesterId = nil
        try? FileManager.default.removeItem(at: storageURL)
        try? FileManager.default.removeItem(at: cacheURL)
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func addCourse(_ course: Course) {
        courses.append(course)
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func updateCourse(_ course: Course) {
        guard let idx = courses.firstIndex(where: { $0.id == course.id }) else { return }
        courses[idx] = course
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func toggleArchiveCourse(_ course: Course) {
        guard let idx = courses.firstIndex(where: { $0.id == course.id }) else { return }
        courses[idx].isArchived.toggle()
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func deleteCourse(_ course: Course) {
        courses.removeAll { $0.id == course.id }
        // Publish course deleted event via Combine for subscribers
        courseDeleted.send(course.id)
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func courses(in semester: Semester) -> [Course] {
        courses.filter { $0.semesterId == semester.id }
    }

    var activeCourses: [Course] {
        courses.filter { !$0.isArchived }
    }

    var archivedCourses: [Course] {
        courses.filter { $0.isArchived }
    }

    // MARK: - Semester Management

    func updateSemester(_ semester: Semester) {
        guard let idx = semesters.firstIndex(where: { $0.id == semester.id }) else { return }
        semesters[idx] = semester
        persist()
    }

    func toggleArchiveSemester(_ semester: Semester) {
        guard let idx = semesters.firstIndex(where: { $0.id == semester.id }) else { return }
        semesters[idx].isArchived.toggle()
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func deleteSemester(_ id: UUID) {
        guard let idx = semesters.firstIndex(where: { $0.id == id }) else { return }
        semesters[idx].deletedAt = Date()
        semesters[idx].isCurrent = false
        if currentSemesterId == id {
            currentSemesterId = nil
        }
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func recoverSemester(_ id: UUID) {
        guard let idx = semesters.firstIndex(where: { $0.id == id }) else { return }
        semesters[idx].deletedAt = nil
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    func permanentlyDeleteSemester(_ id: UUID) {
        semesters.removeAll { $0.id == id }
        courses.removeAll { $0.semesterId == id }
        if currentSemesterId == id {
            currentSemesterId = nil
        }
        persist()
        recalcGPA(tasks: AssignmentsStore.shared.tasks)
    }

    var activeSemesters: [Semester] {
        semesters.filter { !$0.isArchived && $0.deletedAt == nil }.sorted { $0.startDate > $1.startDate }
    }

    var archivedSemesters: [Semester] {
        semesters.filter { $0.isArchived && $0.deletedAt == nil }.sorted { $0.startDate > $1.startDate }
    }

    var recentlyDeletedSemesters: [Semester] {
        semesters.compactMap { $0.deletedAt == nil ? nil : $0 }.sorted { ($0.deletedAt ?? Date.distantPast) > ($1.deletedAt ?? Date.distantPast) }
    }

    var futureSemesters: [Semester] {
        let now = Date()
        return semesters.filter { !$0.isArchived && $0.deletedAt == nil && $0.startDate > now }.sorted { $0.startDate < $1.startDate }
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

    private func loadCache() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        do {
            let data = try Data(contentsOf: cacheURL)
            let decoded = try JSONDecoder().decode(PersistedData.self, from: data)
            self.semesters = decoded.semesters
            self.courses = decoded.courses
            self.currentSemesterId = decoded.currentSemesterId
        } catch {
            print("Failed to load courses cache: \(error)")
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
            try data.write(to: storageURL, options: [.atomic, .completeFileProtection])
            try data.write(to: cacheURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("Failed to persist courses data: \(error)")
        }
    }

    // MARK: - GPA recalculation

    @MainActor
    func recalcGPA(tasks: [AppTask]) {
        let gradedCourses = courses.filter { !$0.isArchived }
        currentGPA = GradeCalculator.calculateGPA(courses: gradedCourses, tasks: tasks)
    }

    func cleanupOldData() {
        let threshold = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let expiredIds = semesters.compactMap { semester -> UUID? in
            guard let deletedAt = semester.deletedAt, deletedAt < threshold else { return nil }
            return semester.id
        }

        guard !expiredIds.isEmpty else { return }

        semesters.removeAll { expiredIds.contains($0.id) }
        courses.removeAll { expiredIds.contains($0.semesterId) }
        if let currentId = currentSemesterId, expiredIds.contains(currentId) {
            currentSemesterId = nil
        }

        persist()
    }

    private func markCurrentSemester(_ id: UUID?) {
        semesters = semesters.map { semester in
            var s = semester
            let isTarget = semester.id == id
            s.isCurrent = isTarget && semester.deletedAt == nil
            return s
        }
    }
}

// Combine publisher replaces brittle NotificationCenter bridges
extension CoursesStore {
    // Emits courseId when a course is removed
    static var courseDeletedPublisher: AnyPublisher<UUID, Never> {
        guard let s = CoursesStore.shared else { return Empty<UUID, Never>().eraseToAnyPublisher() }
        return s.courseDeleted.eraseToAnyPublisher()
    }
}
