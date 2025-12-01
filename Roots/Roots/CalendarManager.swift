import Foundation
import Combine
import EventKit

final class CalendarManager: ObservableObject, LoadableViewModel {
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String? = nil
    static let shared = CalendarManager()
    private let store = EKEventStore()

    @Published var calendars: [EKCalendar] = []
    @Published var reminders: [EKReminder] = []
    @Published var events: [EKEvent] = []

    private init() {}

    // Request access for both calendars and reminders
    func requestAccess(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            self.isLoading = true
            self.loadingMessage = "Requesting calendar access…"
        }

        store.requestAccess(to: .event) { grantedEvents, _ in
            self.store.requestAccess(to: .reminder) { grantedReminders, _ in
                DispatchQueue.main.async {
                    if grantedEvents || grantedReminders {
                        self.fetchCalendars()
                        self.fetchAllReminders()
                    }
                    self.isLoading = false
                    self.loadingMessage = nil
                    completion(grantedEvents || grantedReminders)
                }
            }
        }
    }

    // Fetch calendars
    func fetchCalendars() {
        DispatchQueue.main.async {
            self.calendars = self.store.calendars(for: .event)
        }
    }

    // Fetch events in a date range
    func fetchEvents(start: Date, end: Date) {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let found = store.events(matching: predicate)
        DispatchQueue.main.async { self.events = found.sorted { $0.startDate < $1.startDate } }
    }

    // Fetch reminders (all)
    func fetchAllReminders() {
        let predicate = store.predicateForReminders(in: nil)
        store.fetchReminders(matching: predicate) { reminders in
            DispatchQueue.main.async {
                self.reminders = reminders ?? []
            }
        }
    }

    // Create an event (stub)
    func createEvent(title: String, start: Date, end: Date, calendar: EKCalendar? = nil) throws {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.calendar = calendar ?? store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent)
        fetchEvents(start: Date().addingTimeInterval(-60*60*24*30), end: Date().addingTimeInterval(60*60*24*30))
    }

    // Create a reminder (stub)
    func createReminder(title: String, calendar: EKCalendar? = nil) throws {
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = calendar ?? store.defaultCalendarForNewReminders()
        try store.save(reminder, commit: true)
        fetchAllReminders()
    }
}
