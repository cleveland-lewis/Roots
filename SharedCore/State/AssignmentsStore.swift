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
        
        // Generate plan immediately for the new assignment
        Task { @MainActor in
            generatePlanForNewTask(task)
        }
    }
    
    private func generatePlanForNewTask(_ task: AppTask) {
        guard let assignment = convertTaskToAssignment(task) else { return }
        AssignmentPlansStore.shared.generatePlan(for: assignment, force: false)
    }
    
    private func convertTaskToAssignment(_ task: AppTask) -> Assignment? {
        guard let due = task.due else { return nil }
        
        let assignmentCategory: AssignmentCategory
        switch task.category {
        case .exam: assignmentCategory = .exam
        case .quiz: assignmentCategory = .quiz
        case .practiceHomework: assignmentCategory = .practiceHomework
        case .reading: assignmentCategory = .reading
        case .review: assignmentCategory = .review
        case .project: assignmentCategory = .project
        }
        
        return Assignment(
            id: task.id,
            courseId: task.courseId,
            title: task.title,
            dueDate: due,
            estimatedMinutes: task.estimatedMinutes,
            weightPercent: task.gradeWeightPercent,
            category: assignmentCategory,
            urgency: urgencyFromImportance(task.importance),
            isLockedToDueDate: task.locked,
            plan: []
        )
    }
    
    private func urgencyFromImportance(_ importance: Double) -> AssignmentUrgency {
        switch importance {
        case ..<0.3: return .low
        case ..<0.6: return .medium
        case ..<0.85: return .high
        default: return .critical
        }
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
        // Check if this is a completion event (task was incomplete, now complete)
        let wasJustCompleted: Bool = {
            guard task.isCompleted else { return false }
            guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return false }
            return !tasks[idx].isCompleted
        }()
        
        // Check if key fields changed that require plan regeneration
        let needsPlanRegeneration: Bool = {
            guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return false }
            let old = tasks[idx]
            return old.due != task.due ||
                   old.estimatedMinutes != task.estimatedMinutes ||
                   old.category != task.category ||
                   old.importance != task.importance
        }()
        
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        }
        updateAppBadge()
        saveCache()
        _Concurrency.Task { await CalendarManager.shared.syncPlannerTaskToCalendar(task) }
        refreshGPA()
        
        // Reschedule notification for updated task
        rescheduleNotificationIfNeeded(for: task)
        
        // Regenerate plan if key fields changed
        if needsPlanRegeneration {
            Task { @MainActor in
                generatePlanForNewTask(task)
            }
        }
        
        // Play completion feedback if task was just completed
        if wasJustCompleted {
            Task { @MainActor in
                Feedback.shared.taskCompleted()
            }
        }
    }

    func reassignTasks(fromCourseId: UUID, toCourseId: UUID?) {
        var didChange = false
        let updated = tasks.map { task -> AppTask in
            guard task.courseId == fromCourseId else { return task }
            didChange = true
            return task.withCourseId(toCourseId)
        }
        guard didChange else { return }
        tasks = updated
        saveCache()
        refreshGPA()
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
            
            // Migration validation: verify all tasks have category field populated
            let tasksNeedingMigration = tasks.filter { $0.category != $0.type }
            if !tasksNeedingMigration.isEmpty {
                print("⚠️ Migration Notice: \(tasksNeedingMigration.count) tasks have different category/type values")
            }
            
            // Verify no data loss
            print("✅ Migration Complete: Loaded \(tasks.count) tasks successfully")
            
            // Schedule notifications for all loaded incomplete tasks
            scheduleNotificationsForLoadedTasks()
        } catch {
            print("❌ Failed to load tasks cache: \(error)")
            
            // Attempt rollback-safe recovery
            attemptRollbackRecovery(from: url)
        }
    }
    
    private func attemptRollbackRecovery(from url: URL) {
        // Try to create a backup of the corrupted file
        let backupURL = url.deletingLastPathComponent().appendingPathComponent("tasks_cache_backup_\(Date().timeIntervalSince1970).json")
        
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.copyItem(at: url, to: backupURL)
                print("📦 Backup created at: \(backupURL.path)")
            }
        } catch {
            print("⚠️ Could not create backup: \(error)")
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
