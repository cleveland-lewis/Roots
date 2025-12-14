import Foundation

final class DeveloperSettingsSynchronizer {
    static let shared = DeveloperSettingsSynchronizer()
    private var defaultsObserver: NSObjectProtocol?
    private var isUpdating = false

    private init() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDiagnostics()
        }
        refreshDiagnostics()
    }

    private func refreshDiagnostics() {
        // Prevent infinite recursion
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        
        let diag = Diagnostics.shared
        let settings = AppSettingsModel.shared
        diag.isDeveloperModeEnabled = settings.devModeEnabled
        diag.enableUILogging = settings.devModeUILogging
        diag.enableDataLogging = settings.devModeDataLogging
        diag.enableSchedulerLogging = settings.devModeSchedulerLogging
        diag.enablePerformanceWarnings = settings.devModePerformance
    }
}
