import Foundation
import Combine
import UserNotifications

final class TimerManager: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()

    // Timer state
    private var timer: Timer?
    @Published var isRunning: Bool = false
    @Published var secondsRemaining: Int = 25 * 60

    func start() {
        guard !isRunning else { return }
        LOG_TIMER(.info, "TimerStart", "Timer starting with \(secondsRemaining)s")
        isRunning = true
        // Throttled to 1s
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }
            _Concurrency.Task { @MainActor in
                strongSelf.tick()
            }
        }
        if let t = timer {
            RunLoop.current.add(t, forMode: .common)
        }
    }

    func stop() {
        LOG_TIMER(.info, "TimerStop", "Timer stopped with \(secondsRemaining)s remaining")
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard secondsRemaining > 0 else {
            LOG_TIMER(.info, "TimerComplete", "Timer completed")
            stop()
            // Notify finished
            return
        }
        secondsRemaining -= 1
    }

    func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            LOG_NOTIFICATIONS(.info, "Permissions", "Notification auth status: \(settings.authorizationStatus.rawValue)")
            if settings.authorizationStatus == .notDetermined {
                DispatchQueue.main.async {
                    self.requestNotificationPermission()
                }
            } else if settings.authorizationStatus == .denied {
                LOG_NOTIFICATIONS(.warn, "Permissions", "Notification permissions denied by user")
            }
        }
    }

    private func requestNotificationPermission() {
        DispatchQueue.main.async {
            LOG_NOTIFICATIONS(.info, "Permissions", "Requesting notification authorization")
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    LOG_NOTIFICATIONS(.info, "Permissions", "Notification permission granted")
                } else if let error {
                    // Non-fatal: permissions can be denied in sandboxed or user-blocked environments.
                    LOG_NOTIFICATIONS(.error, "Permissions", "Permission request failed: \(error.localizedDescription)")
                } else {
                    LOG_NOTIFICATIONS(.info, "Permissions", "Notification permission denied by user")
                }
            }
        }
    }
}
