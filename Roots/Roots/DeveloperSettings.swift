import Foundation
import SwiftUI

extension AppSettings {
    @AppStorage("devMode.enabled") var devModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "devMode.enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "devMode.enabled") }
    }

    @AppStorage("devMode.uiLogging") var devModeUILogging: Bool {
        get { UserDefaults.standard.bool(forKey: "devMode.uiLogging") }
        set { UserDefaults.standard.set(newValue, forKey: "devMode.uiLogging") }
    }

    @AppStorage("devMode.dataLogging") var devModeDataLogging: Bool {
        get { UserDefaults.standard.bool(forKey: "devMode.dataLogging") }
        set { UserDefaults.standard.set(newValue, forKey: "devMode.dataLogging") }
    }

    @AppStorage("devMode.schedulerLogging") var devModeSchedulerLogging: Bool {
        get { UserDefaults.standard.bool(forKey: "devMode.schedulerLogging") }
        set { UserDefaults.standard.set(newValue, forKey: "devMode.schedulerLogging") }
    }

    @AppStorage("devMode.performance") var devModePerformance: Bool {
        get { UserDefaults.standard.bool(forKey: "devMode.performance") }
        set { UserDefaults.standard.set(newValue, forKey: "devMode.performance") }
    }
}

// Keep Diagnostics.shared in sync when AppSettings is used as environment
final class DeveloperSettingsSynchronizer {
    static let shared = DeveloperSettingsSynchronizer()
    private var cancellables: [AnyCancellable] = []

    private init() {
        let ds = Diagnostics.shared
        // Observe UserDefaults changes via NotificationCenter
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            ds.isDeveloperModeEnabled = UserDefaults.standard.bool(forKey: "devMode.enabled")
            ds.enableUILogging = UserDefaults.standard.bool(forKey: "devMode.uiLogging")
            ds.enableDataLogging = UserDefaults.standard.bool(forKey: "devMode.dataLogging")
            ds.enableSchedulerLogging = UserDefaults.standard.bool(forKey: "devMode.schedulerLogging")
            ds.enablePerformanceWarnings = UserDefaults.standard.bool(forKey: "devMode.performance")
        }
    }
}
