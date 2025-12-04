import Foundation

enum DateTimeHelpers {
    static func formattedTime(_ date: Date, use24h: Bool) -> String {
        let df = DateFormatter()
        df.dateFormat = use24h ? "HH:mm" : "h:mm a"
        return df.string(from: date)
    }

    static func formattedClockWithSeconds(_ date: Date, use24h: Bool) -> String {
        let df = DateFormatter()
        df.dateFormat = use24h ? "HH:mm:ss" : "h:mm:ss a"
        return df.string(from: date)
    }

    static func todayElapsedFraction(clock: Calendar = .current) -> Double {
        let now = Date()
        let startOfDay = clock.startOfDay(for: now)
        guard let endOfDay = clock.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        let total = endOfDay.timeIntervalSince(startOfDay)
        let elapsed = now.timeIntervalSince(startOfDay)
        return total > 0 ? max(0, min(elapsed / total, 1)) : 0
    }

    static func todayRemainingMinutes(clock: Calendar = .current) -> Int {
        let now = Date()
        let startOfDay = clock.startOfDay(for: now)
        guard let endOfDay = clock.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        let remainingSeconds = endOfDay.timeIntervalSince(now)
        return max(0, Int(remainingSeconds / 60))
    }

    static func todayInterval(calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    }

    static func interval(forDays days: Int, from date: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: days, to: start) ?? start
        return DateInterval(start: start, end: end)
    }
}

