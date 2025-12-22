import SwiftUI
#if os(macOS)
import AppKit
#elseif os(watchOS)
import SwiftUI
#else
import UIKit
#endif

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
        
        /// Global accent color - inherits the app-wide accent
        /// Apply this to all generic UI elements (buttons, toggles, selections, etc.)
        /// DO NOT use for semantic colors (event categories, course colors, status indicators)
        static var accent: Color { .accentColor }

        // Semantic macOS / iOS colors to match Apple HIG
        static var appBackground: Color {
            #if os(macOS)
            return Color(nsColor: .windowBackgroundColor)
            #elseif os(watchOS)
            return Color.black
            #else
            return Color(
                uiColor: UIColor { traits in
                    switch traits.userInterfaceStyle {
                    case .dark:
                        return UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
                    default:
                        return UIColor(red: 0.94, green: 0.94, blue: 0.95, alpha: 1)
                    }
                }
            )
            #endif
        }

        static var sidebarBackground: Color {
            #if os(macOS)
            return Color(nsColor: .controlBackgroundColor)
            #elseif os(watchOS)
            return Color.black
            #else
            return Color(uiColor: .secondarySystemBackground)
            #endif
        }

        static var cardBackground: Color {
            #if os(macOS)
            return Color(nsColor: .textBackgroundColor)
            #elseif os(watchOS)
            return Color.black.opacity(0.8)
            #else
            return Color(uiColor: .systemBackground)
            #endif
        }

        static var groupedBackground: Color {
            #if os(macOS)
            return Color(nsColor: .underPageBackgroundColor)
            #elseif os(watchOS)
            return Color.black
            #else
            return Color(uiColor: .systemGroupedBackground)
            #endif
        }

        static var liquidMaterial: Material { DesignSystem.Materials.hud }

        static func background(for colorScheme: ColorScheme) -> Color {
            return appBackground
        }

        /// Semantic neutral line color that inverts by color scheme:
        /// - Light mode: charcoal (matches dark-mode app background)
        /// - Dark mode: white (matches light-mode app background)
        static func neutralLine(for colorScheme: ColorScheme) -> Color {
            #if os(macOS)
            func resolvedBackground(_ appearanceName: NSAppearance.Name) -> NSColor {
                var color = NSColor.windowBackgroundColor
                if let appearance = NSAppearance(named: appearanceName) {
                    appearance.performAsCurrentDrawingAppearance {
                        color = NSColor.windowBackgroundColor
                    }
                }
                return color
            }
            let lightBackground = resolvedBackground(.aqua)
            let darkBackground = resolvedBackground(.darkAqua)
            // Invert: light scheme gets the dark background (charcoal), dark scheme gets light background (white)
            return colorScheme == .dark ? Color(lightBackground) : Color(darkBackground)
            #elseif os(watchOS)
            return Color.gray.opacity(colorScheme == .dark ? 0.6 : 0.4)
            #else
            let lightTrait = UITraitCollection(userInterfaceStyle: .light)
            let darkTrait = UITraitCollection(userInterfaceStyle: .dark)
            let light = UIColor.systemBackground.resolvedColor(with: lightTrait)
            let dark = UIColor.systemBackground.resolvedColor(with: darkTrait)
            return colorScheme == .dark ? Color(light) : Color(dark)
            #endif
        }
    }

    // MARK: - Layout (8pt Grid)
    struct Layout {
        struct spacing {
            static let small: CGFloat = 8
            static let medium: CGFloat = 16
            static let large: CGFloat = 24
            static let extraLarge: CGFloat = 32
        }

        struct padding {
            static let window: CGFloat = 20
            static let card: CGFloat = 16
        }

        static let cornerRadiusSmall: CGFloat = 12
        static let cornerRadiusStandard: CGFloat = 16
        static let cornerRadiusLarge: CGFloat = 24

        // Shared sizing tokens for rows and pills
        struct rowHeight {
            static let small: CGFloat = 32
            static let medium: CGFloat = 44
            static let large: CGFloat = 56
        }

        struct radii {
            static let card: CGFloat = 22
            static let block: CGFloat = 15
            static let pill: CGFloat = 10
        }
    }

    // Backwards-compatible spacing tokens
    struct Spacing {
        static let xsmall: CGFloat = 4
        static let small: CGFloat = Layout.spacing.small
        static let medium: CGFloat = Layout.spacing.medium
        static let large: CGFloat = Layout.spacing.large
    }

    // MARK: - Typography (Semantic Styles)
    struct Typography {
        static let display = Font.largeTitle.weight(.bold)
        static let header = Font.title2.bold()
        static let subHeader = Font.headline.weight(.medium)
        static let body = Font.body
        static let caption = Font.caption

        // Backwards-compatible aliases
        static let title = Font.title2.weight(.semibold)
    }

    struct Materials {
        // Semantic materials aligned to Apple HIG guidance
        static let sidebar: Material = .bar
        static let card: Material = .regularMaterial
        static let popup: Material = .thickMaterial
        static let hud: Material = .ultraThinMaterial
        // Surface materials used by smaller components
        static let surface: Material = .regularMaterial
        static let surfaceHover: Material = .thickMaterial
    }

    struct Corners {
        static let small: CGFloat = Layout.cornerRadiusSmall
        static let medium: CGFloat = Layout.cornerRadiusStandard
        static let large: CGFloat = Layout.cornerRadiusLarge
        static let card: CGFloat = Layout.radii.card
        static let block: CGFloat = Layout.radii.block
        static let pill: CGFloat = Layout.radii.pill
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
