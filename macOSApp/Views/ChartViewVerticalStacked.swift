#if os(macOS)
import SwiftUI
#if canImport(Charts)
import Charts
#endif

// Minimal Charts-only stacked bar with pointer-hover tooltip via ChartOverlay when available.
struct ChartViewVerticalStacked: View {
    var buckets: [AnalyticsBucket]
    var categoryColors: [String: Color]
    var showLabels: Bool = true

    @State private var hoveredPoint: ChartPoint? = nil
    @State private var hoveredPointLocation: CGPoint? = nil
    @State private var focusedBucketIndex: Int? = nil
    @AppStorage("chartLegendExpanded") private var isLegendExpanded: Bool = true

    var body: some View {
        VStack(spacing: DesignSystem.Layout.spacing.small) {
            chartContentView
            legendView
        }
    }
    
    private var chartContentView: some View {
        // Use the simple manual renderer with hover highlighting and animation to ensure stable builds
        ManualStackedView(buckets: buckets, categoryColors: categoryColors, hoveredPoint: hoveredPoint, showLabels: showLabels)
            .frame(maxHeight: 320)
            .overlay(Group {
                if let hovered = hoveredPoint {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hovered.category).font(DesignSystem.Typography.caption).bold()
                        Text("\(Int(hovered.minutes)) minutes · \(hovered.rangeLabel)").font(.caption2)
                    }
                    .padding(DesignSystem.Layout.spacing.small)
                    .background(Color(.windowBackgroundColor).opacity(0.95))
                    .cornerRadius(8)
                    .shadow(radius: 6)
                    .transition(DesignSystem.Motion.fadeTransition)
                    .offset(x: (hoveredPointLocation?.x ?? 0) > 120 ? -140 : 0, y: 0)
                    .animation(DesignSystem.Motion.snappyEase, value: hoveredPointLocation)
                }
            }.padding(DesignSystem.Layout.padding.card), alignment: Alignment.topTrailing)
            .focusable(true)
            .onKeyDown { ev in
                // left/right arrow to move focused bucket
                guard buckets.count > 0 else { return }
                switch ev.keyCode {
                case 123: // left
                    let new = max(0, (focusedBucketIndex ?? 0) - 1)
                    focusedBucketIndex = new
                case 124: // right
                    let new = min(buckets.count - 1, (focusedBucketIndex ?? 0) + 1)
                    focusedBucketIndex = new
                default: break
                }
            }
    }
    
    private var legendView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Categories")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { withAnimation(DesignSystem.Motion.interactiveSpring) { isLegendExpanded.toggle() } }) {
                    Image(systemName: isLegendExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help(isLegendExpanded ? "Collapse legend" : "Expand legend")
            }
            
            if isLegendExpanded {
                let categories = categoryColors.keys.sorted()
                let columns = [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: DesignSystem.Layout.spacing.small)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                    ForEach(categories, id: \.self) { category in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(categoryColors[category] ?? .gray)
                                .frame(width: 8, height: 8)
                            Text(category)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.controlBackgroundColor).opacity(0.5))
                        )
                    }
                }
                .transition(DesignSystem.Motion.scaleTransition)
            }
        }
        .padding(.horizontal, DesignSystem.Layout.padding.card)
        .padding(.vertical, DesignSystem.Layout.spacing.small)
    }

    init(buckets: [AnalyticsBucket], categoryColors: [String: Color], showLabels: Bool = true) {
        self.buckets = buckets
        self.categoryColors = categoryColors
        self.showLabels = showLabels
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

// removed ChartProxy bridge; using geometry hit-testing for hover instead to keep compilation stable

// small ViewModifier for hover highlighting to avoid heavy inline expressions
private struct HoverHighlightModifier: ViewModifier {
    var isHighlighted: Bool
    func body(content: Content) -> some View {
        content
            .opacity(isHighlighted ? 1.0 : 0.45)
            .scaleEffect(isHighlighted ? 1.0 : 0.98)
            .animation(DesignSystem.Motion.snappyEase, value: isHighlighted)
    }
}

private struct ManualStackedView: View {
    var buckets: [AnalyticsBucket]
    var categoryColors: [String: Color]
    var hoveredPoint: ChartPoint?
    var showLabels: Bool
    var body: some View {
        GeometryReader { proxy in
            let maxMinutes = buckets.map { $0.categoryDurations.values.reduce(0, +) / 60.0 }.max() ?? 1
            let usableHeight = proxy.size.height - 40
            HStack(alignment: .bottom, spacing: DesignSystem.Layout.spacing.small) {
                ForEach(buckets) { bucket in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            let keys = bucket.categoryDurations.keys.sorted()
                            let segments: [(key: String, start: Double, value: Double)] = keys.reduce(into: (acc: 0.0, items: [(String, Double, Double)]())) { acc, key in
                                let val = Double(bucket.categoryDurations[key] ?? 0) / 60.0
                                acc.items.append((key, acc.acc, val))
                                acc.acc += val
                            }.items

                            ForEach(segments, id: \.key) { segment in
                                let isHighlight = hoveredPoint == nil || (hoveredPoint?.bucket == bucket.label && hoveredPoint?.category == segment.key)
                                let ratio = maxMinutes > 0 ? segment.value / maxMinutes : 0
                                let barHeight = CGFloat(ratio) * usableHeight
                                let offsetRatio = segment.start / max(maxMinutes, 0.0001)
                                let offsetY = -CGFloat(offsetRatio) * usableHeight
                                Rectangle()
                                    .fill(categoryColors[segment.key, default: .accentColor])
                                    .frame(height: barHeight)
                                    .offset(y: offsetY)
                                    .opacity(isHighlight ? 1.0 : 0.45)
                                    .scaleEffect(isHighlight ? 1.0 : 0.98)
                                    .animation(DesignSystem.Motion.snappyEase, value: hoveredPoint?.id)
                            }
                        }
                        .cornerRadius(6)
                        if showLabels {
                            Text(bucket.label).font(.caption2).foregroundColor(.secondary).frame(height: 18)
                        }
                    }
                }
            }
        }
    }
}

private struct ChartPoint: Identifiable {
    let id = UUID()
    var bucket: String
    var category: String
    var minutes: Double
    var start: Double
    var end: Double
    var rangeLabel: String
}

// NSViewRepresentable to track mouse movement and deliver local points and in/out events
private struct HoverMouseTracker: NSViewRepresentable {
    typealias Callback = (CGPoint, Bool) -> Void
    let onMove: Callback

    func makeNSView(context: Context) -> NSView {
        let v = TrackingNSView(frame: .zero)
        v.onMove = onMove
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? TrackingNSView)?.onMove = onMove
    }

    class TrackingNSView: NSView {
        var onMove: Callback?
        var tracking: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let t = tracking { removeTrackingArea(t) }
            let opts: NSTrackingArea.Options = [.mouseMoved, .activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited]
            tracking = NSTrackingArea(rect: bounds, options: opts, owner: self, userInfo: nil)
            if let t = tracking { addTrackingArea(t) }
        }

        override func mouseMoved(with event: NSEvent) {
            let p = convert(event.locationInWindow, from: nil)
            onMove?(p, true)
        }

        override func mouseExited(with event: NSEvent) {
            onMove?(CGPoint.zero, false)
        }

        override func mouseEntered(with event: NSEvent) {
            let p = convert(event.locationInWindow, from: nil)
            onMove?(p, true)
        }
    }
}

// Simple onKeyDown handler for macOS to capture arrow keys
#if os(macOS)
import AppKit

struct KeyEventHandlingView: NSViewRepresentable {
    var handler: (NSEvent) -> Void
    func makeNSView(context: Context) -> NSView {
        let v = KeyHandlingNSView()
        v.handler = handler
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    class KeyHandlingNSView: NSView {
        var handler: ((NSEvent) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            handler?(event)
        }
    }
}

extension View {
    func onKeyDown(perform: @escaping (NSEvent) -> Void) -> some View {
        self.background(KeyEventHandlingView(handler: perform))
    }
}
#endif

extension Notification.Name {
    static let chartSegmentTapped = Notification.Name("chartSegmentTapped")
}
#endif
