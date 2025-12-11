#if os(macOS)
import SwiftUI
import EventKit

struct RemindersSettingsView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @State private var showingRevokeAlert = false

    private var isAuthorized: Bool {
        calendarManager.reminderAuthorizationStatus == .fullAccess || calendarManager.reminderAuthorizationStatus == .writeOnly
    }

    var body: some View {
        List {
            Section("Reminders Sync") {
                Toggle("Enable Reminders Sync", isOn: Binding(
                    get: { isAuthorized },
                    set: { newValue in
                        if newValue {
                            _Concurrency.Task { await calendarManager.requestAccess() }
                        } else {
                            showingRevokeAlert = true
                        }
                    }
                ))
                .toggleStyle(.switch)

                HStack {
                    Text("Status:")
                        .foregroundStyle(.secondary)
                    if isAuthorized {
                        Text("Connected").foregroundStyle(.green)
                    } else if calendarManager.isRemindersAccessDenied {
                        Text("Access Denied").foregroundStyle(.red)
                        Button("Open Settings") { calendarManager.openSystemPrivacySettings() }
                            .buttonStyle(.link)
                    } else {
                        Text("Not Connected").foregroundStyle(.secondary)
                    }
                }
                .font(DesignSystem.Typography.caption)
            }

            if isAuthorized {
                Section("School List") {
                    Picker("School List", selection: Binding(get: { calendarManager.selectedReminderListID.isEmpty ? nil : calendarManager.selectedReminderListID }, set: { calendarManager.selectedReminderListID = $0 ?? "" })) {
                        Text("Select a List").tag(String?.none)
                        ForEach(calendarManager.availableReminderLists, id: \.calendarIdentifier) { list in
                            HStack {
                                if let cgColor = list.cgColor, let nsColor = NSColor(cgColor: cgColor) {
                                    Circle().fill(Color(nsColor: nsColor)).frame(width: 8, height: 8)
                                } else {
                                    Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                                }
                                Text(list.title)
                            }
                            .tag(Optional(list.calendarIdentifier))
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: calendarManager.selectedReminderListID) { _, _ in
                        _Concurrency.Task { await calendarManager.refreshAll() }
                    }

                    Text("Only reminders from this list will appear in Roots.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .alert("Disable Reminders Sync", isPresented: $showingRevokeAlert) {
            Button("Open System Settings") {
                calendarManager.openSystemPrivacySettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To disconnect Roots from your Reminders, please revoke access in System Settings > Privacy & Security > Reminders.")
        }
        .onAppear {
            _Concurrency.Task { await calendarManager.refreshAuthStatus() }
        }
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    RemindersSettingsView()
        .environmentObject(CalendarManager.shared)
        .frame(width: 500, height: 600)
}
#endif
#endif
