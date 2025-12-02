import SwiftUI

struct SettingsPane_Interface: View {
    @EnvironmentObject private var settings: AppSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            GroupBox {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Light glass strength")
                            Spacer()
                            Text("\(settings.glassStrength.light, format: .percent.precision(.fractionLength(0)))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { settings.glassStrength.light },
                            set: { settings.glassStrength = GlassStrength(light: $0, dark: settings.glassStrength.dark) }
                        ), in: 0.05...0.5)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Dark glass strength")
                            Spacer()
                            Text("\(settings.glassStrength.dark, format: .percent.precision(.fractionLength(0)))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { settings.glassStrength.dark },
                            set: { settings.glassStrength = GlassStrength(light: settings.glassStrength.light, dark: $0) }
                        ), in: 0.05...0.5)
                    }
                }
            } label: {
                Label("Glass", systemImage: "circle.hexagongrid")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Card radius", selection: $settings.cardRadius) {
                        ForEach(CardRadius.allCases) { radius in
                            Text(radius.label).tag(radius)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Animation softness")
                        Slider(value: $settings.animationSoftness, in: 0.15...1)
                        Text("Higher values make transitions feel gentler.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } label: {
                Label("Geometry & Motion", systemImage: "sparkles")
            }

            Spacer()

            Divider().padding(.vertical)

            tabEditor
        }
        .frame(maxWidth: 640)
    }
}
