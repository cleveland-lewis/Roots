#if os(iOS)
import SwiftUI
import Combine

struct AppearanceSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @Environment(\.colorScheme) private var colorScheme
    
    private var interfaceStyle: InterfaceStyle {
        get {
            InterfaceStyle(rawValue: settings.interfaceStyleRaw) ?? .system
        }
        nonmutating set {
            settings.interfaceStyleRaw = newValue.rawValue
        }
    }
    
    var body: some View {
        List {
            Section {
                Picker(selection: Binding(
                    get: { interfaceStyle },
                    set: { newValue in
                        settings.objectWillChange.send()
                        interfaceStyle = newValue
                        settings.save()
                    }
                )) {
                    ForEach([InterfaceStyle.system, .light, .dark], id: \.self) { style in
                        Text(styleLabel(style)).tag(style)
                    }
                } label: {
                    Text(NSLocalizedString("settings.appearance.theme", comment: "Theme"))
                }
                .pickerStyle(.segmented)
            } header: {
                Text(NSLocalizedString("settings.appearance.theme.header", comment: "Appearance"))
            }
            
            Section {
                Toggle(isOn: Binding(
                    get: { settings.enableGlassEffectsStorage },
                    set: { newValue in
                        settings.objectWillChange.send()
                        settings.enableGlassEffectsStorage = newValue
                        settings.save()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.appearance.glass_effects", comment: "Glass Effects"))
                        Text(NSLocalizedString("settings.appearance.glass_effects.detail", comment: "Use translucent backgrounds and blur"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $settings.showAnimationsStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.appearance.animations", comment: "Show Animations"))
                        Text(NSLocalizedString("settings.appearance.animations.detail", comment: "Enable smooth transitions and effects"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: settings.showAnimationsStorage) { _, _ in
                    settings.save()
                }
            } header: {
                Text(NSLocalizedString("settings.appearance.effects.header", comment: "Effects"))
            }
            
            Section {
                Picker(selection: Binding(
                    get: { CardRadius(rawValue: settings.cardRadiusRaw) ?? .medium },
                    set: { newValue in
                        settings.objectWillChange.send()
                        settings.cardRadiusRaw = newValue.rawValue
                        settings.save()
                    }
                )) {
                    ForEach(CardRadius.allCases, id: \.self) { radius in
                        Text(radius.label).tag(radius)
                    }
                } label: {
                    Text(NSLocalizedString("settings.appearance.card_radius", comment: "Card Corner Radius"))
                }
            } header: {
                Text(NSLocalizedString("settings.appearance.style.header", comment: "Style"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("settings.category.appearance", comment: "Appearance"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings.showAnimationsStorage) { _, _ in
            settings.objectWillChange.send()
        }
    }
    
    private func styleLabel(_ style: InterfaceStyle) -> String {
        switch style {
        case .system:
            return NSLocalizedString("settings.appearance.theme.system", comment: "System")
        case .light:
            return NSLocalizedString("settings.appearance.theme.light", comment: "Light")
        case .dark:
            return NSLocalizedString("settings.appearance.theme.dark", comment: "Dark")
        case .auto:
            return NSLocalizedString("settings.appearance.theme.auto", comment: "Auto")
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
            .environmentObject(AppSettingsModel.shared)
    }
}
#endif
