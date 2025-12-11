import SwiftUI
import Combine

@MainActor
final class AppPreferences: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()

    // Interaction
    @AppStorage("preferences.enableHoverWiggle") var enableHoverWiggle: Bool = true
    @AppStorage("preferences.enableHaptics") var enableHaptics: Bool = true

    // Accessibility
    @AppStorage("preferences.reduceMotion") var reduceMotion: Bool = false
    @AppStorage("preferences.highContrast") var highContrast: Bool = false
    @AppStorage("preferences.reduceTransparency") var reduceTransparency: Bool = false

    // Appearance
    @AppStorage("preferences.glassIntensity") var glassIntensity: Double = 0.5
    @AppStorage("preferences.accentColorName") var accentColorName: String = "Blue"

    // Layout
    @AppStorage("preferences.tabBarMode") var tabBarModeRaw: String = TabBarMode.iconsAndText.rawValue
    @AppStorage("preferences.sidebarBehavior") var sidebarBehaviorRaw: String = SidebarBehavior.automatic.rawValue

    var tabBarMode: TabBarMode {
        TabBarMode(rawValue: tabBarModeRaw) ?? .iconsAndText
    }

    var sidebarBehavior: SidebarBehavior {
        SidebarBehavior(rawValue: sidebarBehaviorRaw) ?? .automatic
    }

    // AppAccent enum and derived color
    enum AppAccent: String, CaseIterable, Identifiable {
        case blue = "Blue"
        case purple = "Purple"
        case pink = "Pink"
        case red = "Red"
        case orange = "Orange"
        case yellow = "Yellow"
        case green = "Green"
        case mint = "Mint"
        case teal = "Teal"
        case cyan = "Cyan"
        case indigo = "Indigo"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .blue: return .blue
            case .purple: return .purple
            case .pink: return .pink
            case .red: return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .green: return .green
            case .mint: return .mint
            case .teal: return .teal
            case .cyan: return .cyan
            case .indigo: return .indigo
            }
        }
    }

    var currentAccentColor: Color {
        AppAccent(rawValue: accentColorName)?.color ?? .blue
    }
}

// MARK: - View Modifiers

struct WiggleOnHoverModifier: ViewModifier {
    @EnvironmentObject private var preferences: AppPreferences
    @State private var hovering = false

    func body(content: Content) -> some View {
        Group {
            if preferences.enableHoverWiggle {
                content
                    .scaleEffect(hovering ? 1.015 : 1.0)
                    .rotationEffect(.degrees(hovering ? 0.6 : 0))
                    .animation(.easeOut(duration: 0.16), value: hovering)
                    .onHover { hovering = $0 }
            } else {
                content
            }
        }
    }
}

struct RootsGlassBackgroundModifier: ViewModifier {
    @EnvironmentObject private var preferences: AppPreferences
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        // If reduceTransparency is set, use a solid background (less transparency). Otherwise use material.
        if preferences.reduceTransparency {
            let background: AnyShapeStyle = AnyShapeStyle(Color(nsColor: NSColor.windowBackgroundColor))
            return content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(background)
                )
        }

        let intensity = preferences.highContrast ? 1.0 : preferences.glassIntensity
        let background: AnyShapeStyle = preferences.highContrast
            ? AnyShapeStyle(Color.primary.opacity(0.08))
            : AnyShapeStyle(DesignSystem.Materials.hud.opacity(intensity))

        return content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
            )
    }
}

extension View {
    func wiggleOnHover() -> some View {
        modifier(WiggleOnHoverModifier())
    }

    func rootsGlassBackground(cornerRadius: CGFloat = 20) -> some View {
        modifier(RootsGlassBackgroundModifier(cornerRadius: cornerRadius))
    }
}
