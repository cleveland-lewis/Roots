import SwiftUI
import Combine

class MenuBarManager {
    private var statusItem: NSStatusItem
    private var viewModel = MenuBarViewModel()
    private var cancellables = Set<AnyCancellable>()

    init(focusManager: FocusManager, assignmentsStore: AssignmentsStore, settings: AppSettingsModel) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        let menu = NSMenu()
        let view = MenuBarView(viewModel: viewModel, assignmentsStore: assignmentsStore, settings: settings)
        let hostingController = NSHostingController(rootView: view)
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

    private func handleTimerStateChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        viewModel.mode = userInfo["mode"] as? LocalTimerMode ?? .pomodoro
        viewModel.isRunning = userInfo["isRunning"] as? Bool ?? false
        viewModel.remainingSeconds = userInfo["remainingSeconds"] as? TimeInterval ?? 0
        viewModel.elapsedSeconds = userInfo["elapsedSeconds"] as? TimeInterval ?? 0
        viewModel.pomodoroSessions = userInfo["pomodoroSessions"] as? Int ?? 0
        viewModel.completedPomodoroSessions = userInfo["completedPomodoroSessions"] as? Int ?? 0
        viewModel.isPomodorBreak = userInfo["isPomodorBreak"] as? Bool ?? false
        viewModel.selectedActivityID = userInfo["selectedActivityID"] as? UUID
        viewModel.activities = userInfo["activities"] as? [LocalTimerActivity] ?? []
        viewModel.sessions = userInfo["sessions"] as? [LocalTimerSession] ?? []
        
        updateMenuBar()
    }

    private func updateMenuBar() {
        guard let button = statusItem.button else { return }
        
        let timeString: String
        let iconName: String
        
        switch viewModel.mode {
        case .pomodoro:
            let minutes = Int(viewModel.remainingSeconds) / 60
            let seconds = Int(viewModel.remainingSeconds) % 60
            timeString = String(format: "%02d:%02d", minutes, seconds)
            iconName = viewModel.isPomodorBreak ? "pause.circle" : "timer"
            
        case .countdown:
            let minutes = Int(viewModel.remainingSeconds) / 60
            let seconds = Int(viewModel.remainingSeconds) % 60
            timeString = String(format: "%02d:%02d", minutes, seconds)
            iconName = "timer"
            
        case .stopwatch:
            let minutes = Int(viewModel.elapsedSeconds) / 60
            let seconds = Int(viewModel.elapsedSeconds) % 60
            timeString = String(format: "%02d:%02d", minutes, seconds)
            iconName = "stopwatch"
        }
        
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: viewModel.mode.label)
        button.title = timeString
    }
}


