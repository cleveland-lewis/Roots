#if os(macOS)
import SwiftUI

struct CalendarDayCell: View {
    let date: Date
    let isInCurrentMonth: Bool
    let isSelected: Bool
    let eventCount: Int
    let calendar: Calendar

    @EnvironmentObject private var settings: AppSettingsModel
    @State private var isPressed = false

    var body: some View {
        let isToday = calendar.isDateInToday(date)
        let a11yContent = VoiceOverLabels.dateCell(date: date, eventCount: eventCount)

        VStack(spacing: 7) {
            Text(dayString)
                .font(DesignSystem.Typography.body)
                .frame(minWidth: 28, minHeight: 28)
                .padding(4)
                .foregroundColor(textColor(isToday: isToday))
                .background(
                    Circle()
                        .fill(backgroundFill(isToday: isToday))
                )
                .overlay(
                    Circle()
                        .strokeBorder(isToday && !isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
                )

            // Event density bar removed per UI request
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeInOut(duration: DesignSystem.Motion.instant), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .voiceOver(a11yContent)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var dayString: String {
        String(calendar.component(.day, from: date))
    }

    private func textColor(isToday: Bool) -> Color {
        if isSelected {
            return .white
        } else if !isInCurrentMonth {
            return .secondary.opacity(0.5)
        } else if isToday {
            return .accentColor
        } else {
            return .primary
        }
    }

    private func backgroundFill(isToday: Bool) -> Color {
        if isSelected {
            return .accentColor
        } else if isToday {
            return .accentColor.opacity(0.12)
        } else {
            return .clear
        }
    }

    private func densityLevel(for count: Int) -> EventDensityLevel {
        switch count {
        case 0: return .none
        case 1...3: return .low
        case 4...6: return .medium
        default: return .high
        }
    }
}

enum EventDensityLevel {
    case none, low, medium, high

    var color: Color {
        switch self {
        case .none: return Color.secondary.opacity(0.25)
        case .low: return RootsColor.calendarDensityLow
        case .medium: return RootsColor.calendarDensityMedium
        case .high: return RootsColor.calendarDensityHigh
        }
    }

    static func fromCount(_ count: Int) -> EventDensityLevel {
        switch count {
        case 0: return .none
        case 1...3: return .low
        case 4...6: return .medium
        default: return .high
        }
    }
}

struct EventDensityBar: View {
    var level: EventDensityLevel
    var body: some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(level.color)
            .frame(height: 5)
            .frame(maxWidth: 32)
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
        .padding(DesignSystem.Layout.padding.card)
        .background(Color.black)
    }
}
#endif
