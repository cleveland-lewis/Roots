import SwiftUI
import Combine

enum IconLabelMode: String, CaseIterable, Codable {
    case iconsOnly
    case textOnly
    case iconsAndText
}

enum TypographyMode: String, CaseIterable, Codable {
    case system
    case dos
    case rounded
}

struct AppTypography {
    enum TextStyle {
        case headline, title2, body
    }

    static func font(for style: TextStyle, mode: TypographyMode) -> Font {
        switch mode {
        case .system:
            switch style {
            case .headline: return .system(size: 24, weight: .semibold)
            case .title2: return .system(size: 20, weight: .semibold)
            case .body: return .system(size: 16, weight: .regular)
            }
        case .dos:
            switch style {
            case .headline: return .custom("Menlo", size: 24).monospacedDigit()
            case .title2: return .custom("Menlo", size: 20).monospacedDigit()
            case .body: return .custom("Menlo", size: 16).monospacedDigit()
            }
        case .rounded:
            switch style {
            case .headline: return .system(size: 24, weight: .semibold, design: .rounded)
            case .title2: return .system(size: 20, weight: .semibold, design: .rounded)
            case .body: return .system(size: 16, weight: .regular, design: .rounded)
            }
        }
    }
}

final class AppSettings: ObservableObject {
    @Published var accentColor: Color = .accentColor
    @Published var iconLabelMode: IconLabelMode = .iconsAndText
    @Published var typographyMode: TypographyMode = .system

    let lightGlassOpacity: Double = 0.33
    let darkGlassOpacity: Double = 0.17

    func glassOpacity(for scheme: ColorScheme) -> Double {
        scheme == .dark ? darkGlassOpacity : lightGlassOpacity
    }

    func font(for style: AppTypography.TextStyle) -> Font {
        AppTypography.font(for: style, mode: typographyMode)
    }

    func cycleIconLabelMode() {
        let modes = IconLabelMode.allCases
        if let currentIndex = modes.firstIndex(of: iconLabelMode) {
            let nextIndex = (currentIndex + 1) % modes.count
            iconLabelMode = modes[nextIndex]
        }
    }
}
