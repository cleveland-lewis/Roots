import AppKit

enum SettingsToolbarIdentifier: String, CaseIterable, Identifiable {
    case general
    case appearance
    case interface
    case courses
    case accounts

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .interface: return "Interface"
        case .courses: return "Courses"
        case .accounts: return "Accounts"
        }
    }

    var systemImageName: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .appearance: return "paintpalette"
        case .interface: return "macwindow"
        case .courses: return "books.vertical"
        case .accounts: return "person.crop.circle"
        }
    }

    var toolbarItemIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("roots.settings.\(rawValue)")
    }

    var windowTitle: String {
        "Roots Settings — \(label)"
    }
}
