import SwiftUI
import Charts

struct StudySample: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Double
}

struct StudyTimeLineGraphView: View {
    var samples: [StudySample]
    var accentColor: Color

    private var maxSample: StudySample? {
        samples.max(by: { $0.minutes < $1.minutes })
    }

    var body: some View {
        Chart {
            ForEach(samples) { s in
                LineMark(
                    x: .value("Date", s.date),
                    y: .value("Minutes", s.minutes)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(accentColor)
            }

            if let peak = maxSample {
                // Subtle point mark at peak
                PointMark(x: .value("Date", peak.date), y: .value("Minutes", peak.minutes))
                    .foregroundStyle(accentColor)
                    .annotation(position: .top, alignment: .center) {
                        // Format as Hh Mm when >= 60 minutes
                        let minutes = Int(peak.minutes)
                        let label: String = {
                            if minutes >= 60 {
                                let h = minutes / 60
                                let m = minutes % 60
                                return m == 0 ? "\(h)h" : "\(h)h \(m)m"
                            } else {
                                return "\(minutes)m"
                            }
                        }()

                        Text(label)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.primary.opacity(0.9))
                    }

                // Add faint horizontal guide lines at 50% and 75% of peak
                if peak.minutes > 0 {
                    RuleMark(y: .value("50pct", peak.minutes * 0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: []))
                        .foregroundStyle(Color.primary.opacity(0.06))
                    RuleMark(y: .value("75pct", peak.minutes * 0.75))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: []))
                        .foregroundStyle(Color.primary.opacity(0.04))
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.clear)
        }
        .padding(6)
    }
}
