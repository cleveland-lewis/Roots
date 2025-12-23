#if os(macOS)
import SwiftUI

/// View modifier to add global context menu on right-click
struct GlobalContextMenuModifier: ViewModifier {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var calendarManager: CalendarManager
    @EnvironmentObject private var plannerCoordinator: PlannerCoordinator
    @EnvironmentObject private var settingsCoordinator: SettingsCoordinator
    
    var pageSpecificItems: (() -> AnyView)?
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                // Global items
                Button(NSLocalizedString("timer.context.refresh_calendar", comment: "")) {
                    GlobalMenuActions.shared.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button(NSLocalizedString("timer.context.go_to_planner", comment: "")) {
                    GlobalMenuActions.shared.navigateToPlanner()
                }
                
                Button(NSLocalizedString("timer.context.add_assignment", comment: "")) {
                    GlobalMenuActions.shared.addAssignment()
                }
                
                Button(NSLocalizedString("timer.context.add_grade", comment: "")) {
                    GlobalMenuActions.shared.addGrade()
                }
            }
    }
}

/// Timer-specific context menu modifier
struct TimerContextMenuModifier: ViewModifier {
    @Binding var isRunning: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onEnd: () -> Void
    
    @EnvironmentObject private var appModel: AppModel
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                // Timer-specific items
                Button(NSLocalizedString("timer.context.start_clock", comment: "")) {
                    TimerMenuActions.shared.startClock()
                }
                .disabled(isRunning)
                
                Button(NSLocalizedString("timer.context.stop_clock", comment: "")) {
                    TimerMenuActions.shared.stopClock()
                }
                .disabled(!isRunning)
                
                Button(NSLocalizedString("timer.context.end_clock", comment: "")) {
                    TimerMenuActions.shared.endClock()
                }
                .disabled(!isRunning)
                
                Divider()
                
                // Global items
                Button(NSLocalizedString("timer.context.refresh_calendar", comment: "")) {
                    GlobalMenuActions.shared.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button(NSLocalizedString("timer.context.go_to_planner", comment: "")) {
                    GlobalMenuActions.shared.navigateToPlanner()
                }
                
                Button(NSLocalizedString("timer.context.add_assignment", comment: "")) {
                    GlobalMenuActions.shared.addAssignment()
                }
                
                Button(NSLocalizedString("timer.context.add_grade", comment: "")) {
                    GlobalMenuActions.shared.addGrade()
                }
            }
    }
}

// MARK: - Action Handlers

/// Global menu action handler
class GlobalMenuActions: NSObject {
    static let shared = GlobalMenuActions()
    
    @objc func refresh() {
        CalendarRefreshCoordinator.shared.refresh()
    }
    
    @objc func navigateToCalendar() {
        NotificationCenter.default.post(name: .navigateToTab, object: nil, userInfo: ["tab": "calendar"])
    }
    
    @objc func navigateToPlanner() {
        Task { @MainActor in
            AppModalRouter.shared.present(.planner)
        }
    }
    
    @objc func addAssignment() {
        Task { @MainActor in
            AppModalRouter.shared.present(.addAssignment)
        }
    }
    
    @objc func addGrade() {
        Task { @MainActor in
            AppModalRouter.shared.present(.addGrade)
        }
    }
}

/// Timer-specific menu action handler
class TimerMenuActions: NSObject {
    static let shared = TimerMenuActions()
    
    @objc func startClock() {
        NotificationCenter.default.post(name: .timerStartRequested, object: nil)
    }
    
    @objc func stopClock() {
        NotificationCenter.default.post(name: .timerStopRequested, object: nil)
    }
    
    @objc func endClock() {
        NotificationCenter.default.post(name: .timerEndRequested, object: nil)
    }
}

// MARK: - Notification Names

// MARK: - View Extensions

extension View {
    func globalContextMenu(pageSpecificItems: (() -> AnyView)? = nil) -> some View {
        modifier(GlobalContextMenuModifier(pageSpecificItems: pageSpecificItems))
    }
    
    func timerContextMenu(isRunning: Binding<Bool>, onStart: @escaping () -> Void, onStop: @escaping () -> Void, onEnd: @escaping () -> Void) -> some View {
        modifier(TimerContextMenuModifier(isRunning: isRunning, onStart: onStart, onStop: onStop, onEnd: onEnd))
    }
}

#endif
