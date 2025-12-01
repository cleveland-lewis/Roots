import SwiftUI

final class AppSettings: ObservableObject {
    // General
    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .system
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true

    // Profile
    @AppStorage("displayName") var displayName: String = ""
    @AppStorage("showCourseCodes") var showCourseCodes: Bool = true

    // Developer
    @AppStorage("enableDebugLogging") var enableDebugLogging: Bool = false

    // Design
    @AppStorage("cardMaterial") var cardMaterial: CardMaterial = .regular
    @AppStorage("cardCornerRadius") var cardCornerRadius: Double = 18

    enum AppearanceMode: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "System"
            case .light:  return "Light"
            case .dark:   return "Dark"
            }
        }
    }

    enum CardMaterial: String, CaseIterable, Identifiable {
        case ultraThin, regular, thick
        var id: String { rawValue }
        var label: String {
            switch self {
            case .ultraThin: return "Ultra Thin"
            case .regular:   return "Regular"
            case .thick:     return "Thick"
            }
        }
    }
}
