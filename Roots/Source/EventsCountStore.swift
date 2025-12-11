import Foundation
import Combine

@MainActor
final class EventsCountStore: ObservableObject {
    @Published var eventsByDate: [Date: Int] = [:]
    private var calendar = Calendar.current

    func update(dates: [Date]) {
        // dates are expected normalized to startOfDay; normalize again for safety
        let normalized = dates.map { calendar.startOfDay(for: $0) }
        let dict = Dictionary(grouping: normalized, by: { $0 }).mapValues { $0.count }
        eventsByDate = dict
    }

    func clear() {
        eventsByDate = [:]
    }
}
