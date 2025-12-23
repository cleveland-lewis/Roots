import SwiftUI

struct DayDetailSidebar: View {
    var date: Date
    var events: [CalendarEvent]
    var onSelectEvent: (CalendarEvent) -> Void = { _ in }

    private let width: CGFloat = 280
    private let calendar = Calendar.current
    @State private var selectedIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SELECTED DATE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(date.formatted(.dateTime.weekday().month().day()))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Divider()

            ScrollView {
                if events.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No events")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            Button {
                                selectedIndex = index
                                onSelectEvent(event)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Rectangle()
                                        .fill(categoryColor(for: event.category))
                                        .frame(width: 6)
                                        .cornerRadius(2)

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 6) {
                                            Text(event.title)
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(.primary)
                                                .lineLimit(2)
                                            
                                            Spacer()
                                            
                                            Text(categoryLabel(for: event.category))
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule()
                                                        .fill(categoryColor(for: event.category).opacity(0.15))
                                                )
                                        }
                                        
                                        Text(timeRange(for: event))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        
                                            .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedIndex == index ? Color(nsColor: .controlAccentColor).opacity(0.1) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectedIndex == index ? Color(nsColor: .controlAccentColor).opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .onAppear {
                        if !events.isEmpty {
                            selectedIndex = 0
                        }
                    }
                }
            }

            Spacer()
        }
        .frame(width: width)
        .background(DesignSystem.Materials.card, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.06), lineWidth: 1)
        )
        .padding(.vertical, 4)
        .focusable()
        .onKeyPress(.upArrow) {
            if !events.isEmpty {
                selectedIndex = max(0, selectedIndex - 1)
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if !events.isEmpty {
                selectedIndex = min(events.count - 1, selectedIndex + 1)
            }
            return .handled
        }
        .onKeyPress(.return) {
            if selectedIndex < events.count {
                onSelectEvent(events[selectedIndex])
            }
            return .handled
        }
        .onChange(of: events) { _, newEvents in
            if selectedIndex >= newEvents.count {
                selectedIndex = max(0, newEvents.count - 1)
            }
        }
    }

    private func timeRange(for event: CalendarEvent) -> String {
        let use24 = AppSettingsModel.shared.use24HourTime
        let f = DateFormatter()
        f.dateFormat = use24 ? "HH:mm" : "h:mm a"
        return "\(f.string(from: event.startDate)) - \(f.string(from: event.endDate))"
    }
    
    private func categoryLabel(for category: EventCategory) -> String {
        switch category {
        case .exam: return "Exam"
        case .class: return "Class"
        case .homework: return "Homework"
        case .study: return "Study"
        case .review: return "Review"
        case .reading: return "Reading"
        case .lab: return "Lab"
        case .other: return "Event"
        }
    }
    
    private func categoryColor(for category: EventCategory) -> Color {
        switch category {
        case .exam: return .red
        case .class: return .blue
        case .homework: return .green
        case .study: return .green
        case .review: return .yellow
        case .reading: return .cyan
        case .lab: return .orange
        case .other: return Color(nsColor: .controlAccentColor)
        }
    }
}

struct DayDetailSidebar_Previews: PreviewProvider {
    static var sampleEvents: [CalendarEvent] = [
        CalendarEvent(title: "Dentist Appointment", startDate: Date().addingTimeInterval(3600), endDate: Date().addingTimeInterval(5400), location: "Dental Office"),
        CalendarEvent(title: "Study Group", startDate: Date().addingTimeInterval(7200), endDate: Date().addingTimeInterval(9000), location: "Library")
    ]

    static var previews: some View {
        Group {
            DayDetailSidebar(date: Date(), events: sampleEvents, onSelectEvent: { _ in })
                .previewLayout(.sizeThatFits)
                .padding()

            DayDetailSidebar(date: Date(), events: [], onSelectEvent: { _ in })
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
