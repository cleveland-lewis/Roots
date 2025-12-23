import SwiftUI
#if os(iOS)
import EventKit

struct CalendarSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @StateObject private var deviceCalendar = DeviceCalendarManager.shared
    @State private var showRevokeConfirmation = false
    
    var body: some View {
        List {
            if !deviceCalendar.isAuthorized {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text(NSLocalizedString("settings.calendar.not_authorized.title", comment: "Calendar Access Required"))
                            .font(.headline)
                        
                        Text(NSLocalizedString("settings.calendar.not_authorized.message", comment: "Grant calendar access to sync events with your schedule"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            Task {
                                await deviceCalendar.bootstrapOnLaunch()
                            }
                        } label: {
                            Text(NSLocalizedString("settings.calendar.request_access", comment: "Request Access"))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(deviceCalendar.getAvailableCalendars(), id: \.calendarIdentifier) { calendar in
                        Button {
                            settings.selectedSchoolCalendarID = calendar.calendarIdentifier
                            settings.save()
                            Task {
                                await deviceCalendar.refreshEventsForVisibleRange(reason: "calendarChanged")
                            }
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: calendar.cgColor))
                                    .frame(width: 12, height: 12)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(calendar.title)
                                        .foregroundColor(.primary)
                                    
                                    if let source = calendar.source?.title {
                                        Text(source)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if settings.selectedSchoolCalendarID == calendar.calendarIdentifier {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("settings.calendar.school_calendar.header", comment: "School Calendar"))
                } footer: {
                    Text(NSLocalizedString("settings.calendar.school_calendar.footer", comment: "Select the calendar to use for event tracking and scheduling"))
                }
                
                Section {
                    Picker(selection: Binding(
                        get: { refreshRangeOption },
                        set: { newValue in
                            switch newValue {
                            case 0: UserDefaults.standard.set(7, forKey: "calendarRefreshRangeDays")
                            case 1: UserDefaults.standard.set(14, forKey: "calendarRefreshRangeDays")
                            case 2: UserDefaults.standard.set(30, forKey: "calendarRefreshRangeDays")
                            case 3: UserDefaults.standard.set(60, forKey: "calendarRefreshRangeDays")
                            default: break
                            }
                        }
                    )) {
                        Text(NSLocalizedString("settings.calendar.range.1_week", comment: "1 Week")).tag(0)
                        Text(NSLocalizedString("settings.calendar.range.2_weeks", comment: "2 Weeks")).tag(1)
                        Text(NSLocalizedString("settings.calendar.range.1_month", comment: "1 Month")).tag(2)
                        Text(NSLocalizedString("settings.calendar.range.2_months", comment: "2 Months")).tag(3)
                    } label: {
                        Text(NSLocalizedString("settings.calendar.refresh_range", comment: "Refresh Range"))
                    }
                } header: {
                    Text(NSLocalizedString("settings.calendar.scheduling.header", comment: "Scheduling"))
                } footer: {
                    Text(NSLocalizedString("settings.calendar.scheduling.footer", comment: "How far ahead to scan for events when refreshing"))
                }
                
                Section {
                    Button(role: .destructive) {
                        showRevokeConfirmation = true
                    } label: {
                        HStack {
                            Text(NSLocalizedString("settings.calendar.revoke_access", comment: "Revoke Calendar Access"))
                            Spacer()
                        }
                    }
                } footer: {
                    Text(NSLocalizedString("settings.calendar.revoke_access.footer", comment: "Remove calendar access and clear all synced events. You'll need to manually revoke permission in iOS Settings."))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("settings.category.calendar", comment: "Calendar"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            NSLocalizedString("settings.calendar.revoke_access.confirm.title", comment: "Revoke Calendar Access?"),
            isPresented: $showRevokeConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("settings.calendar.revoke_access.confirm.button", comment: "Revoke Access"), role: .destructive) {
                deviceCalendar.revokeAccess()
            }
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("settings.calendar.revoke_access.confirm.message", comment: "This will clear all synced calendar data. You'll need to manually revoke permission in iOS Settings > Roots > Calendars."))
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

#Preview {
    NavigationStack {
        CalendarSettingsView()
            .environmentObject(AppSettingsModel.shared)
    }
}
#endif
