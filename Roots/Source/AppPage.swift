import Foundation

enum AppPage: String, CaseIterable, Identifiable {
    case dashboard
    case calendar
    case planner
    case assignments
    case courses
    case grades

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:  return "Dashboard"
        case .calendar:   return "Calendar"
        case .planner:    return "Planner"
        case .assignments:return "Assignments"
        case .courses:    return "Courses"
        case .grades:     return "Grades"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:   return "rectangle.grid.2x2"
        case .calendar:    return "calendar"
        case .planner:     return "square.and.pencil"
        case .assignments: return "checklist"
        case .courses:     return "book.closed"
        case .grades:      return "chart.bar.doc.horizontal"
        }
    }
}
