#if os(macOS)
import SwiftUI

struct InterfaceSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @EnvironmentObject var preferences: AppPreferences
    @State private var glassIntensity: Double = 0.5

    enum AccentColorOption: String, CaseIterable, Identifiable {
        case blue = "Blue"
        case purple = "Purple"
        case pink = "Pink"
        case red = "Red"
        case orange = "Orange"
        case yellow = "Yellow"
        case green = "Green"
        case teal = "Teal"

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
            case .teal: return .teal
            }
        }
    }

    @State private var selectedAccentColor: AccentColorOption = .blue

    var body: some View {
        Form {
            Section("Accessibility") {
                Toggle("Reduce Motion", isOn: $preferences.reduceMotion)
                    .onChange(of: preferences.reduceMotion) { _, _ in /* AppStorage persists */ }

                Toggle("Increase Contrast", isOn: $preferences.highContrast)
                    .onChange(of: preferences.highContrast) { _, _ in /* AppStorage persists */ }

                Toggle("Reduce Transparency", isOn: $preferences.reduceTransparency)
                    .onChange(of: preferences.reduceTransparency) { _, _ in /* AppStorage persists */ }
            }

            Section("Appearance") {
                VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                    Text("Material Intensity")

                    HStack {
                        Text("Low")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)

                        Slider(value: $glassIntensity, in: 0...1)
                            .onChange(of: glassIntensity) { _, newValue in
                                settings.glassIntensity = newValue
                                settings.save()
                            }

                        Text("High")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Accent Color", selection: $preferences.accentColorName) {
                    ForEach(AppPreferences.AppAccent.allCases) { accent in
                        HStack {
                            Circle().fill(accent.color).frame(width: 12, height: 12)
                            Text(accent.rawValue)
                        }
                        .tag(accent.rawValue)
                    }
                }
                .onChange(of: preferences.accentColorName) { _, newValue in
                    // AppStorage in AppPreferences already persists; UI will read preferences.currentAccentColor
                }
            }

            Section("Layout") {
                Picker("Tab Style", selection: $settings.tabBarMode) {
                    Text("Icons").tag(TabBarMode.iconsOnly)
                    Text("Text").tag(TabBarMode.textOnly)
                    Text("Icons & Text").tag(TabBarMode.iconsAndText)
                }
                .onChange(of: settings.tabBarMode) { _, _ in settings.save() }

                Toggle("Sidebar", isOn: $settings.showSidebarByDefault)
                    .onChange(of: settings.showSidebarByDefault) { _, _ in settings.save() }

                Toggle("Compact Density", isOn: $settings.compactMode)
                    .onChange(of: settings.compactMode) { _, _ in settings.save() }
            }

            Section {
                Toggle("Show Animations", isOn: $settings.showAnimations)
                    .onChange(of: settings.showAnimations) { _, _ in settings.save() }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Enable Haptic Feedback", isOn: $settings.enableHaptics)
                        .onChange(of: settings.enableHaptics) { _, _ in settings.save() }
                    
                    if preferences.reduceMotion {
                        Text("Haptic feedback is disabled when Reduce Motion is enabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Show Tooltips", isOn: $settings.showTooltips)
                    .onChange(of: settings.showTooltips) { _, _ in settings.save() }
            } header: {
                Text("Interactions")
            } footer: {
                Text("Haptic feedback respects accessibility settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // Load current values
            glassIntensity = preferences.glassIntensity
            selectedAccentColor = AccentColorOption(rawValue: preferences.accentColorName) ?? .blue
        }
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    InterfaceSettingsView()
        .environmentObject(AppSettingsModel.shared)
        .environmentObject(AppPreferences())
        .frame(width: 500, height: 600)
}
#endif
#endif
