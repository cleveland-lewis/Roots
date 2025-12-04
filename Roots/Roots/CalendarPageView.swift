import SwiftUI
import EventKit

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case month, week, agenda
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct CalendarEvent: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var time: String
    var location: String?
    var date: Date
}

struct CalendarPageView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @EnvironmentObject var permissions: PermissionsManager
    @EnvironmentObject var eventsStore: EventsCountStore
    @State private var currentViewMode: CalendarViewMode = .month
    @State private var focusedDate: Date = Date()
    @State private var events: [CalendarEvent] = CalendarPageView.sampleEvents
    @State private var syncedEvents: [CalendarEvent] = []
    private let eventStore = EKEventStore()

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                topBar
                contentCard
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .onAppear {
                requestAccessAndSync()
            }
            .onChange(of: focusedDate) { previous, new in requestAccessAndSync() }
            .onChange(of: currentViewMode) { previous, new in requestAccessAndSync() }
        }
        .rootsSystemBackground()
    }

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 10) {
                    Button { shift(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Button { shift(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 6) {
                    Text(monthTitle(for: focusedDate))
                        .font(.headline)
                    HStack(spacing: 8) {
                        Picker("View", selection: $currentViewMode) {
                            ForEach(CalendarViewMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 320)
                    }
                }

                Spacer()

                Color.clear.frame(width: 76, height: 1)
            }
        }
    }

    private var contentCard: some View {
        Group {
            switch currentViewMode {
            case .month:
                MonthCalendarView(focusedDate: $focusedDate, events: effectiveEvents)
            case .week:
                WeekCalendarView(focusedDate: $focusedDate, events: effectiveEvents)
            case .agenda:
                AgendaCalendarView(focusedDate: $focusedDate, events: effectiveEvents)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private func shift(by value: Int) {
        switch currentViewMode {
        case .month:
            if let newDate = calendar.date(byAdding: .month, value: value, to: focusedDate) { focusedDate = newDate }
        case .week:
            if let newDate = calendar.date(byAdding: .weekOfYear, value: value, to: focusedDate) { focusedDate = newDate }
        case .agenda:
            if let newDate = calendar.date(byAdding: .day, value: value * 7, to: focusedDate) { focusedDate = newDate }
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private var effectiveEvents: [CalendarEvent] {
        syncedEvents.isEmpty ? events : syncedEvents
    }

    private func requestAccessAndSync() {
        permissions.requestCalendarIfNeeded {
            syncEvents()
        }
        permissions.requestRemindersIfNeeded()
    }

    private func syncEvents() {
        let window = visibleInterval()
        let predicate = eventStore.predicateForEvents(withStart: window.start, end: window.end, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)
        let mapped = ekEvents.map { ek in
            CalendarEvent(title: ek.title, time: formattedTimeRange(start: ek.startDate, end: ek.endDate), location: ek.location, date: ek.startDate)
        }
        syncedEvents = mapped
        // update precomputed counts
        let dates = mapped.map { calendar.startOfDay(for: $0.date) }
        Task { @MainActor in
            eventsStore.update(dates: dates)
        }
        // Reminders (optional)
        let reminderPredicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: window.start, ending: window.end, calendars: nil)
        eventStore.fetchReminders(matching: reminderPredicate) { reminders in
            guard let reminders else { return }
            let mappedReminders = reminders.compactMap { reminder -> CalendarEvent? in
                guard let dueDate = reminder.dueDateComponents?.date else { return nil }
                return CalendarEvent(title: reminder.title, time: "Reminder", location: reminder.location, date: dueDate)
            }
            DispatchQueue.main.async {
                self.syncedEvents.append(contentsOf: mappedReminders)
                // update counts with reminders too
                let dates = self.syncedEvents.map { calendar.startOfDay(for: $0.date) }
                Task { @MainActor in
                    eventsStore.update(dates: dates)
                }
            }
        }
    }

    private func formattedTimeRange(start: Date, end: Date) -> String {
        let use24 = AppSettingsModel.shared.use24HourTime
        let f = DateFormatter()
        f.dateFormat = use24 ? "HH:mm" : "h:mm a"
        return "\(f.string(from: start)) - \(f.string(from: end))"
    }

    private func visibleInterval() -> DateInterval {
        switch currentViewMode {
        case .month:
            if let interval = calendar.dateInterval(of: .month, for: focusedDate) {
                return interval
            }
        case .week:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: focusedDate)) ?? focusedDate
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? focusedDate
            return DateInterval(start: start, end: end)
        case .agenda:
            let start = calendar.startOfDay(for: focusedDate)
            let end = calendar.date(byAdding: .day, value: 14, to: start) ?? focusedDate
            return DateInterval(start: start, end: end)
        }
        return DateInterval(start: focusedDate, end: focusedDate.addingTimeInterval(24*3600))
    }
}

// MARK: - Month View

private struct MonthCalendarView: View {
    @Binding var focusedDate: Date
    let events: [CalendarEvent]
    @EnvironmentObject var eventsStore: EventsCountStore
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthHeader)
                .font(.headline)
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(days, id: \.date) { day in
                    let normalized = calendar.startOfDay(for: day.date)
                    let count = eventsStore.eventsByDate[normalized] ?? events(for: day.date).count
                    let isSelected = calendar.isDate(day.date, inSameDayAs: focusedDate)
                    CalendarDayCell(date: day.date, isInCurrentMonth: day.isCurrentMonth, isSelected: isSelected, eventCount: count, calendar: calendar)
                }
            }
        }
    }

    private var monthHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: focusedDate)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first..<symbols.count] + symbols[0..<first])
        return HStack(spacing: 6) {
            ForEach(ordered, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }


    private var days: [DayItem] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: focusedDate),
            let startWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday,
            let range = calendar.range(of: .day, in: .month, for: focusedDate)
        else { return [] }

        let firstWeekdayIndex = (startWeekday - calendar.firstWeekday + 7) % 7
        var items: [DayItem] = []

        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: focusedDate),
           let prevRange = calendar.range(of: .day, in: .month, for: prevMonth) {
            let prefixDays = prevRange.suffix(firstWeekdayIndex)
            for day in prefixDays {
                if let date = calendar.date(bySetting: .day, value: day, of: prevMonth) {
                    items.append(dayItem(for: date, isCurrentMonth: false))
                }
            }
        }

        for day in range {
            if let date = calendar.date(bySetting: .day, value: day, of: focusedDate) {
                items.append(dayItem(for: date, isCurrentMonth: true))
            }
        }

        while items.count % 7 != 0 {
            if let nextDate = calendar.date(byAdding: .day, value: 1, to: items.last?.date ?? focusedDate) {
                items.append(dayItem(for: nextDate, isCurrentMonth: false))
            } else { break }
        }

        return items
    }

    private func dayItem(for date: Date, isCurrentMonth: Bool) -> DayItem {
        DayItem(date: date, isCurrentMonth: isCurrentMonth, isToday: calendar.isDateInToday(date))
    }

    private func events(for date: Date) -> [CalendarEvent] {
        events.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private struct DayItem: Hashable {
        let date: Date
        let isCurrentMonth: Bool
        let isToday: Bool
    }
}

// MARK: - Week View

private struct WeekCalendarView: View {
    @Binding var focusedDate: Date
    let events: [CalendarEvent]
    @EnvironmentObject var settings: AppSettingsModel
    private let calendar = Calendar.current

    private struct PlaceholderBlock: Identifiable {
        let id = UUID()
        let dayIndex: Int
        let startHour: Double
        let duration: Double
        let title: String
    }

    private let placeholders: [PlaceholderBlock] = [
        .init(dayIndex: 1, startHour: 9, duration: 1.5, title: "Lecture"),
        .init(dayIndex: 3, startHour: 14, duration: 2, title: "Lab"),
        .init(dayIndex: 5, startHour: 19, duration: 1.5, title: "Study Block")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(weekTitle)
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(weekDays, id: \.self) { date in
                    dayPill(for: date)
                }
            }

            Divider().background(Color(nsColor: .separatorColor).opacity(0.12))

            ScrollView {
                ZStack(alignment: .topLeading) {
                    timeGrid
                    eventOverlay
                }
            }
        }
    }

    private var weekDays: [Date] {
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: focusedDate)) ?? focusedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        guard let start = weekDays.first,
              let end = calendar.date(byAdding: .day, value: 6, to: start) else {
            return formatter.string(from: focusedDate)
        }
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    private var timeGrid: some View {
        let hours = Array(6...23)
        return VStack(alignment: .leading, spacing: 22) {
            ForEach(hours, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(formatHour(Double(hour)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.08))
                        .frame(height: 1)
                }
            }
        }
        .padding(.bottom, 20)
    }

    private var eventOverlay: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - 60
            let columnWidth = width / 7
            let hourHeight: CGFloat = 22

            VStack(alignment: .leading, spacing: 0) {
                ForEach(placeholders) { block in
                    let yOffset = CGFloat(block.startHour - 6) * hourHeight
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(settings.activeAccentColor.opacity(0.2))
                        .overlay(
                            VStack(alignment: .leading, spacing: 2) {
                                Text(block.title).font(.caption.weight(.semibold))
                                Text(formatHour(block.startHour)).font(.caption2).foregroundColor(.secondary)
                            }
                            .padding(8)
                        )
                        .frame(width: columnWidth - 8, height: CGFloat(block.duration) * hourHeight)
                        .offset(x: 60 + CGFloat(block.dayIndex) * columnWidth, y: yOffset)
                }
            }
        }
    }

    private func dayPill(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let day = calendar.component(.day, from: date)
        let weekdaySymbol = calendar.shortWeekdaySymbols[(calendar.component(.weekday, from: date) - 1 + 7) % 7]
        return VStack(spacing: 6) {
            Text(weekdaySymbol.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            Text("\(day)")
                .font(.headline)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(isToday ? Color.accentColor.opacity(0.9) : Color(nsColor: .controlBackgroundColor).opacity(0.08))
                )
                .foregroundColor(isToday ? .white : .primary.opacity(0.8))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private func formatHour(_ hour: Double) -> String {
        let base = calendar.date(bySettingHour: Int(hour), minute: Int((hour.truncatingRemainder(dividingBy: 1)) * 60), second: 0, of: focusedDate) ?? focusedDate
        let formatter = DateFormatter()
        formatter.dateFormat = AppSettingsModel.shared.use24HourTime ? "HH:mm" : "h a"
        return formatter.string(from: base)
    }
}

// MARK: - Agenda View

private struct AgendaCalendarView: View {
    @Binding var focusedDate: Date
    let events: [CalendarEvent]
    @EnvironmentObject var settings: AppSettingsModel
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agenda")
                .font(.headline)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(groupedByDay.keys.sorted(), id: \.self) { day in
                        section(for: day)
                    }
                }
            }
        }
    }

    private func section(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dayTitle(for: date))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            VStack(spacing: 10) {
                ForEach(groupedByDay[date] ?? []) { event in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.8))
                            .frame(width: 6, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.body.weight(.semibold))
                            Text(formatTime(event.time) + (event.location != nil ? " · \(event.location!)" : ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.thinMaterial)
                    )
                }
            }
        }
    }

    private var groupedByDay: [Date: [CalendarEvent]] {
        Dictionary(grouping: eventsInWindow) { event in
            calendar.startOfDay(for: event.date)
        }
    }

    private var eventsInWindow: [CalendarEvent] {
        let start = calendar.startOfDay(for: focusedDate)
        let end = calendar.date(byAdding: .day, value: 14, to: start) ?? focusedDate
        return events.filter { $0.date >= start && $0.date < end }
    }

    private func dayTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        if calendar.isDateInToday(date) { return "Today · \(formatter.string(from: date))" }
        return formatter.string(from: date)
    }

    private func formatTime(_ time: String) -> String {
        // If time already formatted, return. For real data, wire through settings formatter.
        return time
    }
}

// MARK: - Event Chips

private struct EventChipsRow: View {
    var title: String
    var events: [CalendarEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            if events.isEmpty {
                Text("No events yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(events) { event in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.9))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.caption.weight(.semibold))
                                    Text(event.time + (event.location != nil ? " · \(event.location!)" : ""))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.06))
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sample Data

private extension CalendarPageView {
    static var sampleEvents: [CalendarEvent] {
        let calendar = Calendar.current
        let now = Date()
        return [
            CalendarEvent(title: "CS Lecture", time: "9:00 – 10:15 AM", location: "Hall A", date: now),
            CalendarEvent(title: "Group Project Sync", time: "1:00 – 1:45 PM", location: "Library", date: now),
            CalendarEvent(title: "Math Problem Set", time: "Due 11:59 PM", location: nil, date: calendar.date(byAdding: .day, value: 1, to: now) ?? now),
            CalendarEvent(title: "Lab Session", time: "3:00 – 5:00 PM", location: "Science Center", date: calendar.date(byAdding: .day, value: 3, to: now) ?? now)
        ]
    }
}

// MARK: - Legacy compatibility wrapper

struct CalendarView: View {
    var body: some View {
        CalendarPageView()
    }
}

struct CalendarPageView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarPageView()
            .preferredColorScheme(.dark)
    }
}
