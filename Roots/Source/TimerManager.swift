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
        isRunning = true
        // Throttled to 1s
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            _Concurrency.Task { @MainActor in
                self?.tick()
            }
        }
        if let t = timer {
            RunLoop.current.add(t, forMode: .common)
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard secondsRemaining > 0 else {
            stop()
            // Notify finished
            return
        }
        secondsRemaining -= 1
    }

    func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                DispatchQueue.main.async {
                    self.requestNotificationPermission()
                }
            } else if settings.authorizationStatus == .denied {
                print("Notifications denied")
            }
        }
    }

    private func requestNotificationPermission() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    LOG_UI(.info, "Notifications", "Permission granted")
                } else if let error {
                    // Non-fatal: permissions can be denied in sandboxed or user-blocked environments.
                    LOG_UI(.warn, "Notifications", "Permission request failed: \(error.localizedDescription)")
                } else {
                    LOG_UI(.info, "Notifications", "Permission denied")
                }
            }
        }
    }
}
