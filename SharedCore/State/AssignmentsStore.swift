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
        refreshGPA()
        
        // Schedule notification for new task
        scheduleNotificationIfNeeded(for: task)
    }

    func removeTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        updateAppBadge()
        saveCache()
        refreshGPA()
        
        // Cancel notification when task is removed
        NotificationManager.shared.cancelAssignmentNotification(id)
    }

    func updateTask(_ task: AppTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        }
        updateAppBadge()
        saveCache()
        _Concurrency.Task { await CalendarManager.shared.syncPlannerTaskToCalendar(task) }
        refreshGPA()
        
        // Reschedule notification for updated task
        rescheduleNotificationIfNeeded(for: task)
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

    private func refreshGPA() {
        Task { @MainActor in
            CoursesStore.shared?.recalcGPA(tasks: tasks)
        }
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
            
            // Schedule notifications for all loaded incomplete tasks
            scheduleNotificationsForLoadedTasks()
        } catch {
            print("Failed to load tasks cache: \(error)")
        }
    }
    
    // MARK: - Notification Scheduling
    
    private func scheduleNotificationIfNeeded(for task: AppTask) {
        guard !task.isCompleted else { return }
        NotificationManager.shared.scheduleAssignmentDue(task)
    }
    
    private func rescheduleNotificationIfNeeded(for task: AppTask) {
        // Cancel existing notification
        NotificationManager.shared.cancelAssignmentNotification(task.id)
        
        // Schedule new one if task is incomplete
        if !task.isCompleted {
            NotificationManager.shared.scheduleAssignmentDue(task)
        }
    }
    
    private func scheduleNotificationsForLoadedTasks() {
        // Schedule notifications for all incomplete tasks on app launch
        for task in tasks where !task.isCompleted {
            NotificationManager.shared.scheduleAssignmentDue(task)
        }
    }
}
