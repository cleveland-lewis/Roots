import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var assignmentsStore: AssignmentsStore
    @EnvironmentObject var coursesStore: CoursesStore

    @State private var userName: String = ""
    @State private var showResetSheet = false
    @State private var resetCode: String = ""
    @State private var resetInput: String = ""
    @State private var isResetting = false

    enum StartOfWeek: String, CaseIterable, Identifiable {
        case sunday = "Sunday"
        case monday = "Monday"

        var id: String { rawValue }
    }

    enum DefaultView: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case calendar = "Calendar"
        case planner = "Planner"
        case courses = "Courses"

        var id: String { rawValue }
    }

    @State private var startOfWeek: StartOfWeek = .sunday
    @State private var defaultView: DefaultView = .dashboard

    var body: some View {
        List {
            Section("Personal") {
                TextField("Name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: userName) { _, newValue in
                        settings.userName = newValue
                        settings.save()
                    }
            }

            Section("Preferences") {
                Picker("Start of Week", selection: $startOfWeek) {
                    ForEach(StartOfWeek.allCases) { day in
                        Text(day.rawValue).tag(day)
                    }
                }
                .onChange(of: startOfWeek) { _, newValue in
                    settings.startOfWeek = newValue.rawValue
                    settings.save()
                }

                Picker("Default View", selection: $defaultView) {
                    ForEach(DefaultView.allCases) { view in
                        Text(view.rawValue).tag(view)
                    }
                }
                .onChange(of: defaultView) { _, newValue in
                    settings.defaultView = newValue.rawValue
                    settings.save()
                }
            }

            Section("Display") {
                Toggle("24-Hour Time", isOn: $settings.use24HourTime)
                    .onChange(of: settings.use24HourTime) { _, _ in settings.save() }

                Toggle("Energy Panel", isOn: $settings.showEnergyPanel)
                    .onChange(of: settings.showEnergyPanel) { _, _ in settings.save() }
            }

            Section("Workday") {
                DatePicker("Start", selection: Binding(
                    get: { settings.date(from: settings.defaultWorkdayStart) },
                    set: { settings.defaultWorkdayStart = settings.components(from: $0); settings.save() }
                ), displayedComponents: .hourAndMinute)

                DatePicker("End", selection: Binding(
                    get: { settings.date(from: settings.defaultWorkdayEnd) },
                    set: { settings.defaultWorkdayEnd = settings.components(from: $0); settings.save() }
                ), displayedComponents: .hourAndMinute)
            }

            Section("Danger Zone") {
                Button(role: .destructive) {
                    resetCode = generateResetCode()
                    resetInput = ""
                    showResetSheet = true
                } label: {
                    Text("Reset All Data")
                        .fontWeight(.semibold)
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            // Load current values
            userName = settings.userName ?? ""
            startOfWeek = StartOfWeek(rawValue: settings.startOfWeek ?? "Sunday") ?? .sunday
            defaultView = DefaultView(rawValue: settings.defaultView ?? "Dashboard") ?? .dashboard
        }
        .sheet(isPresented: $showResetSheet) {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reset All Data")
                        .font(.title2.weight(.bold))
                    Text("This will remove all app data including courses, assignments, settings, and cached sessions. This action cannot be undone.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Type the code to confirm")
                        .font(.headline.weight(.semibold))
                    HStack {
                        Text(resetCode)
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                        Spacer()
                    }
                    TextField("Enter code exactly", text: $resetInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disableAutocorrection(true)
                }

                HStack(spacing: 12) {
                    Button("Cancel") { showResetSheet = false }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Reset Now") {
                        performReset()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .keyboardShortcut(.defaultAction)
                    .disabled(resetInput != resetCode || isResetting)
                }
            }
            .padding(26)
            .frame(minWidth: 440, maxWidth: 520)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 22, x: 0, y: 12)
            .padding()
        }
    }

    private func generateResetCode() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<12).compactMap { _ in chars.randomElement() })
    }

    private func performReset() {
        guard resetInput == resetCode else { return }
        isResetting = true
        // Clear app state
        assignmentsStore.resetAll()
        coursesStore.resetAll()
        settings.resetUserDefaults()
        settings.save()
        timerManager.stop()
        // Reset local UI state
        userName = ""
        startOfWeek = .sunday
        defaultView = .dashboard
        resetInput = ""
        showResetSheet = false
        isResetting = false
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    GeneralSettingsView()
        .environmentObject(AppSettingsModel.shared)
        .environmentObject(TimerManager())
        .environmentObject(AssignmentsStore.shared)
        .environmentObject(CoursesStore())
        .frame(width: 500, height: 600)
}
#endif
