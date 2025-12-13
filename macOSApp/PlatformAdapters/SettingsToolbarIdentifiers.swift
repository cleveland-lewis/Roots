#if os(macOS)
import AppKit

enum SettingsToolbarIdentifier: String, CaseIterable, Identifiable {
    case general
    case calendar
    case reminders
    case planner
    case courses
    case semesters
    case interface
    case profiles
    case flashcards
    case notifications
    case privacy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return "General"
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        case .planner: return "Planner"
        case .courses: return "Courses"
        case .semesters: return "Semesters"
        case .interface: return "Interface"
        case .profiles: return "Profiles"
        case .flashcards: return "Flashcards"
        case .notifications: return "Notifications"
        case .privacy: return "Privacy"
        }
    }

    var systemImageName: String {
        switch self {
        case .general: return "gearshape"
        case .calendar: return "calendar"
        case .reminders: return "list.bullet.rectangle"
        case .planner: return "pencil.and.list.clipboard"
        case .courses: return "books.vertical"
        case .semesters: return "graduationcap"
        case .interface: return "macwindow"
        case .profiles: return "person.crop.circle"
        case .flashcards: return "rectangle.stack.badge.person.crop"
        case .notifications: return "bell.badge"
        case .privacy: return "lock.shield"
        }
    }

    var toolbarItemIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("roots.settings.\(rawValue)")
    }

    var windowTitle: String {
        "Settings"
    }
}
#endif
