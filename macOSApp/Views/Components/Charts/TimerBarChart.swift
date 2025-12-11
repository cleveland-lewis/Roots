import SwiftUI
#if canImport(Charts)
import Charts
#endif

/// Reusable dotted bar chart for timer/focus history.
/// Shows vertical stacks of dots with an optional highlighted "current" bar.
struct TimerDataPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let minutes: Double
    let isCurrent: Bool
}

struct TimerBarChart: View {
    let data: [TimerDataPoint]
    var minutesPerDot: Double = 5
    var xLabelFormatter: (Date) -> String

    init(
        data: [TimerDataPoint],
        minutesPerDot: Double = 5,
        xLabelFormatter: @escaping (Date) -> String = TimerBarChart.defaultTimeFormatter
    ) {
        self.data = data
        self.minutesPerDot = minutesPerDot
        self.xLabelFormatter = xLabelFormatter
    }

    private var yMax: Double {
        data.map(\.minutes).max() ?? 0
    }

    private static nonisolated func defaultTimeFormatter(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "ha"
        return f.string(from: date)
    }

    var body: some View {
        #if canImport(Charts)
        Chart {
            ForEach(data, id: \.id) { point in
                DottedBarStack(point: point, minutesPerDot: minutesPerDot)
                if point.isCurrent {
                    CurrentPointMark(point: point, minutesPerDot: minutesPerDot)
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: data.map(\.date)) { _ in AxisTick() }
        }
        .chartYScale(domain: 0...(max(yMax * 1.1, minutesPerDot * 3)))
        .chartPlotStyle { plot in
            plot.background(.clear)
        }
        .frame(height: 220)
        #else
        Text("Charts framework unavailable")
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(.secondary)
        #endif
    }
}

#if canImport(Charts)
private struct DottedBarStack: View {
    let point: TimerDataPoint
    let minutesPerDot: Double

    var body: some View {
        let count = max(1, Int(ceil(point.minutes / minutesPerDot)))
        ForEach(0..<count, id: \.self) { idx in
            PointMark(
                x: .value("Time", point.date),
                y: .value("Minutes", Double(idx) * minutesPerDot)
            )
            .symbolSize(28)
            .foregroundStyle(point.isCurrent ? Color.yellow : Color.secondary.opacity(0.55))
        }
    }
}

private struct CurrentPointMark: View {
    let point: TimerDataPoint
    let minutesPerDot: Double

    var body: some View {
        PointMark(
            x: .value("Time", point.date),
            y: .value("Minutes", Double(max(point.minutes, minutesPerDot)))
        )
        .symbol(.circle)
        .foregroundStyle(Color.yellow)
        .symbolSize(120)
    }
}
#endif
