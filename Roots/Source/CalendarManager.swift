import Foundation
import Combine
import EventKit
import AppKit
import _Concurrency
import SwiftUI

@MainActor
final class CalendarManager: ObservableObject, @MainActor LoadableViewModel {
    // Loadable conformance
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String? = nil
    let objectWillChange = ObservableObjectPublisher()

    static let shared = CalendarManager()
    let store = EKEventStore()
    private let cacheURL: URL?

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
    private let lastPlanKey = "roots.lastDailyPlan"

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

    // MARK: - Insights

    func nextEvent(allEvents: [EKEvent]) -> EKEvent? {
        let upcoming = allEvents.filter { $0.startDate > Date() }.sorted { $0.startDate < $1.startDate }
        return upcoming.first
    }

    func tasksDueTomorrow(using assignmentsStore: AssignmentsStore) -> Int {
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) else { return 0 }
        let start = tomorrow
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return assignmentsStore.tasks.filter { task in
            guard let due = task.due else { return false }
            return due >= start && due < end
        }.count
    }

    func tasksDueThisWeek(using assignmentsStore: AssignmentsStore) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 7, to: start) else { return 0 }
        return assignmentsStore.tasks.filter { task in
            guard let due = task.due else { return false }
            return due >= start && due < end
        }.count
    }

    func daysLeftInSemester(using dataManager: CoursesStore) -> Int? {
        let today = Date()
        guard let active = dataManager.semesters.first(where: { $0.startDate <= today && today <= $0.endDate }) else {
            return nil
        }
        let comps = Calendar.current.dateComponents([.day], from: today, to: active.endDate)
        return comps.day
    }

    private init() {
        let fm = FileManager.default
        if let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let folder = dir.appendingPathComponent("RootsCalendarCache", isDirectory: true)
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            cacheURL = folder.appendingPathComponent("month_events.json")
        } else {
            cacheURL = nil
        }
        NotificationCenter.default.addObserver(self, selector: #selector(storeChanged), name: .EKEventStoreChanged, object: store)
        loadCachedEvents()
        _Concurrency.Task { await self.refreshAuthStatus() }
    }

    func refreshAuthStatus() async {
        await MainActor.run {
            self.eventAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
            self.reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            self.isCalendarAccessDenied = (self.eventAuthorizationStatus == .denied || self.eventAuthorizationStatus == .restricted)
            self.isRemindersAccessDenied = (self.reminderAuthorizationStatus == .denied || self.reminderAuthorizationStatus == .restricted)
            self.isAuthorized = (self.eventAuthorizationStatus == .fullAccess || self.eventAuthorizationStatus == .writeOnly) || (self.reminderAuthorizationStatus == .fullAccess || self.reminderAuthorizationStatus == .writeOnly)
        }
        if self.isAuthorized {
            refreshSources()
            await refreshAll()
            await planTodayIfNeeded(tasks: AssignmentsStore.shared.tasks)
        }
    }

    /// Ensures the month cache is hydrated and surfaces a real loading state.
    func ensureMonthCache(for date: Date) {
        _Concurrency.Task { [weak self] in
            guard let self else { return }
            _ = try await self.withLoading(message: "Loading calendar…") {
                if !self.isAuthorized {
                    await self.checkPermissionsOnStartup()
                } else {
                    self.refreshMonthlyCache(for: date)
                }
                return ()
            }
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
            self.isAuthorized = (eventStatus == .fullAccess || eventStatus == .writeOnly) || (reminderStatus == .fullAccess || reminderStatus == .writeOnly)
        }

        if isAuthorized {
            await MainActor.run { refreshSources() }
            await refreshAll()
            await planTodayIfNeeded(tasks: AssignmentsStore.shared.tasks)
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

        // After refreshing, attempt daily planning for tasks due today
        await planTodayIfNeeded(tasks: AssignmentsStore.shared.tasks)
    }

    func refreshMonthlyCache(for date: Date) {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return }

        let predicate = store.predicateForEvents(withStart: monthStart, end: monthEnd, calendars: nil)
        let monthEvents = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        DispatchQueue.main.async {
            self.cachedMonthEvents = monthEvents
            self.saveCachedEvents(monthEvents)
        }
    }

    // Helper
    func isSchoolEvent(_ event: EKEvent) -> Bool {
        return event.calendar.calendarIdentifier == selectedCalendarID
    }

    // MARK: - Daily planning

    func planTodayIfNeeded(tasks: [AppTask]) async {
        guard isAuthorized else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let last = UserDefaults.standard.object(forKey: lastPlanKey) as? Date,
           cal.isDate(last, inSameDayAs: today) {
            return
        }

        let dueToday = tasks.filter { task in
            guard !task.isCompleted, let due = task.due else { return false }
            return cal.isDate(due, inSameDayAs: today)
        }
        guard !dueToday.isEmpty else {
            UserDefaults.standard.set(today, forKey: lastPlanKey)
            return
        }

        for task in dueToday {
            await syncPlannerTaskToCalendar(task)
        }

        UserDefaults.standard.set(today, forKey: lastPlanKey)
    }

    // MARK: - Planner sync into calendar

    /// Map planner tasks to calendar events. Merges into existing "Homework" blocks when possible, otherwise creates a new event in the selected calendar within work hours.
    func syncPlannerTaskToCalendar(_ task: AppTask, workDayStart: Int = 9, workDayEnd: Int = 17) async {
        guard !selectedCalendarID.isEmpty else { return }
        guard let targetCalendar = store.calendars(for: .event).first(where: { $0.calendarIdentifier == selectedCalendarID }) else { return }

        let durationMinutes = task.estimatedMinutes > 0 ? task.estimatedMinutes : 45
        let cal = Calendar.current
        let taskDay = cal.startOfDay(for: task.due ?? Date())
        guard let dayStart = cal.date(bySettingHour: workDayStart, minute: 0, second: 0, of: taskDay),
              let dayEnd = cal.date(bySettingHour: workDayEnd, minute: 0, second: 0, of: taskDay) else { return }

        let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: [targetCalendar])
        let dayEvents = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        let hwEvents = dayEvents.filter { $0.title.localizedCaseInsensitiveContains("homework") || $0.title.localizedCaseInsensitiveContains("practice") }

        // Try to extend an existing homework/practice event if it fits without overlapping others and within work hours.
        if let hw = hwEvents.first, let merged = extend(event: hw, byMinutes: durationMinutes, within: dayStart...dayEnd, avoiding: dayEvents) {
            save(event: merged)
            return
        }

        // Otherwise, place a new event in the first available gap.
        if let slotStart = firstAvailableSlot(durationMinutes: durationMinutes, within: dayStart...dayEnd, avoiding: dayEvents) {
            let newEvent = EKEvent(eventStore: store)
            newEvent.calendar = targetCalendar
            newEvent.title = taskTitle(for: task)
            newEvent.startDate = slotStart
            newEvent.endDate = slotStart.addingTimeInterval(Double(durationMinutes) * 60)
            newEvent.notes = taskNotes(for: task)
            save(event: newEvent)
        }
    }

    private func taskTitle(for task: AppTask) -> String {
        if task.type == .practiceHomework {
            return "Homework: \(task.title)"
        }
        return task.title
    }

    private func taskNotes(for task: AppTask) -> String {
        var parts: [String] = []
        if let notes = task.attachments.first?.name {
            parts.append("Attachment: \(notes)")
        }
        parts.append("[Planner] Auto-scheduled")
        return parts.joined(separator: "\n")
    }

    private func extend(event: EKEvent, byMinutes minutes: Int, within window: ClosedRange<Date>, avoiding events: [EKEvent]) -> EKEvent? {
        let proposedEnd = event.endDate.addingTimeInterval(Double(minutes) * 60)
        guard proposedEnd <= window.upperBound else { return nil }

        // Check overlap with other events
        let overlaps = events.contains { other in
            guard other.eventIdentifier != event.eventIdentifier else { return false }
            return !(proposedEnd <= other.startDate || event.startDate >= other.endDate)
        }
        guard !overlaps else { return nil }

        let updated = event.copy() as! EKEvent
        updated.endDate = proposedEnd
        var newNotes = updated.notes ?? ""
        if !newNotes.contains("[Planner]") {
            newNotes.append("\n[Planner] Extended for task")
        }
        updated.notes = newNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return updated
    }

    private func firstAvailableSlot(durationMinutes: Int, within window: ClosedRange<Date>, avoiding events: [EKEvent]) -> Date? {
        var cursor = window.lowerBound
        let duration = TimeInterval(durationMinutes * 60)
        let sorted = events.sorted { $0.startDate < $1.startDate }

        for event in sorted {
            if cursor.addingTimeInterval(duration) <= event.startDate {
                return cursor
            } else {
                cursor = max(cursor, event.endDate)
            }
        }

        if cursor.addingTimeInterval(duration) <= window.upperBound {
            return cursor
        }
        return nil
    }

    private func save(event: EKEvent) {
        do {
            try store.save(event, span: .thisEvent)
        } catch {
            print("📅 [CalendarManager] Failed to save event: \(error)")
        }
    }

    // MARK: - Request Access
    func requestAccess() async {
        do {
            if #available(macOS 14.0, *) {
                try await store.requestFullAccessToEvents()
                _ = try await store.requestFullAccessToReminders()
            } else {
                // Bridge legacy callback-based API to async
                let _ : Bool = await withCheckedContinuation { cont in
                    store.requestAccess(to: .event) { granted, _ in cont.resume(returning: granted) }
                }
                let _ : Bool = await withCheckedContinuation { cont in
                    store.requestAccess(to: .reminder) { granted, _ in cont.resume(returning: granted) }
                }
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
                _ = await withCheckedContinuation { cont in
                    store.requestAccess(to: .event) { granted, _ in cont.resume(returning: granted) }
                }
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

    // Update an existing event by identifier
    func updateEvent(identifier: String,
                     title: String,
                     startDate: Date,
                     endDate: Date,
                     isAllDay: Bool,
                     location: String?,
                     notes: String?,
                     recurrence: RecurrenceOption = .none) async throws {
        guard let item = store.calendarItem(withIdentifier: identifier) as? EKEvent else { return }
        item.title = title
        item.startDate = startDate
        item.endDate = endDate
        item.isAllDay = isAllDay
        item.location = location
        item.notes = notes
        item.recurrenceRules = recurrence.rule.map { [$0] }
        try store.save(item, span: .thisEvent, commit: true)
        await refreshAll()
    }

    // Delete an event or reminder by identifier
    func deleteCalendarItem(identifier: String, isReminder: Bool) async throws {
        if isReminder, let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder {
            try store.remove(reminder, commit: true)
        } else if let event = store.calendarItem(withIdentifier: identifier) as? EKEvent {
            try store.remove(event, span: .thisEvent, commit: true)
        }
        await refreshAll()
    }

    @objc private func storeChanged() {
        _Concurrency.Task { await refreshAll() }
    }

    func openCalendarPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
    }

    // MARK: - Caching
    private struct CachedEKEvent: Codable {
        let title: String
        let start: Date
        let end: Date
        let location: String?
        let notes: String?
        let identifier: String
        let calendarId: String
    }

    private func saveCachedEvents(_ events: [EKEvent]) {
        guard let url = cacheURL else { return }
        let toCache = events.map { CachedEKEvent(title: $0.title, start: $0.startDate, end: $0.endDate, location: $0.location, notes: $0.notes, identifier: $0.eventIdentifier, calendarId: $0.calendar.calendarIdentifier) }
        do {
            let data = try JSONEncoder().encode(toCache)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            print("Failed to cache events: \(error)")
        }
    }

    private func loadCachedEvents() {
        guard let url = cacheURL, let data = try? Data(contentsOf: url) else { return }
        guard let decoded = try? JSONDecoder().decode([CachedEKEvent].self, from: data) else { return }

        let ekEvents: [EKEvent] = decoded.compactMap { cached in
            let ev = EKEvent(eventStore: store)
            ev.title = cached.title
            ev.startDate = cached.start
            ev.endDate = cached.end
            ev.location = cached.location
            ev.notes = cached.notes
            ev.calendar = store.calendars(for: .event).first(where: { $0.calendarIdentifier == cached.calendarId }) ?? store.defaultCalendarForNewEvents
            return ev
        }
        DispatchQueue.main.async {
            self.cachedMonthEvents = ekEvents
        }
    }

    enum RecurrenceOption: String, CaseIterable, Identifiable {
        case none, daily, weekly, monthly
        var id: String { rawValue }

        var rule: EKRecurrenceRule? {
            switch self {
            case .none:
                return nil
            case .daily:
                return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
            case .weekly:
                return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
            case .monthly:
                return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
            }
        }
    }

    // Backwards compatible API used in other views
    func openSystemPrivacySettings() {
        openCalendarPrivacySettings()
    }
}

// MARK: - Quick Add Event

extension CalendarManager {
    func quickAddEvent(title: String = "New Event", start: Date = Date(), durationMinutes: Int = 60) async {
        let granted = await requestEventAccessIfNeeded()
        guard granted else { return }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(Double(durationMinutes) * 60)
        event.calendar = store.defaultCalendarForNewEvents ?? store.calendars(for: .event).first
        do {
            try store.save(event, span: .thisEvent, commit: true)
            await MainActor.run {
                dailyEvents.append(event)
                cachedMonthEvents.append(event)
            }
        } catch {
            print("Failed to add quick event: \(error)")
        }
    }

    private func requestEventAccessIfNeeded() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess || status == .writeOnly {
            return true
        }
        if #available(macOS 14.0, *) {
            do {
                try await store.requestFullAccessToEvents()
                await MainActor.run {
                    self.eventAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    self.isAuthorized = (self.eventAuthorizationStatus == .fullAccess || self.eventAuthorizationStatus == .writeOnly)
                }
                return (self.eventAuthorizationStatus == .fullAccess || self.eventAuthorizationStatus == .writeOnly)
            } catch {
                print("Event access request failed: \(error)")
                return false
            }
        } else {
            return await withCheckedContinuation { cont in
                store.requestAccess(to: .event) { granted, _ in
                    DispatchQueue.main.async {
                        self.eventAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
                        self.isAuthorized = granted
                    }
                    cont.resume(returning: granted)
                }
            }
        }
    }
}
extension EKEvent {
    /// Safe identifier for UI lists even when eventIdentifier is nil (e.g., cached events).
    var rootsIdentifier: String {
        if !eventIdentifier.isEmpty { return eventIdentifier }
        if !calendarItemIdentifier.isEmpty { return calendarItemIdentifier }
        let time = startDate?.timeIntervalSince1970 ?? 0
        return "\(title ?? "")-\(time)"
    }
}
