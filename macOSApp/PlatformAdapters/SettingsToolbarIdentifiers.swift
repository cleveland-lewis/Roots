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
    case timer
    case flashcards
    case integrations
    case notifications
    case privacy
    case localModel
    case storage
    case developer

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
        case .timer: return "Timer"
        case .flashcards: return "Flashcards"
        case .integrations: return "Integrations"
        case .notifications: return "Notifications"
        case .privacy: return "Privacy"
        case .localModel: return "Local AI Model"
        case .storage: return "Storage"
        case .developer: return "Developer"
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
        case .timer: return "timer"
        case .flashcards: return "rectangle.stack.badge.person.crop"
        case .integrations: return "arrow.triangle.2.circlepath.circle"
        case .notifications: return "bell.badge"
        case .privacy: return "lock.shield"
        case .localModel: return "cpu"
        case .storage: return "externaldrive"
        case .developer: return "hammer.fill"
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
