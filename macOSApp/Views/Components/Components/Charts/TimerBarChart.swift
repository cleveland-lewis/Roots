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

    private static func defaultTimeFormatter(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "ha"
        return f.string(from: date)
    }

    var body: some View {
        #if canImport(Charts)
        Chart {
            ForEach(data) { point in
                let dotCount = max(1, Int(ceil(point.minutes / minutesPerDot)))
                ForEach(0..<dotCount, id: \.self) { idx in
                    PointMark(
                        x: .value("Time", point.date),
                        y: .value("Minutes", Double(idx) * minutesPerDot)
                    )
                    .symbolSize(28)
                    .foregroundStyle(point.isCurrent ? Color.yellow : Color.secondary.opacity(0.55))
                }

                if point.isCurrent {
                    PointMark(
                        x: .value("Time", point.date),
                        y: .value("Minutes", max(point.minutes, minutesPerDot))
                    )
                    .symbol(Circle().strokeBorder(lineWidth: 0).background(Circle().fill(Color.yellow)))
                    .symbolSize(120)
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: data.map(\.date)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(xLabelFormatter(date))
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    AxisTick()
                }
            }
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
