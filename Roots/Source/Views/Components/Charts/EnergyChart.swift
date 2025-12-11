import SwiftUI
import Charts

// Reference: Swift Charts: Audio Graphs & Accessibility - https://www.youtube.com/watch?v=example
// (Swift Charts: Audio Graphs & Accessibility - demonstrates that Swift Charts auto-generates Audio Graphs)
let swiftChartsAccessibilityVideoURL = URL(string: "https://www.youtube.com/watch?v=example")!

struct EnergyPoint: Identifiable {
    let id = UUID()
    let hour: Date
    let level: Double
}

struct EnergyChart: View {
    let title = "Energy Levels"
    @State private var data: [EnergyPoint] = {
        let calendar = Calendar.current
        let now = Date()
        return (0..<24).map { i in
            EnergyPoint(hour: calendar.date(byAdding: .hour, value: -23 + i, to: now)!, level: Double.random(in: 20...100))
        }
    }()

    @State private var selectedHour: Date? = nil

    var body: some View {
        RootsChartContainer(title: title, summary: "Last 24 hours", trend: .up) {
            Chart {
                ForEach(data) { point in
                    AreaMark(
                        x: .value("Hour", point.hour),
                        y: .value("Energy", point.level)
                    )
                    .foregroundStyle(LinearGradient(colors: [Color.blue.opacity(0.35), Color.blue.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Hour", point.hour),
                        y: .value("Energy", point.level)
                    )
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }

                // Scrubbing rule & tooltip
                if let selected = selectedHour {
                    RuleMark(x: .value("Selected", selected))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.primary.opacity(0.8))

                    // Tooltip dot using a PointMark at the selected location
                    if let nearest = nearestPoint(to: selected) {
                        PointMark(x: .value("Hour", nearest.hour), y: .value("Energy", nearest.level))
                            .symbolSize(80)
                            .foregroundStyle(Color.white)
                            .annotation(position: .overlay, alignment: .top) {
                                VStack(spacing: 4) {
                                    Text(String(format: "%.0f%%", nearest.level))
                                        .font(.caption)
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.85)))
                                        .foregroundColor(.white)
                                }
                                .offset(y: -10)
                            }
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis { DesignSystem.Charts.AxisPresets.dailyXAxis }
            .chartYAxis { DesignSystem.Charts.AxisPresets.percentageYAxis }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let location = value.location
                                if let date: Date = proxy.value(atX: location.x) as? Date {
                                    selectedHour = nearestExistingHour(to: date)
                                }
                            }
                            .onEnded { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation { selectedHour = nil }
                                }
                            }
                        )
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(title))
        }
        .padding()
    }

    private func nearestExistingHour(to date: Date) -> Date {
        guard let nearest = nearestPoint(to: date) else { return date }
        return nearest.hour
    }

    private func nearestPoint(to date: Date) -> EnergyPoint? {
        data.min(by: { abs($0.hour.timeIntervalSince(date)) < abs($1.hour.timeIntervalSince(date)) })
    }
}
