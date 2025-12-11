import SwiftUI

struct DayDetailSidebar: View {
    var date: Date
    var events: [CalendarEvent]
    var onSelectEvent: (CalendarEvent) -> Void = { _ in }

    private let width: CGFloat = 280
    private let calendar = Calendar.current

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
                    LazyVStack(spacing: 10) {
                        ForEach(events) { event in
                            Button {
                                onSelectEvent(event)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Rectangle()
                                        .fill(Color(nsColor: .controlAccentColor))
                                        .frame(width: 6)
                                        .cornerRadius(2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text(timeRange(for: event))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(event.id == events.first?.id ? Color(nsColor: .controlAccentColor).opacity(0.06) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
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
    }

    private func timeRange(for event: CalendarEvent) -> String {
        let use24 = AppSettingsModel.shared.use24HourTime
        let f = DateFormatter()
        f.dateFormat = use24 ? "HH:mm" : "h:mm a"
        return "\(f.string(from: event.startDate)) - \(f.string(from: event.endDate))"
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
