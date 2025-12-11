import Foundation

enum AnalyticsTimeRange: String, CaseIterable, Identifiable {
    case today, thisWeek, last7Days, thisMonth, thisYear, allTime
    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .last7Days: return "Last 7 Days"
        case .thisMonth: return "This Month"
        case .thisYear: return "This Year"
        case .allTime: return "All Time"
        }
    }
}

/// Lightweight analytics helper for timer/dashboard charts.
final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}

    private struct StudySession {
        let date: Date
        let category: String
        let seconds: Double
    }

    // Placeholder sample data removed; sessions must be provided by the app.
    private lazy var sampleSessions: [StudySession] = []

    func getCategoryDistribution(range: AnalyticsTimeRange) -> [(category: String, seconds: Double)] {
        let sessions = filteredSessions(for: range)
        let grouped = Dictionary(grouping: sessions, by: { $0.category })
        return grouped.map { (key, value) in
            (category: key, seconds: value.reduce(0) { $0 + $1.seconds })
        }
        .sorted { $0.seconds > $1.seconds }
    }

    func getStudyTrends(range: AnalyticsTimeRange) -> [(date: Date, seconds: Double)] {
        let sessions = filteredSessions(for: range)
        let calendar = Calendar.current
        var bucketed: [Date: Double] = [:]

        for session in sessions {
            let bucket: Date
            switch range {
            case .today:
                // bucket by hour
                let comps = calendar.dateComponents([.year, .month, .day, .hour], from: session.date)
                bucket = calendar.date(from: comps) ?? session.date
            default:
                bucket = calendar.startOfDay(for: session.date)
            }
            bucketed[bucket, default: 0] += session.seconds
        }

        return bucketed
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }

    // MARK: - Helpers

    private func filteredSessions(for range: AnalyticsTimeRange) -> [StudySession] {
        let now = Date()
        let calendar = Calendar.current

        switch range {
        case .allTime:
            return sampleSessions
        case .today:
            return sampleSessions.filter { calendar.isDate($0.date, inSameDayAs: now) }
        case .thisWeek:
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return sampleSessions }
            return sampleSessions.filter { $0.date >= weekStart }
        case .last7Days:
            guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return sampleSessions }
            return sampleSessions.filter { $0.date >= start }
        case .thisMonth:
            guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else { return sampleSessions }
            return sampleSessions.filter { $0.date >= monthStart }
        case .thisYear:
            guard let yearStart = calendar.dateInterval(of: .year, for: now)?.start else { return sampleSessions }
            return sampleSessions.filter { $0.date >= yearStart }
        }
    }
}
