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
                PointMark(x: .value("Date", peak.date), y: .value("Minutes", peak.minutes))
                    .foregroundStyle(accentColor)
                    .annotation(position: .top, alignment: .center) {
                        Text("\(Int(peak.minutes))m")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08)))
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
