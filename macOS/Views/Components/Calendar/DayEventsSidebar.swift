#if os(macOS)
import SwiftUI
import EventKit
import AppKit

struct DayEventsSidebar: View {
    let selectedDate: Date
    let events: [EKEvent]
    let accentColor: Color
    var onSelectEvent: (EKEvent) -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            header

            // legend
            FlexibleLegend()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()
                .padding(.horizontal, 16)
            content
        }
        .padding() // match calendar card padding so rounded backgrounds align
        .background(DesignSystem.Materials.card)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedDate.formatted(.dateTime.weekday().month().day()))
                .font(.title3.weight(.semibold))
            Text(eventCountText)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .padding(.bottom, 4)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Layout.spacing.small) {
                if events.isEmpty {
                    VStack(spacing: DesignSystem.Layout.spacing.small) {
                        Text("No events")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                } else {
                    ForEach(events, id: \.calendarItemIdentifier) { event in
                        Button {
                            onSelectEvent(event)
                        } label: {
                            DayEventRow(event: event, accentColor: accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
    }

    private var eventCountText: String {
        switch events.count {
        case 0: return "No events"
        case 1: return "1 event"
        default: return "\(events.count) events"
        }
    }
}

private struct DayEventRow: View {
    let event: EKEvent
    let accentColor: Color
    @EnvironmentObject private var settings: AppSettingsModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            let cat = parseEventCategory(from: event.title) ?? .other
            Rectangle()
                .fill(cat.color)
                .frame(width: 3)
                .cornerRadius(1.5)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(displayTime)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)

            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.05))
        )
    }

    private var displayTime: String {
        if event.isAllDay {
            return "All-day"
        }
        let use24 = settings.use24HourTime
        let formatter = DateFormatter()
        formatter.dateFormat = use24 ? "HH:mm" : "h:mm a"
        let start = formatter.string(from: event.startDate ?? Date())
        let end = formatter.string(from: event.endDate ?? (event.startDate ?? Date()))
        return "\(start) — \(end)"
    }
}

private struct FlexibleLegend: View {
    var body: some View {
        FlowLayout(spacing: 10) {
            ForEach(EventCategory.allCases) { c in
                HStack(spacing: 6) {
                    Circle().fill(c.color).frame(width: 8, height: 8)
                    Text(c.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize()
                }
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxHeight = max(maxHeight, currentY + size.height)
        }
        
        return (CGSize(width: maxWidth, height: maxHeight), positions)
    }
}
#endif
