import Foundation
import UserNotifications
import Combine
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    enum AuthorizationState: Equatable {
        case notRequested
        case granted
        case denied
        case error(String)

        var isAuthorized: Bool {
            if case .granted = self { return true }
            return false
        }
    }

    @Published var isAuthorized: Bool = false
    @Published var authorizationState: AuthorizationState = .notRequested

    private init() {}

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.authorizationState = .granted
                } else if let error {
                    // Silently handle permission errors (common in sandboxed/restricted environments)
                    if (error as NSError).domain != "UNErrorDomain" || (error as NSError).code != 1 {
                        self.authorizationState = .error(error.localizedDescription)
                    } else {
                        self.authorizationState = .denied
                    }
                } else {
                    self.authorizationState = .denied
                }
                self.isAuthorized = self.authorizationState.isAuthorized
            }
        }
    }

    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let state: AuthorizationState
            switch settings.authorizationStatus {
            case .notDetermined:
                state = .notRequested
            case .authorized, .provisional, .ephemeral:
                state = .granted
            case .denied:
                state = .denied
            @unknown default:
                state = .error("Unknown authorization status")
            }
            DispatchQueue.main.async {
                self.authorizationState = state
                self.isAuthorized = state.isAuthorized
            }
        }
    }

#if os(macOS)
    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }
#elseif os(iOS)
    func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
#endif

    func scheduleTimerNotification(seconds: TimeInterval, title: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LOG_UI(.error, "NotificationManager", "Failed to schedule timer notification", metadata: ["error": error.localizedDescription])
            }
        }
    }

    func updateBadgeCount(_ count: Int) {
#if os(macOS)
        NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
#endif

        if #available(macOS 14.0, iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count)
        } else {
            let content = UNMutableNotificationContent()
            content.badge = NSNumber(value: count)
            let request = UNNotificationRequest(identifier: "roots.badge.update", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    LOG_UI(.error, "NotificationManager", "Failed to update badge", metadata: ["error": error.localizedDescription])
                }
            }
        }
    }

    func clearBadge() {
        updateBadgeCount(0)
    }
    
    // MARK: - Timer Completion Notifications
    
    func scheduleTimerCompleted(mode: String, duration: TimeInterval) {
        guard AppSettingsModel.shared.timerAlertsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete"
        content.body = "\(mode) finished after \(formatDuration(duration))"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LOG_UI(.error, "NotificationManager", "Failed to schedule timer completion", metadata: ["error": error.localizedDescription])
            }
        }
    }
    
    // MARK: - Pomodoro Notifications
    
    func schedulePomodoroWorkComplete() {
        guard AppSettingsModel.shared.pomodoroAlertsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Work Session Complete"
        content.body = "Time for a break! Great job staying focused."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LOG_UI(.error, "NotificationManager", "Failed to schedule pomodoro work completion", metadata: ["error": error.localizedDescription])
            }
        }
    }
    
    func schedulePomodoroBreakComplete(isLongBreak: Bool = false) {
        guard AppSettingsModel.shared.pomodoroAlertsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = isLongBreak ? "Long Break Complete" : "Break Complete"
        content.body = "Ready to focus? Let's get back to work!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LOG_UI(.error, "NotificationManager", "Failed to schedule pomodoro break completion", metadata: ["error": error.localizedDescription])
            }
        }
    }
    
    // MARK: - Assignment Notifications
    
    func scheduleAssignmentDue(_ assignment: AppTask) {
        guard AppSettingsModel.shared.notificationsEnabled else { return }
        guard AppSettingsModel.shared.assignmentRemindersEnabled else { return }
        guard let dueDate = assignment.due else { return }
        guard !assignment.isCompleted else { return }
        
        let leadTime = AppSettingsModel.shared.assignmentLeadTime
        let notificationDate = dueDate.addingTimeInterval(-leadTime)
        
        // Don't schedule if already past
        guard notificationDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.assignment.title", comment: "Assignment Due Soon")
        content.body = String(format: NSLocalizedString("notification.assignment.body", comment: "%@ is due soon"), assignment.title)
        content.sound = .default
        content.userInfo = ["assignmentId": assignment.id.uuidString]
        content.categoryIdentifier = "roots.assignmentReminder"
        
        // Add course subtitle if available
        if let courseId = assignment.courseId,
           let coursesStore = CoursesStore.shared,
           let course = coursesStore.courses.first(where: { $0.id == courseId }) {
            content.subtitle = course.title
        }
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let identifier = "assignment-\(assignment.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LOG_UI(.error, "NotificationManager", "Failed to schedule assignment notification", metadata: ["error": error.localizedDescription, "assignmentId": assignment.id.uuidString])
            }
        }
    }
    
    func scheduleAllAssignmentReminders() {
        let assignments = AssignmentsStore.shared.tasks
        for assignment in assignments where !assignment.isCompleted {
            scheduleAssignmentDue(assignment)
        }
    }
    
    func cancelAllAssignmentReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let assignmentIds = requests
                .filter { $0.identifier.hasPrefix("assignment-") }
                .map { $0.identifier }
            
            if !assignmentIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: assignmentIds)
            }
        }
    }
    
    func cancelAssignmentNotification(_ assignmentId: UUID) {
        let identifier = "assignment-\(assignmentId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // MARK: - Daily Overview
    
    func scheduleDailyOverview() {
        guard AppSettingsModel.shared.notificationsEnabled else {
            cancelDailyOverview()
            return
        }
        guard AppSettingsModel.shared.dailyOverviewEnabled else {
            cancelDailyOverview()
            return
        }
        
        // Cancel existing daily overview
        cancelDailyOverview()
        
        // Generate overview content
        let content = generateDailyOverviewContent()
        
        let overviewTime = AppSettingsModel.shared.dailyOverviewTime
        let components = Calendar.current.dateComponents([.hour, .minute], from: overviewTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(identifier: "daily-overview", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily overview: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelDailyOverview() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-overview"])
    }
    
    // MARK: - Motivational Messages
    
    func scheduleMotivationalMessages() {
        guard AppSettingsModel.shared.notificationsEnabled else {
            cancelMotivationalMessages()
            return
        }
        guard AppSettingsModel.shared.affirmationsEnabled else {
            cancelMotivationalMessages()
            return
        }
        
        // Cancel existing motivational messages
        cancelMotivationalMessages()
        
        // Schedule 3 daily messages at 10am, 2pm, and 6pm
        let times = [
            DateComponents(hour: 10, minute: 0),
            DateComponents(hour: 14, minute: 0),
            DateComponents(hour: 18, minute: 0)
        ]
        
        let messages = [
            NSLocalizedString("notification.motivation.message_1", comment: "Keep up the great work!"),
            NSLocalizedString("notification.motivation.message_2", comment: "You're making progress!"),
            NSLocalizedString("notification.motivation.message_3", comment: "Stay focused on your goals!"),
            NSLocalizedString("notification.motivation.message_4", comment: "Every small step counts!"),
            NSLocalizedString("notification.motivation.message_5", comment: "Believe in yourself!"),
            NSLocalizedString("notification.motivation.message_6", comment: "You're doing amazing!"),
        ]
        
        for (index, timeComponents) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("notification.motivation.title", comment: "Stay Motivated")
            content.body = messages.randomElement() ?? messages[0]
            content.sound = .default
            content.categoryIdentifier = "roots.motivation"
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: timeComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "motivation-\(index)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    LOG_UI(.error, "NotificationManager", "Failed to schedule motivational message", metadata: ["error": error.localizedDescription])
                }
            }
        }
    }
    
    func cancelMotivationalMessages() {
        let identifiers = (0..<3).map { "motivation-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func cancelAllScheduledNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    private func generateDailyOverviewContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.daily_overview.title", comment: "Good Morning!")
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "roots.dailyOverview"
        
        var bodyParts: [String] = []
        
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Today's assignments
        if AppSettingsModel.shared.dailyOverviewIncludeTasks {
            let todayTasks = AssignmentsStore.shared.tasks.filter { task in
                guard !task.isCompleted, let due = task.due else { return false }
                return due >= today && due < tomorrow
            }
            
            if !todayTasks.isEmpty {
                let taskText = todayTasks.count == 1 ?
                    NSLocalizedString("notification.daily_overview.task_singular", comment: "1 task") :
                    String(format: NSLocalizedString("notification.daily_overview.tasks_plural", comment: "%d tasks"), todayTasks.count)
                bodyParts.append(taskText)
            }
        }
        
        // Yesterday's study time from FocusManager/timer sessions
        if AppSettingsModel.shared.dailyOverviewIncludeYesterdayStudyTime {
            if let studyMinutes = getYesterdayStudyTime() {
                let hours = studyMinutes / 60
                let mins = studyMinutes % 60
                if hours > 0 {
                    bodyParts.append("Yesterday: Studied \(hours)h \(mins)m")
                } else if mins > 0 {
                    bodyParts.append("Yesterday: Studied \(mins)m")
                }
            }
        }
        
        // Today's events from CalendarManager
        if AppSettingsModel.shared.dailyOverviewIncludeEvents {
            if let todayEvents = getTodayEvents(), !todayEvents.isEmpty {
                if todayEvents.count <= 2 {
                    let eventTitles = todayEvents.map { $0.title }.joined(separator: ", ")
                    bodyParts.append("Today: \(eventTitles)")
                } else {
                    bodyParts.append("Today: \(todayEvents.count) events scheduled")
                }
            }
        }
        
        // Motivational closing
        if AppSettingsModel.shared.dailyOverviewIncludeMotivation {
            bodyParts.append(NSLocalizedString("notification.daily_overview.motivation", comment: "You've got this!"))
        }
        
        content.body = bodyParts.isEmpty ?
            NSLocalizedString("notification.daily_overview.default", comment: "Open Roots to see today's plan") :
            bodyParts.joined(separator: " • ")
        content.sound = .default
        
        return content
    }
    
    private func getYesterdayStudyTime() -> Int? {
        // Try to access yesterday's study time from UserDefaults cache
        // This assumes timer data is cached somewhere accessible
        let key = "timer.yesterday.study.minutes"
        let minutes = UserDefaults.standard.integer(forKey: key)
        return minutes > 0 ? minutes : nil
    }
    
    private func getTodayEvents() -> [(title: String, startDate: Date)]? {
        // Access today's calendar events
        // This will integrate with CalendarManager when available
        let today = Calendar.current.startOfDay(for: Date())
        _ = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Placeholder: return nil for now, can be enhanced with CalendarManager
        // TODO: Integrate with CalendarManager.shared.events or similar
        return nil
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    func printPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("📬 Pending Notifications: \(requests.count)")
            for request in requests {
                print("  • \(request.identifier)")
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let nextTrigger = trigger.nextTriggerDate() {
                    print("    Next: \(nextTrigger)")
                }
            }
        }
    }
    
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from Roots (5 seconds)"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification failed: \(error)")
            } else {
                print("✅ Test notification scheduled for 5 seconds")
            }
        }
    }
    #endif
    
    // MARK: - Utility
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatLeadTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let hours = minutes / 60
        let days = hours / 24
        
        if days > 0 {
            return "in \(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "in \(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "in \(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
}
