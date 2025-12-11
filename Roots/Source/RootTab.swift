import Foundation

enum RootTab: String, CaseIterable, Identifiable {
    case dashboard
    case calendar
    case planner
    case assignments
    case courses
    case grades
    case timer
    case decks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:    return "Dashboard"
        case .calendar:     return "Calendar"
        case .planner:      return "Planner"
        case .assignments:  return "Assignments"
        case .courses:      return "Courses"
        case .grades:       return "Grades"
        case .timer:        return "Timer"
        case .decks:        return "Decks"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:    return "square.grid.2x2"
        case .calendar:     return "calendar"
        case .planner:      return "pencil.and.list.clipboard"
        case .assignments:  return "slider.horizontal.3"
        case .courses:      return "book.closed"
        case .grades:       return "number.circle"
        case .timer:        return "timer"
        case .decks:        return "rectangle.stack"
        }
    }

    var logKey: String { title.lowercased().replacingOccurrences(of: " ", with: "") }
}
