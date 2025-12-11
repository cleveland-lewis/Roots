import SwiftUI

struct SettingsPane_Appearance: View {
    @EnvironmentObject private var settings: AppSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Accent color", selection: $settings.accentColorChoice) {
                        ForEach(AppAccentColor.allCases) { accent in
                            HStack(spacing: DesignSystem.Layout.spacing.small) {
                                Circle()
                                    .fill(accent.color)
                                    .frame(width: 14, height: 14)
                                Text(accent.label)
                            }
                            .tag(accent)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: settings.accentColorChoice) { _, _ in settings.save() }
                    Toggle("Enable custom accent color", isOn: $settings.isCustomAccentEnabled)
                        .onChange(of: settings.isCustomAccentEnabled) { _, _ in settings.save() }

                    ColorPicker(
                        "Custom accent tint",
                        selection: Binding(
                            get: { settings.customAccentColor },
                            set: { settings.customAccentColor = $0; settings.save() }
                        )
                    )
                    .disabled(!settings.isCustomAccentEnabled)
                    .foregroundStyle(settings.isCustomAccentEnabled ? .primary : .secondary)

                    Text("Custom colors override the built-in palette.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } label: {
                Label("Accent", systemImage: "paintpalette")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Interface style", selection: $settings.interfaceStyle) {
                        ForEach(InterfaceStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.interfaceStyle) { _, _ in settings.save() }

                    Text("Choose how Roots reacts to system appearance changes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } label: {
                Label("Interface", systemImage: "circle.lefthalf.fill")
            }

            Spacer()
        }
        .frame(maxWidth: 640)
    }
}
