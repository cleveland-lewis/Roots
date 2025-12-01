import SwiftUI

enum DesignMaterial: String, CaseIterable, Identifiable, Hashable {
    var id: String { rawValue }
    case ultraThin, regular, thick

    var material: Material {
        switch self {
        case .ultraThin: return .ultraThinMaterial
        case .regular: return .regularMaterial
        case .thick: return .thickMaterial
        }
    }

    var name: String {
        switch self {
        case .ultraThin: return "Ultra Thin"
        case .regular: return "Regular"
        case .thick: return "Thick"
        }
    }
}

struct DesignSystem {
    // Global empty state message used across the app
    static let emptyStateMessage = "No data available"
    struct Colors {
        static let primary = Color("Primary")
        static let secondary = Color("Secondary")
        static let destructive = Color.red
        static let subtle = Color("Subtle")
        static let neutral = Color("Neutral")

        static func background(for colorScheme: ColorScheme) -> Color {
            #if os(macOS)
            switch colorScheme {
            case .dark: return Color(nsColor: NSColor.windowBackgroundColor)
            default: return Color(nsColor: NSColor.windowBackgroundColor)
            }
            #else
            switch colorScheme {
            case .dark: return Color(uiColor: UIColor.systemBackground)
            default: return Color(uiColor: UIColor.systemBackground)
            }
            #endif
        }
    }

    struct Typography {
        static let title = Font.system(size: 20, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
    }

    struct Materials {
        static let ultraThin = Material.ultraThinMaterial
        static let regular = Material.regularMaterial
        static let thick = Material.thickMaterial
    }

    struct Corners {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    struct Spacing {
        static let xsmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    struct Icons {
        static let primary = Image(systemName: "star.fill")
        static let settings = Image(systemName: "gearshape")
    }

    struct Cards {
        static let cornerRadius: CGFloat = Corners.medium
        static let inset: CGFloat = Spacing.small
        static let defaultHeight: CGFloat = 260
        // new unified card metrics
        static let cardMinWidth: CGFloat = 260
        static let cardMinHeight: CGFloat = 140
        static let cardCornerRadius: CGFloat = 18
    }

    // semantic helpers
    static func background(for colorScheme: ColorScheme) -> Color {
        Colors.background(for: colorScheme)
    }

    static var materials: [DesignMaterial] { DesignMaterial.allCases }
}
