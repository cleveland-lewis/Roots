import Foundation

protocol InsightEngine {
    func generateInsights(from stats: UsageStats) -> [Insight]
}

final class RuleBasedInsightEngine: InsightEngine {

    func generateInsights(from stats: UsageStats) -> [Insight] {
        var insights: [Insight] = []
        insights.append(contentsOf: timeOfDayInsights(from: stats))
        insights.append(contentsOf: loadBalanceInsights(from: stats))
        insights.append(contentsOf: estimationInsights(from: stats))

        insights.sort { a, b in
            score(a.severity) > score(b.severity)
        }
        return insights
    }

    private func score(_ severity: InsightSeverity) -> Int {
        switch severity {
        case .critical: return 3
        case .warning:  return 2
        case .info:     return 1
        }
    }

    private func timeOfDayInsights(from stats: UsageStats) -> [Insight] {
        var out: [Insight] = []

        let ratios: [(hour: Int, ratio: Double)] = stats.hourly.compactMap { h in
            guard h.scheduledMinutes > 0 else { return nil }
            let r = Double(h.completedMinutes) / Double(h.scheduledMinutes)
            return (h.hour, r)
        }

        guard !ratios.isEmpty else { return [] }

        if let worst = ratios.min(by: { $0.ratio < $1.ratio }),
           worst.ratio < 0.4,
           worst.hour >= 20 {
            out.append(
                Insight(
                    category: .timeOfDay,
                    severity: .warning,
                    title: "Late-night blocks rarely get done",
                    message: "Blocks scheduled around \(worst.hour):00 are only completed about \(Int(worst.ratio * 100))% of the time. Consider shifting deep work earlier in the day."
                )
            )
        }

        if let best = ratios.max(by: { $0.ratio < $1.ratio }),
           best.ratio > 0.7 {
            out.append(
                Insight(
                    category: .timeOfDay,
                    severity: .info,
                    title: "You execute best around \(best.hour):00",
                    message: "Blocks scheduled around \(best.hour):00 are completed about \(Int(best.ratio * 100))% of the time. Use that window for harder tasks."
                )
            )
        }

        return out
    }

    private func loadBalanceInsights(from stats: UsageStats) -> [Insight] {
        guard !stats.byDay.isEmpty else { return [] }

        let days = stats.byDay
        let avg = Double(days.map { $0.scheduledMinutes }.reduce(0,+)) / Double(days.count)
        guard avg > 0 else { return [] }

        var out: [Insight] = []

        for dayStat in days {
            let ratio = Double(dayStat.scheduledMinutes) / avg
            if ratio >= 2.0 {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE, MMM d"
                let dateString = formatter.string(from: dayStat.date)

                out.append(
                    Insight(
                        category: .loadBalance,
                        severity: .warning,
                        title: "One day is overloaded",
                        message: "\(dateString) has about \(Int(ratio * 100))% of your average workload. Try spreading work more evenly across the week."
                    )
                )
                break
            }
        }

        return out
    }

    private func estimationInsights(from stats: UsageStats) -> [Insight] {
        var out: [Insight] = []

        for typeStats in stats.byTaskType {
            guard typeStats.avgPlannedBlockMinutes > 0 else { continue }
            let ratio = typeStats.avgActualBlockMinutes / typeStats.avgPlannedBlockMinutes

            if ratio > 1.3 {
                out.append(
                    Insight(
                        category: .estimation,
                        severity: .info,
                        title: "You underestimate \(typeStats.type) work",
                        message: "\(typeStats.type) blocks take about \(Int(ratio * 100))% of the time you plan. Consider scheduling slightly longer blocks for this type."
                    )
                )
            }
        }

        return out
    }
}
