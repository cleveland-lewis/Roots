import Foundation
import Combine
import EventKit
#if os(macOS)
import AppKit
#endif
import _Concurrency
import SwiftUI

@MainActor
final class CalendarManager: ObservableObject, LoadableViewModel {
    // Shim only. No EventKit. No caches. No observers. Do not add logic here.
    // All EventKit ownership and permissions live in DeviceCalendarManager.
    // Use DeviceCalendarManager directly for new code. This shim forwards existing APIs.
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String? = nil
    nonisolated let objectWillChange = ObservableObjectPublisher()

    static let shared = CalendarManager()
    private var deviceManager = DeviceCalendarManager.shared
    private var store: EKEventStore { deviceManager.store }

    // Persistent selection
    @AppStorage("selectedCalendarID") var selectedCalendarID: String = ""
    @AppStorage("selectedReminderListID") var selectedReminderListID: String = ""

    // Forwarded sources for pickers
    @Published var availableCalendars: [EKCalendar] = []
    @Published var availableReminderLists: [EKCalendar] = []

    // NOTE: Do not keep own event caches here. UI should observe DeviceCalendarManager.

    // Permissions (forwarded)
    @Published var eventAuthorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var reminderAuthorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    @Published var isAuthorized: Bool = false
    @Published var isCalendarAccessDenied: Bool = false
    @Published var isRemindersAccessDenied: Bool = false
    @Published var selectedDate: Date? = nil

    // Helpers used by AddEventPopup - forwarded
    var writableCalendars: [EKCalendar] { deviceManager.store.calendars(for: .event).filter { $0.allowsContentModifications } }
    var defaultCalendarForNewEvents: EKCalendar? { deviceManager.store.defaultCalendarForNewEvents }
    func defaultCalendarForNewReminders() -> EKCalendar? { deviceManager.store.defaultCalendarForNewReminders() }

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

    private let cacheURL: URL?
    private let lastPlanKey = "roots.lastDailyPlan"

    private init() {
        cacheURL = nil
        // Observe store changes via DeviceCalendarManager's store
        deviceManager.startObservingStoreChanges()
        // Also subscribe to notification to refresh local caches
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAuthStatus()
            }
        }
        _Concurrency.Task { await self.refreshAuthStatus() }
    }

    func refreshAuthStatus() async {
        // Forward to DeviceCalendarManager for authorization state
        await MainActor.run {
            self.isAuthorized = DeviceCalendarManager.shared.isAuthorized
            self.eventAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
            self.reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            self.isCalendarAccessDenied = (self.eventAuthorizationStatus == .denied || self.eventAuthorizationStatus == .restricted)
            self.isRemindersAccessDenied = (self.reminderAuthorizationStatus == .denied || self.reminderAuthorizationStatus == .restricted)
        }
        if self.isAuthorized {
            refreshSources()
            // DeviceCalendarManager owns fetching; UI should observe it directly.
            await DeviceCalendarManager.shared.refreshEventsForVisibleRange()
            await planTodayIfNeeded(tasks: AssignmentsStore.shared.tasks)
        }
    }

    /// Ensures the month cache is hydrated and surfaces a real loading state.
    func ensureMonthCache(for date: Date) {
        _Concurrency.Task { [weak self] in
            guard let self else { return }
            _ = await self.withLoading(message: "Loading calendar…") {
                if !self.isAuthorized {
                    await self.checkPermissionsOnStartup()
                } else {
                    // Forward to device manager
                    await DeviceCalendarManager.shared.refreshEventsForVisibleRange()
                }
                return ()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .EKEventStoreChanged, object: nil)
    }

    // MARK: - Permissions & Sources

    func checkPermissionsOnStartup() async {
        // Forward to DeviceCalendarManager bootstrap
        await DeviceCalendarManager.shared.bootstrapOnLaunch()
        await refreshAuthStatus()
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
        // Forward refresh to device manager; CalendarManager does not hold caches.
        guard DeviceCalendarManager.shared.isAuthorized else { return }
        await DeviceCalendarManager.shared.refreshEventsForVisibleRange()
        // Reminders handling remains in device manager; shim simply forwards.
        await planTodayIfNeeded(tasks: AssignmentsStore.shared.tasks)
    }

    func refreshMonthlyCache(for date: Date) {
        // Forward to device manager; it manages the canonical event cache
        Task { await DeviceCalendarManager.shared.refreshEventsForVisibleRange() }
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
        // Forward to device manager
        do {
            try DeviceCalendarManager.shared.store.save(event, span: .thisEvent)
        } catch {
            print("📅 [CalendarManager] Failed to save event: \(error)")
        }
    }

    // MARK: - Request Access
    func requestAccess() async {
        // Forward to DeviceCalendarManager
        await DeviceCalendarManager.shared.bootstrapOnLaunch()
        await refreshAuthStatus()
    }

    func requestCalendarAccess() async {
        // Forward to device manager
        await DeviceCalendarManager.shared.bootstrapOnLaunch()
        await refreshAuthStatus()
    }

    func requestRemindersAccess() async {
        // Forward to device manager
        await DeviceCalendarManager.shared.bootstrapOnLaunch()
        await refreshAuthStatus()
    }

    // Create and save events (used by AddEventPopup)
    func saveEvent(title: String,
                   startDate: Date,
                   endDate: Date,
                   isAllDay: Bool,
                   location: String,
                   notes: String,
                   url: URL? = nil,
                   alarms: [EKAlarm]? = nil,
                   recurrenceRule: EKRecurrenceRule? = nil,
                   calendar: EKCalendar?,
                   category: EventCategory? = nil) async throws {
        // Forward create to device manager
        guard let targetCalendar = calendar ?? DeviceCalendarManager.shared.store.defaultCalendarForNewEvents else { return }
        try await MainActor.run {
            let newEvent = EKEvent(eventStore: DeviceCalendarManager.shared.store)
            newEvent.title = title
            newEvent.startDate = startDate
            newEvent.endDate = endDate
            newEvent.isAllDay = isAllDay
            newEvent.location = location
            newEvent.notes = encodeNotesWithCategory(userNotes: notes, category: category)
            if let url = url { newEvent.url = url }
            if let rule = recurrenceRule { newEvent.recurrenceRules = [rule] }
            if let alarms = alarms { newEvent.alarms = alarms }
            newEvent.calendar = targetCalendar

            try DeviceCalendarManager.shared.store.save(newEvent, span: .thisEvent)
        }
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
                     url: String?,
                     primaryAlert: AlertOption?,
                     secondaryAlert: AlertOption?,
                     travelTime: TimeInterval?,
                     recurrence: RecurrenceOption = .none,
                     category: EventCategory? = nil,
                     span: EKSpan = .thisEvent) async throws {
        enum CalendarUpdateError: LocalizedError {
            case eventNotFound
            case readOnlyCalendar
            case unauthorized

            var errorDescription: String? {
                switch self {
                case .eventNotFound: return "Event could not be loaded."
                case .readOnlyCalendar: return "This calendar is read-only."
                case .unauthorized: return "Calendar access is not granted."
                }
            }
        }

        guard DeviceCalendarManager.shared.isAuthorized else { throw CalendarUpdateError.unauthorized }
        guard let item = DeviceCalendarManager.shared.store.event(withIdentifier: identifier) else {
            throw CalendarUpdateError.eventNotFound
        }
        guard item.calendar.allowsContentModifications else { throw CalendarUpdateError.readOnlyCalendar }

        item.title = title
        item.startDate = startDate
        item.endDate = endDate
        item.isAllDay = isAllDay
        item.location = location
        item.notes = encodeNotesWithCategory(userNotes: notes ?? "", category: category)
        
        // Handle URL
        if let urlString = url, !urlString.isEmpty, let validURL = URL(string: urlString) {
            item.url = validURL
        } else {
            item.url = nil
        }
        
        // Handle alarms
        var alarms: [EKAlarm] = []
        if let primary = primaryAlert?.alarm {
            alarms.append(primary)
        }
        if let secondary = secondaryAlert?.alarm {
            alarms.append(secondary)
        }
        item.alarms = alarms.isEmpty ? nil : alarms
        
        // Note: EKEvent doesn't have a travelTime property in EventKit API
        // Travel time functionality would need to be handled differently
        
        // Handle recurrence
        item.recurrenceRules = recurrence.rule.map { [$0] }

        let effectiveSpan: EKSpan = {
            guard !(item.recurrenceRules?.isEmpty ?? true) else { return .thisEvent }
            return span
        }()
        
        try DeviceCalendarManager.shared.store.save(item, span: effectiveSpan, commit: true)
        await DeviceCalendarManager.shared.refreshEventsForVisibleRange(reason: "updateEvent")
    }

    // Delete an event or reminder by identifier
    func deleteCalendarItem(identifier: String, isReminder: Bool) async throws {
        if isReminder, let reminder = DeviceCalendarManager.shared.store.calendarItem(withIdentifier: identifier) as? EKReminder {
            try DeviceCalendarManager.shared.store.remove(reminder, commit: true)
        } else if let event = DeviceCalendarManager.shared.store.calendarItem(withIdentifier: identifier) as? EKEvent {
            try DeviceCalendarManager.shared.store.remove(event, span: .thisEvent, commit: true)
        }
        await refreshAll()
    }

    @objc private func storeChanged() {
        _Concurrency.Task { await refreshAll() }
    }

    func openCalendarPrivacySettings() {
#if os(macOS)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
#endif
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
    
    enum AlertOption: String, CaseIterable, Identifiable {
        case none = "None"
        case atTime = "At time of event"
        case fiveMinutes = "5 minutes before"
        case fifteenMinutes = "15 minutes before"
        case thirtyMinutes = "30 minutes before"
        case oneHour = "1 hour before"
        case twoHours = "2 hours before"
        case oneDay = "1 day before"
        case twoDays = "2 days before"
        
        var id: String { rawValue }
        
        var alarm: EKAlarm? {
            switch self {
            case .none:
                return nil
            case .atTime:
                return EKAlarm(relativeOffset: 0)
            case .fiveMinutes:
                return EKAlarm(relativeOffset: -5 * 60)
            case .fifteenMinutes:
                return EKAlarm(relativeOffset: -15 * 60)
            case .thirtyMinutes:
                return EKAlarm(relativeOffset: -30 * 60)
            case .oneHour:
                return EKAlarm(relativeOffset: -60 * 60)
            case .twoHours:
                return EKAlarm(relativeOffset: -2 * 60 * 60)
            case .oneDay:
                return EKAlarm(relativeOffset: -24 * 60 * 60)
            case .twoDays:
                return EKAlarm(relativeOffset: -2 * 24 * 60 * 60)
            }
        }
        
        static func from(alarm: EKAlarm?) -> AlertOption {
            guard let alarm = alarm else { return .none }
            
            switch alarm.relativeOffset {
            case 0: return .atTime
            case -5 * 60: return .fiveMinutes
            case -15 * 60: return .fifteenMinutes
            case -30 * 60: return .thirtyMinutes
            case -60 * 60: return .oneHour
            case -2 * 60 * 60: return .twoHours
            case -24 * 60 * 60: return .oneDay
            case -2 * 24 * 60 * 60: return .twoDays
            default: return .none
            }
        }
    }
    
    enum TravelTimeOption: String, CaseIterable, Identifiable {
        case none = "None"
        case fifteenMinutes = "15 minutes"
        case thirtyMinutes = "30 minutes"
        case oneHour = "1 hour"
        case oneAndHalfHours = "1.5 hours"
        case twoHours = "2 hours"
        
        var id: String { rawValue }
        
        var timeInterval: TimeInterval? {
            switch self {
            case .none:
                return nil
            case .fifteenMinutes:
                return 15 * 60
            case .thirtyMinutes:
                return 30 * 60
            case .oneHour:
                return 60 * 60
            case .oneAndHalfHours:
                return 90 * 60
            case .twoHours:
                return 2 * 60 * 60
            }
        }
        
        static func from(interval: TimeInterval?) -> TravelTimeOption {
            guard let interval = interval else { return .none }
            
            switch interval {
            case 15 * 60: return .fifteenMinutes
            case 30 * 60: return .thirtyMinutes
            case 60 * 60: return .oneHour
            case 90 * 60: return .oneAndHalfHours
            case 2 * 60 * 60: return .twoHours
            default: return .none
            }
        }
    }

    // Backwards compatible API used in other views
    func openSystemPrivacySettings() {
        openCalendarPrivacySettings()
    }
    
    // MARK: - Category Storage
    
    /// Encodes category into notes with a special marker that won't be displayed to users
    private func encodeNotesWithCategory(userNotes: String, category: EventCategory?) -> String {
        var result = userNotes
        if let cat = category {
            // Store category as metadata at the end of notes
            let categoryMarker = "\n[RootsCategory:\(cat.rawValue)]"
            // Remove any existing category marker first
            result = result.replacingOccurrences(of: #"\n\[RootsCategory:.*?\]"#, with: "", options: .regularExpression)
            result = result + categoryMarker
        }
        return result
    }
    
    /// Extracts category from notes and returns both the clean user notes and category
    func decodeNotesWithCategory(notes: String?) -> (userNotes: String, category: EventCategory?) {
        guard let notes = notes else { return ("", nil) }
        
        let pattern = #"\[RootsCategory:(.*?)\]"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: notes, options: [], range: NSRange(notes.startIndex..., in: notes)),
           let categoryRange = Range(match.range(at: 1), in: notes) {
            let categoryString = String(notes[categoryRange])
            let category = EventCategory(rawValue: categoryString)
            // Remove the category marker from displayed notes
            let cleanNotes = notes.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (cleanNotes, category)
        }
        
        return (notes, nil)
    }
}

// MARK: - Quick Add Event

extension CalendarManager {
    func quickAddEvent(title: String = "New Event", start: Date = Date(), durationMinutes: Int = 60) async {
        // Forward permission check to DeviceCalendarManager
        if !DeviceCalendarManager.shared.isAuthorized {
            await DeviceCalendarManager.shared.bootstrapOnLaunch()
        }
        guard DeviceCalendarManager.shared.isAuthorized else { return }
        let store = deviceManager.store
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(Double(durationMinutes) * 60)
        event.calendar = store.defaultCalendarForNewEvents ?? store.calendars(for: .event).first
        do {
            try store.save(event, span: .thisEvent, commit: true)
            await DeviceCalendarManager.shared.refreshEventsForVisibleRange()
        } catch {
            print("Failed to add quick event: \(error)")
        }
    }

    private func requestEventAccessIfNeeded() async -> Bool {
        await DeviceCalendarManager.shared.requestFullAccessIfNeeded()
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
