import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct TimerGraphsView: View {
    enum GraphMode: String, CaseIterable, Identifiable { case live, history; var id: String { rawValue } }

    @Binding var mode: GraphMode
    let sessions: [FocusSession]
    let currentSession: FocusSession?
    let sessionElapsed: TimeInterval
    let sessionRemaining: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Graph Mode", selection: $mode) {
                ForEach(GraphMode.allCases) { m in
                    Text(m == .live ? "Live" : "History").tag(m)
                }
            }
            .pickerStyle(.segmented)

            switch mode {
            case .live:
                liveGraph
            case .history:
                historyGraph
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var liveGraph: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let session = currentSession {
                ProgressView(value: liveProgress(for: session))
                    .progressViewStyle(.linear)
                HStack {
                    Text("Elapsed \(format(minutes: sessionElapsed / 60))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let planned = session.plannedDuration {
                        Text("Remaining \(format(minutes: sessionRemaining / 60))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int((liveProgress(for: session)) * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                    }
                }
            } else {
                Text("No active session")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var historyGraph: some View {
        VStack(alignment: .leading, spacing: 12) {
            #if canImport(Charts)
            Chart(historyPoints) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Minutes", point.minutes)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(6)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
            #else
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(historyPoints) { point in
                    VStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.8))
                            .frame(width: 16, height: CGFloat(point.minutes))
                        Text(point.label)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 28)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            #endif

            VStack(alignment: .leading, spacing: 4) {
                Text("Today: \(format(minutes: todayMinutes))")
                Text("This Week: \(format(minutes: weekMinutes))")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private func liveProgress(for session: FocusSession) -> Double {
        guard let planned = session.plannedDuration, planned > 0 else { return 0 }
        return min(max(sessionElapsed / planned, 0), 1)
    }

    private var historyPoints: [HistoryPoint] {
        let calendar = Calendar.current
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: Date()) }
        return days.reversed().map { day in
            let total = sessions
                .filter { session in
                    guard let end = session.endedAt else { return false }
                    return calendar.isDate(end, inSameDayAs: day)
                }
                .reduce(0.0) { partial, session in
                    partial + (session.actualDuration ?? session.plannedDuration ?? 0)
                } / 60

            return HistoryPoint(date: day, minutes: total)
        }
    }

    private var todayMinutes: Double {
        let calendar = Calendar.current
        return sessions
            .filter { session in
                guard let end = session.endedAt else { return false }
                return calendar.isDateInToday(end)
            }
            .reduce(0.0) { partial, session in
                partial + (session.actualDuration ?? session.plannedDuration ?? 0)
            } / 60
    }

    private var weekMinutes: Double {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -6, to: Date()) else { return 0 }
        return sessions
            .filter { session in
                guard let end = session.endedAt else { return false }
                return end >= start
            }
            .reduce(0.0) { partial, session in
                partial + (session.actualDuration ?? session.plannedDuration ?? 0)
            } / 60
    }

    private func format(minutes: Double) -> String {
        let totalSeconds = Int(minutes * 60)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

private struct HistoryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Double

    var label: String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f.string(from: date)
    }
}
