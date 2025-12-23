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
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LOG_UI(.error, "NotificationManager", "Failed to schedule assignment notification", metadata: ["error": error.localizedDescription, "assignmentId": assignment.id.uuidString])
            }
        }
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
        
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Today's assignments
        if AppSettingsModel.shared.dailyOverviewIncludeTasks {
            let todayTasks = AssignmentsStore.shared.tasks.filter { task in
                guard !task.isCompleted, let due = task.due else { return false }
                return due >= today && due < tomorrow
            }
            
            if todayTasks.isEmpty {
                bodyParts.append("No assignments due today")
            } else {
                let taskTitles = todayTasks.prefix(3).map { $0.title }.joined(separator: ", ")
                if todayTasks.count <= 3 {
                    bodyParts.append("\(todayTasks.count) due today: \(taskTitles)")
                } else {
                    bodyParts.append("\(todayTasks.count) due today: \(taskTitles), +\(todayTasks.count - 3) more")
                }
            }
        }
        
        // Yesterday's accomplishments
        if AppSettingsModel.shared.dailyOverviewIncludeYesterdayCompleted {
            let yesterdayCompleted = AssignmentsStore.shared.tasks.filter { task in
                guard task.isCompleted, let completedDate = task.completedDate else { return false }
                return completedDate >= yesterday && completedDate < today
            }
            
            if !yesterdayCompleted.isEmpty {
                if yesterdayCompleted.count <= 2 {
                    let titles = yesterdayCompleted.map { $0.title }.joined(separator: ", ")
                    bodyParts.append("Yesterday: Completed \(titles)")
                } else {
                    bodyParts.append("Yesterday: Completed \(yesterdayCompleted.count) tasks")
                }
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
        
        // Motivational closing (non-cringe, optional)
        if !bodyParts.isEmpty && AppSettingsModel.shared.dailyOverviewIncludeMotivation && shouldIncludeMotivation() {
            bodyParts.append(getMotivationalLine())
        }
        
        content.body = bodyParts.joined(separator: "\n")
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
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Placeholder: return nil for now, can be enhanced with CalendarManager
        // TODO: Integrate with CalendarManager.shared.events or similar
        return nil
    }
    
    private func shouldIncludeMotivation() -> Bool {
        // Include motivation ~50% of the time to keep it fresh
        return Bool.random()
    }
    
    private func getMotivationalLine() -> String {
        let lines = [
            "Make today count!",
            "You've got this!",
            "One step at a time",
            "Progress, not perfection",
            "Stay focused, stay strong",
            "Keep moving forward"
        ]
        return lines.randomElement() ?? lines[0]
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
