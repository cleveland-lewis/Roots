#if os(macOS)
import SwiftUI
import EventKit

struct CalendarSettingsView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var settings: AppSettingsModel
    @State private var showingRevokeAlert = false

    private var isAuthorized: Bool {
        calendarManager.eventAuthorizationStatus == .fullAccess || calendarManager.eventAuthorizationStatus == .writeOnly
    }

    var body: some View {
        List {
            Section("Calendar Sync") {
                Toggle("Enable Calendar Sync", isOn: Binding(
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
                    } else if calendarManager.isCalendarAccessDenied {
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
                Section("School Calendar") {
                    Picker("School Calendar", selection: Binding(get: { calendarManager.selectedCalendarID.isEmpty ? nil : calendarManager.selectedCalendarID }, set: { calendarManager.selectedCalendarID = $0 ?? "" })) {
                        Text("Select a Calendar").tag(String?.none)
                        ForEach(calendarManager.availableCalendars, id: \.calendarIdentifier) { cal in
                            HStack {
                                if let cgColor = cal.cgColor, let nsColor = NSColor(cgColor: cgColor) {
                                    Circle().fill(Color(nsColor: nsColor)).frame(width: 8, height: 8)
                                } else {
                                    Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                                }
                                Text(cal.title)
                            }
                            .tag(Optional(cal.calendarIdentifier))
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: calendarManager.selectedCalendarID) { _, _ in
                        _Concurrency.Task { await calendarManager.refreshAll() }
                    }

                    Text("Select the calendar used for school/academic events.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Scheduling") {
                    Picker("Refresh Range", selection: Binding(
                        get: { refreshRangeOption },
                        set: { newValue in
                            switch newValue {
                            case 0: UserDefaults.standard.set(7, forKey: "calendarRefreshRangeDays")
                            case 1: UserDefaults.standard.set(14, forKey: "calendarRefreshRangeDays")
                            case 2: UserDefaults.standard.set(30, forKey: "calendarRefreshRangeDays")
                            case 3: UserDefaults.standard.set(60, forKey: "calendarRefreshRangeDays")
                            default: break
                            }
                            // Refresh calendar with new range
                            _Concurrency.Task { await calendarManager.refreshAll() }
                        }
                    )) {
                        Text("1 Week").tag(0)
                        Text("2 Weeks").tag(1)
                        Text("1 Month").tag(2)
                        Text("2 Months").tag(3)
                    }
                    .pickerStyle(.menu)
                    
                    Text("How far ahead to scan for events when refreshing.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Calendar View Filter") {
                    Toggle("Show Only School Calendar", isOn: $settings.showOnlySchoolCalendar)
                        .toggleStyle(.switch)
                        .onChange(of: settings.showOnlySchoolCalendar) { _, _ in
                            settings.save()
                            _Concurrency.Task { await calendarManager.refreshAll() }
                        }
                    
                    Text(settings.showOnlySchoolCalendar ? "Calendar UI will only show events from your school calendar." : "Calendar UI will show events from all calendars.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Calendar Picker Lock") {
                    Toggle("Lock Calendar Picker to School", isOn: $settings.lockCalendarPickerToSchool)
                        .toggleStyle(.switch)
                        .onChange(of: settings.lockCalendarPickerToSchool) { _, _ in
                            settings.save()
                        }
                    
                    Text(settings.lockCalendarPickerToSchool ? "New events will always be saved to the school calendar. Users cannot select a different calendar." : "Users can choose which calendar to save new events to.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .alert("Disable Calendar Sync", isPresented: $showingRevokeAlert) {
            Button("Open System Settings") {
                calendarManager.openSystemPrivacySettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To disconnect Roots from your Calendar, please revoke access in System Settings > Privacy & Security > Calendars.")
        }
        .onAppear {
            _Concurrency.Task { await calendarManager.refreshAuthStatus() }
        }
    }
    
    private var refreshRangeDays: Int {
        UserDefaults.standard.integer(forKey: "calendarRefreshRangeDays") != 0 
            ? UserDefaults.standard.integer(forKey: "calendarRefreshRangeDays") 
            : 14
    }
    
    private var refreshRangeOption: Int {
        switch refreshRangeDays {
        case 7: return 0
        case 14: return 1
        case 30: return 2
        case 60: return 3
        default: return 1
        }
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    CalendarSettingsView()
        .environmentObject(CalendarManager.shared)
        .environmentObject(AppSettingsModel.shared)
        .frame(width: 500, height: 600)
}
#endif
#endif
