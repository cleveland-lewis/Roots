import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettingsModel
    // design tokens
    @State private var selectedMaterial: DesignMaterial = .regular

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("General")) {
                    Toggle("Use 24-hour time", isOn: $settings.use24HourTime)
                    Toggle("Show Energy Panel", isOn: $settings.showEnergyPanel)
                    Toggle("High Contrast Mode", isOn: $settings.highContrastMode)
                }

                Section(header: Text("Workday")) {
                    DatePicker("Start", selection: Binding(
                        get: { settings.date(from: settings.defaultWorkdayStart) },
                        set: { settings.defaultWorkdayStart = settings.components(from: $0) }
                    ), displayedComponents: [.hourAndMinute])
                    DatePicker("End", selection: Binding(
                        get: { settings.date(from: settings.defaultWorkdayEnd) },
                        set: { settings.defaultWorkdayEnd = settings.components(from: $0) }
                    ), displayedComponents: [.hourAndMinute])
                }

                Section(header: Text("Advanced")) {
                    NavigationLink(destination: DebugSettingsView(selectedMaterial: $selectedMaterial)) {
                        Label("Developer", systemImage: "hammer")
                    }
                }

                Section(header: Text("Design")) {
                    Picker("Material", selection: $selectedMaterial) {
                        ForEach(DesignSystem.materials, id: \.id) { token in
                            Text(token.name).tag(token as DesignMaterial)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            #if os(iOS)
            #if os(iOS)
            .listStyle(.insetGrouped)
#else
            .listStyle(.plain)
#endif
#else
            .listStyle(.plain)
#endif
            .navigationTitle("Settings")
            .onChange(of: settings.use24HourTime) { _ in settings.save() }
            .onChange(of: settings.showEnergyPanel) { _ in settings.save() }
            .onChange(of: settings.highContrastMode) { _ in settings.save() }
            .onChange(of: settings.defaultWorkdayStart) { _ in settings.save() }
            .onChange(of: settings.defaultWorkdayEnd) { _ in settings.save() }
        }
        .rootsSystemBackground()
    }
}

private struct DebugSettingsView: View {
    @Binding var selectedMaterial: DesignMaterial

    var body: some View {
        Form {
            Toggle("Enable verbose logging", isOn: .constant(false))
            Button("Reset demo data") { }

            Section(header: Text("Design debug")) {
                HStack {
                    Text("Selected material")
                    Spacer()
                    Text(selectedMaterial.name)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Developer")
    }
}

#Preview {
    SettingsView()
}
