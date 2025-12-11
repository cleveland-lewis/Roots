import SwiftUI

struct SettingsPane_Interface: View {
    @EnvironmentObject private var settings: AppSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            GroupBox {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                        HStack {
                            Text("Light glass strength")
                            Spacer()
                            Text("\(settings.glassStrength.light, format: .percent.precision(.fractionLength(0)))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { settings.glassStrength.light },
                            set: { newVal in settings.glassStrength = GlassStrength(light: newVal, dark: settings.glassStrength.dark); settings.save() }
                        ), in: 0.05...0.5)
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                        HStack {
                            Text("Dark glass strength")
                            Spacer()
                            Text("\(settings.glassStrength.dark, format: .percent.precision(.fractionLength(0)))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { settings.glassStrength.dark },
                            set: { newVal in settings.glassStrength = GlassStrength(light: settings.glassStrength.light, dark: newVal); settings.save() }
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
                    #if os(macOS)
                    .pickerStyle(.radioGroup)
                    #endif

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Animation softness")
                        Slider(value: Binding(get: { settings.animationSoftness }, set: { newVal in settings.animationSoftness = newVal; settings.save() }), in: 0.15...1)
                        Text("Higher values make transitions feel gentler.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } label: {
                Label("Geometry & Motion", systemImage: "sparkles")
            }

            Spacer()

            GroupBox {
                HStack {
                    Text("Clock format")
                    Spacer()
                    Picker("Clock format", selection: Binding(get: { settings.use24HourTime }, set: { settings.use24HourTime = $0 })) {
                        Text("12-hour").tag(false)
                        Text("24-hour").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                .padding(.vertical, 6)
            } label: {
                Label("Clock", systemImage: "clock")
            }

            Divider().padding(.vertical)

            HStack(spacing: 20) {
                #if os(macOS)
                tabEditor
                Divider()
                #endif
                quickActionsEditor
            }
            .padding(.top)
        }
        .frame(maxWidth: 640)
    }
}
