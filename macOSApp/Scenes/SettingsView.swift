#if os(macOS)
import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettingsModel
    @EnvironmentObject var coursesStore: CoursesStore
    @EnvironmentObject var assignmentsStore: AssignmentsStore
    // design tokens
    @State private var selectedMaterial: DesignMaterial = .regular
    @State private var diagnosticReport: DiagnosticReport? = nil
    @State private var showingHealthCheck = false
    @State private var saveWorkItem: DispatchWorkItem?

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("General")) {
                    Toggle("Use 24-hour time", isOn: $settings.use24HourTime)
                    Toggle("Show Energy Panel", isOn: $settings.showEnergyPanel)
                    Toggle("High Contrast Mode", isOn: $settings.highContrastMode)
                }

                Section(header: Text("Academic")) {
                    // Note: Courses & Semesters management now handled via SettingsRootView
                    // NavigationLink(destination: CoursesSettingsView().environmentObject(coursesStore)) {
                    //     Label("Courses & Semesters", systemImage: "book.closed")
                    // }
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

                Section {
                    Button {
                        diagnosticReport = AppDebugger.shared.runFullDiagnostic(
                            dataManager: coursesStore,
                            calendarManager: CalendarManager.shared,
                            assignmentsStore: assignmentsStore
                        )
                        showingHealthCheck = true
                    } label: {
                        Label("Run Health Check", systemImage: "stethoscope")
                    }
                } footer: {
                    Text("Runs a quick self-diagnostic across data, permissions, and local files.")
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
            .onChange(of: settings.use24HourTime) { _, _ in scheduleSettingsSave() }
            .onChange(of: settings.showEnergyPanel) { _, _ in scheduleSettingsSave() }
            .onChange(of: settings.highContrastMode) { _, _ in scheduleSettingsSave() }
            .onChange(of: settings.defaultWorkdayStart) { _, _ in scheduleSettingsSave() }
            .onChange(of: settings.defaultWorkdayEnd) { _, _ in scheduleSettingsSave() }
        }
        .background(DesignSystem.Colors.appBackground)
        .alert("Health Check", isPresented: $showingHealthCheck, presenting: diagnosticReport) { _ in
            Button("OK", role: .cancel) { }
        } message: { report in
            if report.issues.isEmpty {
                Text("All systems look healthy.")
            } else {
                Text(report.formattedSummary)
            }
        }
    }

    private func scheduleSettingsSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { settings.save() }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
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

#if !DISABLE_PREVIEWS
#Preview {
    SettingsView()
}
#endif
#endif
