import SwiftUI
#if canImport(Charts)
import Charts
#endif

// Minimal Charts-only stacked bar with clear, simple body to avoid type-check issues.
struct ChartViewVerticalStacked: View {
    var buckets: [AnalyticsBucket]
    var categoryColors: [String: Color]

    @State private var tappedPoint: ChartPoint? = nil

    var body: some View {
        #if canImport(Charts)
        let points = computePoints()
        let categories = computeCategories(from: points)
        let colors = categories.map { categoryColors[$0] ?? .accentColor }

        Chart {
            ForEach(points) { p in
                BarMark(x: .value("Bucket", p.bucket), yStart: .value("StartMin", p.start), yEnd: .value("EndMin", p.end))
                    .foregroundStyle(by: .value("Category", p.category))
                    .accessibilityLabel("\(p.category) \(Int(p.minutes)) minutes")
                    .onTapGesture {
                        NotificationCenter.default.post(name: .chartSegmentTapped, object: p)
                    }
            }
        }
        .chartForegroundStyleScale(domain: categories, range: colors)
        .frame(maxHeight: 320)
        .overlay(Group {
            if let tapped = tappedPoint {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tapped.category).font(.caption).bold()
                    Text("\(Int(tapped.minutes)) minutes · \(tapped.rangeLabel)").font(.caption2)
                }
                .padding(8).background(Color(.windowBackgroundColor).opacity(0.9)).cornerRadius(8).shadow(radius: 4)
                .transition(.opacity.combined(with: .scale))
            }
        }.padding(), alignment: .topTrailing)
        #else
        ManualStackedView(buckets: buckets, categoryColors: categoryColors)
        #endif
    }

    init(buckets: [AnalyticsBucket], categoryColors: [String: Color]) {
        self.buckets = buckets
        self.categoryColors = categoryColors
        // observe tapped segment notifications
        NotificationCenter.default.addObserver(forName: .chartSegmentTapped, object: nil, queue: .main) { note in
            if let p = note.object as? ChartPoint {
                self._tappedPoint.wrappedValue = p
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { self._tappedPoint.wrappedValue = nil }
            }
        }
    }

    private func computePoints() -> [ChartPoint] {
        var out: [ChartPoint] = []
        for bucket in buckets {
            let keys = bucket.categoryDurations.keys.sorted()
            var acc: Double = 0
            let df = DateFormatter(); df.dateFormat = "h:mma"
            for key in keys {
                let secs = bucket.categoryDurations[key] ?? 0
                let mins = Double(secs) / 60.0
                let start = acc
                acc += mins
                let range = "\(df.string(from: bucket.start)) — \(df.string(from: bucket.end))"
                out.append(ChartPoint(bucket: bucket.label, category: key, minutes: mins, start: start, end: acc, rangeLabel: range))
            }
        }
        return out
    }

    private func computeCategories(from points: [ChartPoint]) -> [String] {
        var set = Set<String>()
        for p in points { set.insert(p.category) }
        return Array(set)
    }
}

#if !canImport(Charts)
private struct ManualStackedView: View {
    var buckets: [AnalyticsBucket]
    var categoryColors: [String: Color]
    var body: some View {
        GeometryReader { proxy in
            let maxMinutes = buckets.map { $0.categoryDurations.values.reduce(0, +) / 60.0 }.max() ?? 1
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(buckets) { bucket in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            let keys = bucket.categoryDurations.keys.sorted()
                            var acc: Double = 0
                            ForEach(keys, id: \.self) { key in
                                let val = Double(bucket.categoryDurations[key] ?? 0) / 60.0
                                Rectangle()
                                    .fill(categoryColors[key, default: .accentColor])
                                    .frame(height: maxMinutes > 0 ? CGFloat(val / maxMinutes) * (proxy.size.height - 40) : 0)
                                    .offset(y: -CGFloat(acc / max(maxMinutes, 0.0001)) * (proxy.size.height - 40))
                                acc += val
                            }
                        }
                        .cornerRadius(6)
                        Text(bucket.label).font(.caption2).foregroundColor(.secondary).frame(height: 18)
                    }
                }
            }
        }
    }
}
#endif

private struct ChartPoint: Identifiable {
    let id = UUID()
    var bucket: String
    var category: String
    var minutes: Double
    var start: Double
    var end: Double
    var rangeLabel: String
}

extension Notification.Name {
    static let chartSegmentTapped = Notification.Name("chartSegmentTapped")
}
