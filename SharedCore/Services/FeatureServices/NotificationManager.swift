import Foundation
import UserNotifications
import Combine
#if os(macOS)
#if os(macOS)
import AppKit
#endif
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
#endif

    func scheduleTimerNotification(seconds: TimeInterval, title: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
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
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
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
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
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
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
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
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    // MARK: - Assignment Notifications
    
    func scheduleAssignmentDue(_ assignment: AppTask) {
        guard AppSettingsModel.shared.assignmentRemindersEnabled else { return }
        guard let dueDate = assignment.due else { return }
        
        let leadTime = AppSettingsModel.shared.assignmentLeadTime
        let notificationDate = dueDate.addingTimeInterval(-leadTime)
        
        // Don't schedule if already past
        guard notificationDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Assignment Due Soon"
        content.body = "\(assignment.title) is due \(formatLeadTime(leadTime))"
        content.sound = .default
        content.userInfo = ["assignmentId": assignment.id.uuidString]
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let identifier = "assignment-\(assignment.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func cancelAssignmentNotification(_ assignmentId: UUID) {
        let identifier = "assignment-\(assignmentId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // MARK: - Daily Overview
    
    func scheduleDailyOverview() {
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
    
    private func generateDailyOverviewContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Daily Overview"
        content.interruptionLevel = .timeSensitive
        
        var bodyParts: [String] = []
        
        // Today's assignments
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let todayTasks = AssignmentsStore.shared.tasks.filter { task in
            guard !task.isCompleted, let due = task.due else { return false }
            return due >= today && due < tomorrow
        }
        
        if todayTasks.isEmpty {
            bodyParts.append("✓ No assignments due today")
        } else {
            let taskTitles = todayTasks.prefix(3).map { $0.title }.joined(separator: ", ")
            if todayTasks.count <= 3 {
                bodyParts.append("\(todayTasks.count) due today: \(taskTitles)")
            } else {
                bodyParts.append("\(todayTasks.count) due today: \(taskTitles), +\(todayTasks.count - 3) more")
            }
        }
        
        // Calendar events (if available)
        // TODO: Integrate with CalendarManager once available
        
        content.body = bodyParts.joined(separator: "\n")
        content.sound = .default
        
        return content
    }
    
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
