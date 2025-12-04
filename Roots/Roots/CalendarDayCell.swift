import SwiftUI

struct CalendarDayCell: View {
    let date: Date
    let isInCurrentMonth: Bool
    let isSelected: Bool
    let eventCount: Int
    let calendar: Calendar

    @EnvironmentObject private var settings: AppSettingsModel

    var body: some View {
        let color = eventDensityColor(for: eventCount)

        VStack(spacing: 6) {
            Text(dayString)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundColor(isInCurrentMonth ? .primary : Color.secondary)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )

            // load bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(height: 6)
                .frame(maxWidth: 36)
        }
        .frame(maxWidth: .infinity)
    }

    private var dayString: String {
        String(calendar.component(.day, from: date))
    }

    private func eventDensityColor(for count: Int) -> Color {
        switch count {
        case 0: return .secondary.opacity(0.2)
        case 1...3: return .green.opacity(0.7)
        case 4...6: return .yellow.opacity(0.8)
        default: return .red.opacity(0.8)
        }
    }
}

struct CalendarDayCell_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            CalendarDayCell(date: Date(), isInCurrentMonth: true, isSelected: false, eventCount: 0, calendar: Calendar.current)
            CalendarDayCell(date: Date(), isInCurrentMonth: true, isSelected: false, eventCount: 1, calendar: Calendar.current)
            CalendarDayCell(date: Date(), isInCurrentMonth: true, isSelected: false, eventCount: 3, calendar: Calendar.current)
            CalendarDayCell(date: Date(), isInCurrentMonth: true, isSelected: true, eventCount: 5, calendar: Calendar.current)
        }
        .preferredColorScheme(.dark)
        .padding()
        .background(Color.black)
    }
}
