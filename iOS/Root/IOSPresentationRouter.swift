#if os(iOS)
import SwiftUI
import Combine

final class IOSSheetRouter: ObservableObject {
    struct TaskDefaults {
        let id = UUID()
        var courseId: UUID?
        var dueDate: Date
        var title: String
        var type: TaskType
        var itemLabel: String
    }

    struct CourseDefaults {
        let id = UUID()
        var semesterId: UUID?
        var title: String
        var code: String
    }

    enum SheetKind: Identifiable {
        case addAssignment(TaskDefaults)
        case addCourse(CourseDefaults)
        case addGrade(UUID)

        var id: UUID {
            switch self {
            case .addAssignment(let defaults): return defaults.id
            case .addCourse(let defaults): return defaults.id
            case .addGrade(let id): return id
            }
        }
    }

    @Published var activeSheet: SheetKind? = nil
}

final class IOSToastRouter: ObservableObject {
    @Published var message: String? = nil

    func show(_ message: String) {
        self.message = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard self?.message == message else { return }
            self?.message = nil
        }
    }
}

final class IOSFilterState: ObservableObject {
    @Published var selectedSemesterId: UUID? {
        didSet { save() }
    }
    @Published var selectedCourseId: UUID? {
        didSet { save() }
    }

    init() {
        if let semesterString = UserDefaults.standard.string(forKey: Self.semesterKey) {
            selectedSemesterId = UUID(uuidString: semesterString)
        }
        if let courseString = UserDefaults.standard.string(forKey: Self.courseKey) {
            selectedCourseId = UUID(uuidString: courseString)
        }
    }

    func setSemester(_ id: UUID?, availableCourseIds: Set<UUID>) {
        selectedSemesterId = id
        if let selectedCourseId, !availableCourseIds.contains(selectedCourseId) {
            self.selectedCourseId = nil
        }
    }

    private func save() {
        if let id = selectedSemesterId {
            UserDefaults.standard.set(id.uuidString, forKey: Self.semesterKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.semesterKey)
        }
        if let id = selectedCourseId {
            UserDefaults.standard.set(id.uuidString, forKey: Self.courseKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.courseKey)
        }
    }

    private static let semesterKey = "roots.ios.filters.semester"
    private static let courseKey = "roots.ios.filters.course"
}
#endif
