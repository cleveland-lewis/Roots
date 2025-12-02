import SwiftUI
import AppKit

enum TabBarMode: String, CaseIterable, Identifiable {
    case iconsOnly
    case textOnly
    case iconsAndText

    var id: String { rawValue }

    var label: String {
        switch self {
        case .iconsOnly:   return "Icons"
        case .textOnly:    return "Text"
        case .iconsAndText:return "Icons & Text"
        }
    }

    var systemImageName: String {
        switch self {
        case .iconsOnly:   return "square.grid.2x2"
        case .textOnly:    return "textformat"
        case .iconsAndText:return "square.grid.2x2.and.square"
        }
    }
}

typealias IconLabelMode = TabBarMode

extension IconLabelMode {
    var description: String { label }
}

enum InterfaceStyle: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case auto

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Follow macOS"
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Automatic at Night"
        }
    }
}

enum SidebarBehavior: String, CaseIterable, Identifiable {
    case automatic
    case expanded
    case compact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: return "Auto-collapse"
        case .expanded:  return "Always expanded"
        case .compact:   return "Favor compact mode"
        }
    }
}

enum CardRadius: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        }
    }

    var value: Double {
        switch self {
        case .small:  return 12
        case .medium: return 18
        case .large:  return 26
        }
    }
}

enum TypographyMode: String, CaseIterable, Identifiable {
    case system
    case dos
    case rounded

    var id: String { rawValue }
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

struct GlassStrength: Equatable {
    var light: Double
    var dark: Double
}

enum AppAccentColor: String, CaseIterable, Identifiable {
    case multicolor
    case graphite
    case aqua
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green

    var id: String { rawValue }

    var label: String {
        switch self {
        case .multicolor: return "Multicolor (Default)"
        case .graphite: return "Graphite"
        case .aqua: return "Aqua"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        }
    }

    fileprivate var nsColor: NSColor {
        switch self {
        case .multicolor: return NSColor.controlAccentColor
        case .graphite: return NSColor.systemGray
        case .aqua: return NSColor.systemTeal
        case .blue: return NSColor.systemBlue
        case .purple: return NSColor.systemPurple
        case .pink: return NSColor.systemPink
        case .red: return NSColor.systemRed
        case .orange: return NSColor.systemOrange
        case .yellow: return NSColor.systemYellow
        case .green: return NSColor.systemGreen
        }
    }

    var color: Color {
        Color(nsColor: nsColor)
    }
}

@MainActor
final class AppSettingsModel: ObservableObject {
    static let shared = AppSettingsModel()

    private enum Keys {
        static let accentColor = "roots.settings.accentColor"
        static let customAccentEnabled = "roots.settings.customAccentEnabled"
        static let customAccentRed = "roots.settings.customAccent.red"
        static let customAccentGreen = "roots.settings.customAccent.green"
        static let customAccentBlue = "roots.settings.customAccent.blue"
        static let customAccentAlpha = "roots.settings.customAccent.alpha"
        static let interfaceStyle = "roots.settings.interfaceStyle"
        static let glassLightStrength = "roots.settings.glass.light"
        static let glassDarkStrength = "roots.settings.glass.dark"
        static let sidebarBehavior = "roots.settings.sidebarBehavior"
        static let wiggleOnHover = "roots.settings.wiggleOnHover"
        static let tabBarMode = "roots.settings.tabBarMode"
        static let enableGlassEffects = "roots.settings.enableGlassEffects"
        static let cardRadius = "roots.settings.cardRadius"
        static let animationSoftness = "roots.settings.animationSoftness"
        static let typographyMode = "roots.settings.typographyMode"
    }

    @AppStorage(Keys.accentColor) private var accentColorRaw: String = AppAccentColor.multicolor.rawValue
    @AppStorage(Keys.customAccentEnabled) private var customAccentEnabledStorage: Bool = false
    @AppStorage(Keys.customAccentRed) private var customAccentRed: Double = NSColor.systemBlue.redComponent
    @AppStorage(Keys.customAccentGreen) private var customAccentGreen: Double = NSColor.systemBlue.greenComponent
    @AppStorage(Keys.customAccentBlue) private var customAccentBlue: Double = NSColor.systemBlue.blueComponent
    @AppStorage(Keys.customAccentAlpha) private var customAccentAlpha: Double = 1
    @AppStorage(Keys.interfaceStyle) private var interfaceStyleRaw: String = InterfaceStyle.system.rawValue
    @AppStorage(Keys.glassLightStrength) private var glassLightStrength: Double = 0.33
    @AppStorage(Keys.glassDarkStrength) private var glassDarkStrength: Double = 0.17
    @AppStorage(Keys.sidebarBehavior) private var sidebarBehaviorRaw: String = SidebarBehavior.automatic.rawValue
    @AppStorage(Keys.wiggleOnHover) private var wiggleOnHoverStorage: Bool = true
    @AppStorage(Keys.tabBarMode) private var tabBarModeRaw: String = TabBarMode.iconsAndText.rawValue
    @AppStorage(Keys.enableGlassEffects) private var enableGlassEffectsStorage: Bool = true
    @AppStorage(Keys.cardRadius) private var cardRadiusRaw: String = CardRadius.medium.rawValue
    @AppStorage(Keys.animationSoftness) private var animationSoftnessStorage: Double = 0.42
    @AppStorage(Keys.typographyMode) private var typographyModeRaw: String = TypographyMode.system.rawValue

    var accentColorChoice: AppAccentColor {
        get { AppAccentColor(rawValue: accentColorRaw) ?? .multicolor }
        set {
            objectWillChange.send()
            accentColorRaw = newValue.rawValue
        }
    }

    var isCustomAccentEnabled: Bool {
        get { customAccentEnabledStorage }
        set {
            objectWillChange.send()
            customAccentEnabledStorage = newValue
        }
    }

    var customAccentColor: Color {
        get {
            Color(red: customAccentRed, green: customAccentGreen, blue: customAccentBlue, opacity: customAccentAlpha)
        }
        set {
            guard let components = Self.components(from: newValue) else { return }
            objectWillChange.send()
            customAccentRed = components.red
            customAccentGreen = components.green
            customAccentBlue = components.blue
            customAccentAlpha = components.alpha
        }
    }

    var activeAccentColor: Color {
        isCustomAccentEnabled ? customAccentColor : accentColorChoice.color
    }

    var interfaceStyle: InterfaceStyle {
        get { InterfaceStyle(rawValue: interfaceStyleRaw) ?? .system }
        set {
            objectWillChange.send()
            interfaceStyleRaw = newValue.rawValue
        }
    }

    var glassStrength: GlassStrength {
        get { GlassStrength(light: glassLightStrength, dark: glassDarkStrength) }
        set {
            objectWillChange.send()
            glassLightStrength = newValue.light
            glassDarkStrength = newValue.dark
        }
    }

    var sidebarBehavior: SidebarBehavior {
        get { SidebarBehavior(rawValue: sidebarBehaviorRaw) ?? .automatic }
        set {
            objectWillChange.send()
            sidebarBehaviorRaw = newValue.rawValue
        }
    }

    var wiggleOnHover: Bool {
        get { wiggleOnHoverStorage }
        set {
            objectWillChange.send()
            wiggleOnHoverStorage = newValue
        }
    }

    var tabBarMode: TabBarMode {
        get { TabBarMode(rawValue: tabBarModeRaw) ?? .iconsAndText }
        set {
            objectWillChange.send()
            tabBarModeRaw = newValue.rawValue
        }
    }

    var iconLabelMode: TabBarMode {
        get { tabBarMode }
        set { tabBarMode = newValue }
    }

    var enableGlassEffects: Bool {
        get { enableGlassEffectsStorage }
        set {
            objectWillChange.send()
            enableGlassEffectsStorage = newValue
        }
    }

    var cardRadius: CardRadius {
        get { CardRadius(rawValue: cardRadiusRaw) ?? .medium }
        set {
            objectWillChange.send()
            cardRadiusRaw = newValue.rawValue
        }
    }

    var cardCornerRadius: Double { cardRadius.value }

    var animationSoftness: Double {
        get { animationSoftnessStorage }
        set {
            objectWillChange.send()
            animationSoftnessStorage = newValue
        }
    }

    var typographyMode: TypographyMode {
        get { TypographyMode(rawValue: typographyModeRaw) ?? .system }
        set {
            objectWillChange.send()
            typographyModeRaw = newValue.rawValue
        }
    }

    func font(for style: AppTypography.TextStyle) -> Font {
        AppTypography.font(for: style, mode: typographyMode)
    }

    func glassOpacity(for scheme: ColorScheme) -> Double {
        guard enableGlassEffects else { return 0 }
        return scheme == .dark ? glassStrength.dark : glassStrength.light
    }

    private static func components(from color: Color) -> (red: Double, green: Double, blue: Double, alpha: Double)? {
        guard let cgColor = color.cgColor else { return nil }
        guard let nsColor = NSColor(cgColor: cgColor) else { return nil }
        let rgb = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        return (Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent), Double(rgb.alphaComponent))
    }

    init() {}
}

typealias AppSettings = AppSettingsModel
