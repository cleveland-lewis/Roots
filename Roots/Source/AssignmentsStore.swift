import Foundation
import Combine

final class AssignmentsStore: ObservableObject {
    static let shared = AssignmentsStore()
    private init() {
        loadCache()
    }

    @Published var tasks: [AppTask] = [] {
        didSet { updateAppBadge() }
    }

    private var cacheURL: URL? = {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let folder = dir.appendingPathComponent("RootsAssignments", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("tasks_cache.json")
    }()

    // No sample data - provided methods to add/remove tasks programmatically
    func addTask(_ task: AppTask) {
        tasks.append(task)
        updateAppBadge()
        saveCache()
        _Concurrency.Task { await CalendarManager.shared.syncPlannerTaskToCalendar(task) }
        CoursesStore.shared?.recalcGPA(tasks: tasks)
    }

    func removeTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        updateAppBadge()
        saveCache()
        CoursesStore.shared?.recalcGPA(tasks: tasks)
    }

    func updateTask(_ task: AppTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        }
        updateAppBadge()
        saveCache()
        _Concurrency.Task { await CalendarManager.shared.syncPlannerTaskToCalendar(task) }
        CoursesStore.shared?.recalcGPA(tasks: tasks)
    }

    func incompleteTasks() -> [AppTask] {
        // For now all tasks are considered active; in future, filter by completion state
        return tasks
    }

    func resetAll() {
        tasks.removeAll()
        updateAppBadge()
        if let url = cacheURL, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        saveCache()
    }

    private func updateAppBadge() {
        let calendar = Calendar.current
        let now = Date()
        let startOfTomorrow = calendar.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        let count = tasks.filter { task in
            guard !task.isCompleted, let due = task.due else { return false }
            return due < startOfTomorrow
        }.count
        NotificationManager.shared.updateBadgeCount(count)
    }

    private func saveCache() {
        guard let url = cacheURL else { return }
        do {
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save tasks cache: \(error)")
        }
    }

    private func loadCache() {
        guard let url = cacheURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([AppTask].self, from: data)
            tasks = decoded
        } catch {
            print("Failed to load tasks cache: \(error)")
        }
    }
}
