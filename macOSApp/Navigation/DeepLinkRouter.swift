import Foundation
import SwiftUI

enum DeepLinkRoute {
    case dashboard
    case calendar(date: Date?, view: CalendarView)
    case planner
    case assignment(id: UUID)
    case course(id: UUID)
    case focus(mode: LocalTimerMode?, activityId: UUID?)
    case settings(section: SettingsToolbarIdentifier?)
    case invalid(String)
    
    enum CalendarView: String {
        case month, week, day, year
    }
}

@MainActor
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()
    
    private init() {}
    
    func handle(url: URL,
                appModel: AppModel = .shared,
                plannerCoordinator: PlannerCoordinator = .shared,
                calendarManager: CalendarManager = .shared,
                settingsCoordinator: SettingsCoordinator) -> Bool {
        let route = parse(url: url)
        return open(route: route,
                    appModel: appModel,
                    plannerCoordinator: plannerCoordinator,
                    calendarManager: calendarManager,
                    settingsCoordinator: settingsCoordinator)
    }
    
    func parse(url: URL) -> DeepLinkRoute {
        guard url.scheme?.lowercased() == "roots" else {
            return .invalid("Unsupported scheme")
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = (components?.path ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = path.split(separator: "/").map(String.init)
        let queryItems = components?.queryItems ?? []
        func query(_ name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }
        
        if parts.isEmpty {
            return .dashboard
        }
        
        switch parts[0].lowercased() {
        case "dashboard":
            return .dashboard
        case "calendar":
            let date: Date?
            if let dateString = query("date") {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                date = formatter.date(from: dateString)
            } else {
                date = nil
            }
            let view = DeepLinkRoute.CalendarView(rawValue: query("view") ?? "month") ?? .month
            return .calendar(date: date, view: view)
        case "planner":
            return .planner
        case "assignment":
            if parts.count >= 2, let id = UUID(uuidString: parts[1]) {
                return .assignment(id: id)
            } else {
                return .invalid("Missing assignment id")
            }
        case "course":
            if parts.count >= 2, let id = UUID(uuidString: parts[1]) {
                return .course(id: id)
            } else {
                return .invalid("Missing course id")
            }
        case "focus":
            let mode = query("mode").flatMap { LocalTimerMode(rawValue: $0) }
            let activityId = query("activityId").flatMap { UUID(uuidString: $0) }
            return .focus(mode: mode, activityId: activityId)
        case "settings":
            let section = query("section").flatMap { SettingsToolbarIdentifier(rawValue: $0) }
            return .settings(section: section)
        default:
            return .invalid("Unknown path")
        }
    }
    
    private func open(route: DeepLinkRoute,
                      appModel: AppModel,
                      plannerCoordinator: PlannerCoordinator,
                      calendarManager: CalendarManager,
                      settingsCoordinator: SettingsCoordinator) -> Bool {
        switch route {
        case .dashboard:
            appModel.selectedPage = .dashboard
            return true
        case .calendar(let date, _):
            appModel.selectedPage = .calendar
            if let date = date {
                calendarManager.selectedDate = date
            }
            return true
        case .planner:
            appModel.selectedPage = .planner
            return true
        case .assignment(_):
            appModel.selectedPage = .assignments
            return true
        case .course(let id):
            appModel.selectedPage = .courses
            plannerCoordinator.selectedCourseFilter = id
            return true
        case .focus(let mode, let activityId):
            appModel.selectedPage = .timer
            appModel.focusDeepLink = FocusDeepLink(mode: mode, activityId: activityId)
            appModel.focusWindowRequested = true
            return true
        case .settings(let section):
            settingsCoordinator.show(selecting: section ?? .general)
            return true
        case .invalid(let reason):
            print("DeepLink invalid: \(reason)")
            return false
        }
    }
}
