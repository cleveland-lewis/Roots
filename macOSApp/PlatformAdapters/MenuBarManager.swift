import SwiftUI
import Combine

class MenuBarManager {
    private var statusItem: NSStatusItem
    private var viewModel = MenuBarViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var hostingController: NSHostingController<MenuBarView>?

    init(focusManager: FocusManager, assignmentsStore: AssignmentsStore, settings: AppSettingsModel) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        let menu = NSMenu()
        let view = MenuBarView(viewModel: viewModel, assignmentsStore: assignmentsStore, settings: settings)
        let hostingController = NSHostingController(rootView: view)
        self.hostingController = hostingController
        
        let menuItem = NSMenuItem()
        menuItem.view = hostingController.view
        menu.addItem(menuItem)
        statusItem.menu = menu

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Timer")
        }

        NotificationCenter.default.addObserver(forName: .timerStateDidChange, object: nil, queue: .main) { [weak self] notification in
            self?.handleTimerStateChange(notification)
        }
    }
    
    deinit {
        if let statusItem = statusItem as NSStatusItem? {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    private func handleTimerStateChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        let mode = userInfo["mode"] as? LocalTimerMode ?? .pomodoro
        let isRunning = userInfo["isRunning"] as? Bool ?? false
        let remainingSeconds = userInfo["remainingSeconds"] as? TimeInterval ?? 0
        let elapsedSeconds = userInfo["elapsedSeconds"] as? TimeInterval ?? 0
        let isPomodorBreak = userInfo["isPomodorBreak"] as? Bool ?? false
        
        // Update button directly (avoids SwiftUI view rebuilds)
        updateMenuBarButton(mode: mode, isRunning: isRunning, remainingSeconds: remainingSeconds, elapsedSeconds: elapsedSeconds, isPomodorBreak: isPomodorBreak)
        
        // Only update viewModel for menu content (throttled)
        if shouldUpdateMenuContent(mode: mode, isRunning: isRunning) {
            viewModel.mode = mode
            viewModel.isRunning = isRunning
            viewModel.remainingSeconds = remainingSeconds
            viewModel.elapsedSeconds = elapsedSeconds
            viewModel.pomodoroSessions = userInfo["pomodoroSessions"] as? Int ?? 0
            viewModel.completedPomodoroSessions = userInfo["completedPomodoroSessions"] as? Int ?? 0
            viewModel.isPomodorBreak = isPomodorBreak
            viewModel.selectedActivityID = userInfo["selectedActivityID"] as? UUID
            if let activities = userInfo["activities"] as? [LocalTimerActivity] {
                viewModel.activities = activities
            }
            if let sessions = userInfo["sessions"] as? [LocalTimerSession] {
                viewModel.sessions = sessions
            }
        }
    }
    
    private var lastMenuUpdate: Date = .distantPast
    private let menuUpdateThrottle: TimeInterval = 1.0
    
    private func shouldUpdateMenuContent(mode: LocalTimerMode, isRunning: Bool) -> Bool {
        let now = Date()
        let shouldUpdate = now.timeIntervalSince(lastMenuUpdate) >= menuUpdateThrottle
        if shouldUpdate {
            lastMenuUpdate = now
        }
        return shouldUpdate
    }

    private func updateMenuBarButton(mode: LocalTimerMode, isRunning: Bool, remainingSeconds: TimeInterval, elapsedSeconds: TimeInterval, isPomodorBreak: Bool) {
        guard let button = statusItem.button else { return }
        
        let timeString: String
        let iconName: String
        
        switch mode {
        case .pomodoro:
            let minutes = Int(remainingSeconds) / 60
            let seconds = Int(remainingSeconds) % 60
            timeString = String(format: "%02d:%02d", minutes, seconds)
            iconName = isPomodorBreak ? "pause.circle" : "timer"
            
        case .countdown:
            let minutes = Int(remainingSeconds) / 60
            let seconds = Int(remainingSeconds) % 60
            timeString = String(format: "%02d:%02d", minutes, seconds)
            iconName = "timer"
            
        case .stopwatch:
            let minutes = Int(elapsedSeconds) / 60
            let seconds = Int(elapsedSeconds) % 60
            timeString = String(format: "%02d:%02d", minutes, seconds)
            iconName = "stopwatch"
        }
        
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: mode.label)
        button.title = timeString
    }
}

