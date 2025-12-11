import Foundation
import SwiftUI

struct AnalyticsBucket: Identifiable {
    let id = UUID()
    let label: String
    let start: Date
    let end: Date
    var categoryDurations: [String: Double] // seconds per category
}

struct StudyAnalyticsAggregator {
    static func bucketsForToday(hours: Int = 24, calendar: Calendar = Calendar.current) -> [AnalyticsBucket] {
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        var buckets: [AnalyticsBucket] = []
        for i in 0..<hours {
            let s = calendar.date(byAdding: .hour, value: i, to: startOfDay)!
            let e = calendar.date(byAdding: .hour, value: i+1, to: startOfDay)!
            buckets.append(AnalyticsBucket(label: hourLabel(for: s, calendar: calendar), start: s, end: e, categoryDurations: [:]))
        }
        return buckets
    }

    static func bucketsForMonth(calendar: Calendar = Calendar.current) -> [AnalyticsBucket] {
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return [] }
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        return range.map { day -> AnalyticsBucket in
            let s = calendar.date(byAdding: .day, value: day-1, to: start)!
            let e = calendar.date(byAdding: .day, value: day, to: start)!
            return AnalyticsBucket(label: String(day), start: s, end: e, categoryDurations: [:])
        }
    }

    static func bucketsForYear(calendar: Calendar = Calendar.current) -> [AnalyticsBucket] {
        let now = Date()
        let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
        return (1...12).map { m -> AnalyticsBucket in
            let s = calendar.date(byAdding: .month, value: m-1, to: start)!
            let e = calendar.date(byAdding: .month, value: m, to: start)!
            let formatter = DateFormatter(); formatter.dateFormat = "MMM"
            return AnalyticsBucket(label: formatter.string(from: s), start: s, end: e, categoryDurations: [:])
        }
    }

    static func bucketsForWeek(calendar: Calendar = Calendar.current) -> [AnalyticsBucket] {
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        // start on Monday: weekday 2 (in Gregorian), adjust accordingly
        let startDiff = (weekday + 5) % 7 // days to subtract to get Monday
        if let monday = calendar.date(byAdding: .day, value: -startDiff, to: now) {
            let startOfMonday = calendar.startOfDay(for: monday)
            var buckets: [AnalyticsBucket] = []
            for i in 0..<7 {
                let s = calendar.date(byAdding: .day, value: i, to: startOfMonday)!
                let e = calendar.date(byAdding: .day, value: i+1, to: startOfMonday)!
                buckets.append(AnalyticsBucket(label: dayLabel(for: s, calendar: calendar), start: s, end: e, categoryDurations: [:]))
            }
            return buckets
        }
        return []
    }

    static func aggregate(sessions: [LocalTimerSession], activities: [LocalTimerActivity], into buckets: [AnalyticsBucket], calendar: Calendar = Calendar.current) -> [AnalyticsBucket] {
        var result = buckets
        // map activity id to category
        var activityMap: [UUID: LocalTimerActivity] = [:]
        for a in activities { activityMap[a.id] = a }

        for session in sessions {
            guard let end = session.endDate else { continue }
            // clamp session into buckets by overlap
            for i in 0..<result.count {
                if session.startDate < result[i].end && end > result[i].start {
                    // overlap duration
                    let s = max(session.startDate, result[i].start)
                    let e = min(end, result[i].end)
                    let overlapped = e.timeIntervalSince(s)
                    let cat = activityMap[session.activityID]?.category ?? "Uncategorized"
                    result[i].categoryDurations[cat, default: 0] += overlapped
                }
            }
        }
        return result
    }

    private static func hourLabel(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }

    private static func dayLabel(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
