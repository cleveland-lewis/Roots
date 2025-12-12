#if os(macOS)
import SwiftUI
import Charts

struct CourseStudySlice: Identifiable {
    let id: String
    let courseName: String
    let minutes: Double
    let color: Color
}

struct TodayStudyStackedBarChart: View {
    var activities: [LocalTimerActivity]

    private func buildSlices() -> [CourseStudySlice] {
        let grouped = Dictionary(grouping: activities) { $0.courseCode ?? "Unassigned" }
        var slices: [CourseStudySlice] = []
        for (key, list) in grouped {
            let minutes = list.reduce(0) { $0 + $1.todayTrackedSeconds } / 60.0
            if minutes <= 0 { continue }
            let color = list.first?.colorTag.color ?? deterministicColor(for: key)
            slices.append(CourseStudySlice(id: key, courseName: key, minutes: minutes, color: color))
        }
        // stable sort by minutes desc
        slices.sort { $0.minutes > $1.minutes }
        return slices
    }

    private func deterministicColor(for key: String) -> Color {
        var hash = 5381
        for c in key.unicodeScalars { hash = ((hash << 5) &+ hash) &+ Int(c.value) }
        let hue = Double((hash % 360)) / 360.0
        return Color(hue: hue, saturation: 0.45, brightness: 0.75)
    }

    var body: some View {
        let slices = buildSlices()
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                let total = slices.reduce(0) { $0 + $1.minutes }
                if total > 0 {
                    Text("Total: \(Int(total))m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if #available(macOS 13.0, *), !slices.isEmpty {
                Chart {
                    ForEach(slices) { slice in
                        BarMark(
                            x: .value("Label", "Today"),
                            y: .value("Minutes", slice.minutes)
                        )
                        .foregroundStyle(slice.color)
                        .annotation(position: .overlay) {
                            // no per-segment labels for compactness
                            EmptyView()
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 140)

                // compact legend
                HStack(spacing: 10) {
                    ForEach(slices.prefix(6)) { s in
                        HStack(spacing: 6) {
                            Circle().fill(s.color).frame(width: 8, height: 8)
                            Text(s.courseName)
                                .font(.caption2)
                            Text("\(Int(s.minutes))m")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 6)
            } else {
                // fallback: simple bar made of rectangles
                GeometryReader { proxy in
                    let total = slices.reduce(0) { $0 + $1.minutes }
                    HStack(spacing: 0) {
                        ForEach(slices) { s in
                            Rectangle()
                                .fill(s.color)
                                .frame(width: proxy.size.width * CGFloat(s.minutes / max(1, total)))
                        }
                    }
                }
                .frame(height: 28)
                if slices.isEmpty {
                    Text("No study tracked today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

}
#endif
