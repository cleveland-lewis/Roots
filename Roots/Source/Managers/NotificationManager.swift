import Foundation
import UserNotifications
import Combine
#if os(macOS)
import AppKit
#endif

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized: Bool = false

    private init() {}

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        }
    }

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
}
