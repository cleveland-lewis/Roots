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
            ForEach(data) { point in
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
