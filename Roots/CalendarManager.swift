import Foundation
import Combine
import EventKit
import AppKit
import _Concurrency
import SwiftUI

@MainActor
final class CalendarManager: ObservableObject, LoadableViewModel {
    // Loadable conformance
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String? = nil
    nonisolated let objectWillChange = ObservableObjectPublisher()

    static let shared = CalendarManager()
    let store = EKEventStore()

    // Persistent selection
    @AppStorage("selectedCalendarID") var selectedCalendarID: String = ""
    @AppStorage("selectedReminderListID") var selectedReminderListID: String = ""

    // Sources for pickers
    @Published var availableCalendars: [EKCalendar] = []
    @Published var availableReminderLists: [EKCalendar] = []

    // Data
    @Published var dailyEvents: [EKEvent] = []
    @Published var reminders: [EKReminder] = []
    @Published var cachedMonthEvents: [EKEvent] = []
    @Published var selectedDate: Date? = nil

    // Permissions
    @Published var eventAuthorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var reminderAuthorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    @Published var isAuthorized: Bool = false
    @Published var isCalendarAccessDenied: Bool = false
    @Published var isRemindersAccessDenied: Bool = false

    // Helpers used by AddEventPopup
    var writableCalendars: [EKCalendar] { store.calendars(for: .event).filter { $0.allowsContentModifications } }
    var defaultCalendarForNewEvents: EKCalendar? { store.defaultCalendarForNewEvents }
    func defaultCalendarForNewReminders() -> EKCalendar? { store.defaultCalendarForNewReminders() }

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(storeChanged), name: .EKEventStoreChanged, object: store)
        _Concurrency.Task { await self.refreshAuthStatus() }
    }

    func refreshAuthStatus() async {
        await MainActor.run {
            self.eventAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
            self.reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            self.isCalendarAccessDenied = (self.eventAuthorizationStatus == .denied || self.eventAuthorizationStatus == .restricted)
            self.isRemindersAccessDenied = (self.reminderAuthorizationStatus == .denied || self.reminderAuthorizationStatus == .restricted)
            self.isAuthorized = (self.eventAuthorizationStatus == .fullAccess || self.eventAuthorizationStatus == .authorized) || (self.reminderAuthorizationStatus == .fullAccess || self.reminderAuthorizationStatus == .authorized)
        }
        if self.isAuthorized {
            await refreshSources()
            await refreshAll()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .EKEventStoreChanged, object: store)
    }

    // MARK: - Permissions & Sources

    func checkPermissionsOnStartup() async {
        let eventStatus = EKEventStore.authorizationStatus(for: .event)
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)

        await MainActor.run {
            self.eventAuthorizationStatus = eventStatus
            self.reminderAuthorizationStatus = reminderStatus
            self.isCalendarAccessDenied = (eventStatus == .denied || eventStatus == .restricted)
            self.isRemindersAccessDenied = (reminderStatus == .denied || reminderStatus == .restricted)
            self.isAuthorized = (eventStatus == .fullAccess || eventStatus == .authorized) || (reminderStatus == .fullAccess || reminderStatus == .authorized)
        }

        if isAuthorized {
            await MainActor.run { refreshSources() }
            await refreshAll()
        }
    }

    @MainActor
    func refreshSources() {
        self.availableCalendars = store.calendars(for: .event)
        self.availableReminderLists = store.calendars(for: .reminder)

        if selectedCalendarID.isEmpty, let defaultCal = store.defaultCalendarForNewEvents {
            selectedCalendarID = defaultCal.calendarIdentifier
        }
        if selectedReminderListID.isEmpty, let defaultList = store.defaultCalendarForNewReminders() {
            selectedReminderListID = defaultList.calendarIdentifier
        }
    }

    // MARK: - Refreshing

    func refreshAll() async {
        guard isAuthorized else { return }

        // Fetch ALL events for the day; Views will distinguish school vs other using selectedCalendarID
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicateAll = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let eventsFound = store.events(matching: predicateAll).sorted { $0.startDate < $1.startDate }

        await MainActor.run {
            self.dailyEvents = eventsFound
        }

        // Reminders - keep it filtered by selectedReminderListID
        let listsToSearch = store.calendars(for: .reminder).filter { $0.calendarIdentifier == selectedReminderListID }

        if !listsToSearch.isEmpty {
            let predicate = store.predicateForReminders(in: listsToSearch)
            store.fetchReminders(matching: predicate) { foundReminders in
                DispatchQueue.main.async {
                    self.reminders = foundReminders ?? []
                }
            }
        } else {
            await MainActor.run { self.reminders = [] }
        }

        refreshMonthlyCache(for: Date())
    }

    func refreshMonthlyCache(for date: Date) {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return }

        let predicate = store.predicateForEvents(withStart: monthStart, end: monthEnd, calendars: nil)
        let monthEvents = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        DispatchQueue.main.async {
            self.cachedMonthEvents = monthEvents
        }
    }

    // Helper
    func isSchoolEvent(_ event: EKEvent) -> Bool {
        return event.calendar.calendarIdentifier == selectedCalendarID
    }

    // MARK: - Request Access
    func requestAccess() async {
        do {
            if #available(macOS 14.0, *) {
                try await store.requestFullAccessToEvents()
                _ = try await store.requestFullAccessToReminders()
            } else {
                _ = try await store.requestAccess(to: .event)
                _ = try await store.requestAccess(to: .reminder)
            }
            await checkPermissionsOnStartup()
        } catch {
            print("Access request failed: \(error)")
        }
    }

    func requestCalendarAccess() async {
        do {
            if #available(macOS 14.0, *) {
                _ = try await store.requestFullAccessToEvents()
            } else {
                _ = try await store.requestAccess(to: .event)
            }
            await refreshAuthStatus()
        } catch {
            print("Calendar access request failed: \(error)")
        }
    }

    func requestRemindersAccess() async {
        do {
            if #available(macOS 14.0, *) {
                _ = try await store.requestFullAccessToReminders()
            } else {
                _ = try await store.requestAccess(to: .reminder)
            }
            await refreshAuthStatus()
        } catch {
            print("Reminders access request failed: \(error)")
        }
    }

    // Create and save events (used by AddEventPopup)
    func saveEvent(title: String,
                   startDate: Date,
                   endDate: Date,
                   isAllDay: Bool,
                   location: String,
                   notes: String,
                   calendar: EKCalendar?) async throws {
        guard let targetCalendar = calendar ?? store.defaultCalendarForNewEvents else { return }

        let newEvent = EKEvent(eventStore: store)
        newEvent.title = title
        newEvent.startDate = startDate
        newEvent.endDate = endDate
        newEvent.isAllDay = isAllDay
        newEvent.location = location
        newEvent.notes = notes
        newEvent.calendar = targetCalendar

        try store.save(newEvent, span: .thisEvent)
        await refreshAll()
    }

    @objc private func storeChanged() {
        _Concurrency.Task { await refreshAll() }
    }

    func openCalendarPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
    }

    // Backwards compatible API used in other views
    func openSystemPrivacySettings() {
        openCalendarPrivacySettings()
    }
}
