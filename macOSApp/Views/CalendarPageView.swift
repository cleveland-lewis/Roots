#if os(macOS)
import SwiftUI
import EventKit
import _Concurrency
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

// Shared helper for labeling events
fileprivate func eventCategoryLabel(for title: String) -> String {
    let lower = title.lowercased()
    let pairs: [(String, String)] = [
        ("exam", "Exam"),
        ("midterm", "Exam"),
        ("final", "Exam"),
        ("class", "Class"),
        ("lecture", "Class"),
        ("lab", "Class"),
        ("study", "Study"),
        ("read", "Reading"),
        ("homework", "Homework"),
        ("assignment", "Homework"),
        ("problem set", "Homework"),
        ("practice test", "Practice Test"),
        ("mock", "Practice Test"),
        ("quiz", "Practice Test"),
        ("meeting", "Meeting"),
        ("sync", "Meeting"),
        ("1:1", "Meeting"),
        ("one-on-one", "Meeting")
    ]
    for (key, label) in pairs {
        if lower.contains(key) { return label }
    }
    return "Other"
}

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

public struct CalendarEvent: Identifiable, Hashable {
    public let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var location: String?
    var notes: String?
    var url: URL?
    var alarms: [EKAlarm]?
    var travelTime: TimeInterval?
    var ekIdentifier: String?
    var isReminder: Bool = false
    var category: EventCategory

    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date, location: String? = nil, notes: String? = nil, url: URL? = nil, alarms: [EKAlarm]? = nil, travelTime: TimeInterval? = nil, ekIdentifier: String? = nil, isReminder: Bool = false, category: EventCategory? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.url = url
        self.alarms = alarms
        self.travelTime = travelTime
        self.ekIdentifier = ekIdentifier
        self.isReminder = isReminder
        self.category = category ?? parseEventCategory(from: title) ?? .other
    }
}

struct CalendarPageView: View {
    @EnvironmentObject var settings: AppSettingsModel

    @EnvironmentObject var eventsStore: EventsCountStore
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var deviceCalendar: DeviceCalendarManager
    @State private var currentViewMode: CalendarViewMode = .month
    @State private var focusedDate: Date = Date()
    @State private var selectedDate: Date? = Date()
    @State private var selectedEvent: CalendarEvent?
    @State private var metrics: CalendarStats = .empty
    @State private var showingNewEventSheet = false
    @State private var events: [CalendarEvent] = []
    @State private var syncedEvents: [CalendarEvent] = []
    private var eventStore: EKEventStore { DeviceCalendarManager.shared.store }

    private let calendar = Calendar.current

    @State private var chevronLeftHover = false
    @State private var chevronRightHover = false
    @State private var todayHover = false

    var body: some View {
        VStack(spacing: 16) {
            // Header: Add button, Title, View selector, Navigation
            HStack(alignment: .center, spacing: 12) {
                Button {
                    showingNewEventSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(DesignSystem.Materials.hud.opacity(0.75), in: Circle())
                }
                .buttonStyle(.plain)
                .rootsStandardInteraction()

                VStack(alignment: .leading, spacing: 2) {
                    // Large title driven by current view mode
                    Group {
                        switch currentViewMode {
                        case .day:
                            Text(focusedDate.formatted(.dateTime.weekday().month().day()))
                        case .week:
                            Text(weekTitle(for: focusedDate))
                        case .month:
                            Text(monthTitle(for: focusedDate))
                        case .year:
                            Text(String(Calendar.current.component(.year, from: focusedDate)))
                        }
                    }
                    .font(.largeTitle.weight(.semibold))
                    .lineLimit(1)

                    // Subtitle / small metadata
                    Text(currentViewMode == .week ? weekSubtitle(for: focusedDate) : "")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("View", selection: $currentViewMode) {
                    ForEach(CalendarViewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                .tint(settings.activeAccentColor)

                HStack(spacing: 6) {
                    Button { shift(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(chevronLeftHover ? settings.activeAccentColor : .primary)
                            .scaleEffect(chevronLeftHover ? 1.06 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .rootsStandardInteraction()
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: DesignSystem.Motion.instant)) { chevronLeftHover = hovering }
                    }

                    Button { jumpToToday() } label: {
                        Text("Today")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(settings.activeAccentColor).opacity(todayHover ? 0.18 : 0.12))
                    }
                    .buttonStyle(.plain)
                    .rootsStandardInteraction()
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: DesignSystem.Motion.instant)) { todayHover = hovering }
                    }

                    Button { shift(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(chevronRightHover ? settings.activeAccentColor : .primary)
                            .scaleEffect(chevronRightHover ? 1.06 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .rootsStandardInteraction()
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: DesignSystem.Motion.instant)) { chevronRightHover = hovering }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, DesignSystem.Layout.padding.window)
            .padding(.vertical, 4)

            // Main content: single glass area without sidebars
            VStack(spacing: 12) {
                gridContent
            }
            .padding()
            .background(DesignSystem.Materials.card)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .sheet(isPresented: $showingNewEventSheet) {
            AddEventPopup().environmentObject(calendarManager)
        }
        .onAppear {
            requestAccessAndSync()
            Task { await deviceCalendar.refreshEventsForVisibleRange() }
            updateMetrics()
        }
        .onChange(of: focusedDate) { _, newValue in
            Task { await deviceCalendar.refreshEventsForVisibleRange() }
            updateMetrics()
        }
        .onChange(of: currentViewMode) { _, _ in updateMetrics() }
        .onReceive(deviceCalendar.$events) { _ in
            updateMetrics()
        }
        // Present event detail without resizing layout
        .sheet(item: $selectedEvent, onDismiss: {
            // restore sidebar when the detail sheet is dismissed
            withAnimation(DesignSystem.Motion.standardEase) { selectedDate = calendarManager.selectedDate ?? focusedDate }
            selectedEvent = nil
        }, content: { event in
            // Add a subtle presentation animation inside the sheet
            EventDetailView(item: event, isPresented: Binding(get: { selectedEvent != nil }, set: { if !$0 { selectedEvent = nil } }))
                .transition(.move(edge: .bottom).combined(with: .opacity))
        })
    }

    @ViewBuilder
    private var gridContent: some View {
        switch currentViewMode {
        case .month:
            MonthCalendarView(
                focusedDate: $focusedDate,
                events: effectiveEvents,
                onSelectDate: { day in
                    focusedDate = day
                    selectedDate = day
                    calendarManager.selectedDate = day
                    selectedEvent = events(on: day).first
                    updateMetrics()
                },
                onSelectEvent: { event in
                    selectedEvent = event
                    focusedDate = event.startDate
                    selectedDate = event.startDate
                    calendarManager.selectedDate = event.startDate
                    updateMetrics()
                }
            )
        case .week:
            WeekCalendarView(focusedDate: $focusedDate, events: effectiveEvents)
        case .day:
            CalendarDayView(date: focusedDate, events: deviceCalendar.events)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .year:
            CalendarYearView(currentYear: focusedDate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func eventsFor(date: Date) -> [CalendarEvent] {
        let start = calendar.startOfDay(for: date)
        return effectiveEvents.filter { calendar.isDate($0.startDate, inSameDayAs: start) }
    }

    private func shift(by value: Int) {
        switch currentViewMode {
        case .month:
            if let newDate = calendar.date(byAdding: .month, value: value, to: focusedDate) {
                focusedDate = newDate
                selectedDate = newDate
            }
        case .week:
            if let newDate = calendar.date(byAdding: .weekOfYear, value: value, to: focusedDate) {
                focusedDate = newDate
                selectedDate = newDate
            }
        case .day:
            if let newDate = calendar.date(byAdding: .day, value: value, to: focusedDate) {
                focusedDate = newDate
                selectedDate = newDate
            }
        case .year:
            if let newDate = calendar.date(byAdding: .year, value: value, to: focusedDate) {
                focusedDate = newDate
                selectedDate = newDate
            }
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private func weekTitle(for date: Date) -> String {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? date
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    private func weekSubtitle(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }

    private func jumpToToday() {
        let today = Date()
        focusedDate = today
        selectedDate = today
        calendarManager.selectedDate = today
    }

    private var effectiveEvents: [CalendarEvent] {
        syncedEvents.isEmpty ? events : syncedEvents
    }

    private func requestAccessAndSync() {
        _Concurrency.Task {
            await calendarManager.requestAccess()
            // Only sync if access granted
            syncEvents()
        }
    }

    private func syncEvents() {
        // Guard: don't attempt to read if not authorized
        let hasEventAccess: Bool = {
            if #available(macOS 14.0, *) {
                return calendarManager.eventAuthorizationStatus == .fullAccess || calendarManager.eventAuthorizationStatus == .writeOnly
            } else {
                return calendarManager.eventAuthorizationStatus == .fullAccess || calendarManager.eventAuthorizationStatus == .writeOnly
            }
        }()
        let hasReminderAccess: Bool = {
            if #available(macOS 14.0, *) {
                return calendarManager.reminderAuthorizationStatus == .fullAccess || calendarManager.reminderAuthorizationStatus == .writeOnly
            } else {
                return calendarManager.reminderAuthorizationStatus == .fullAccess || calendarManager.reminderAuthorizationStatus == .writeOnly
            }
        }()

        if !(hasEventAccess || hasReminderAccess) {
            print("📅 [CalendarPageView] syncEvents called without permissions")
            return
        }

        let window = visibleInterval()
        let selectedCalId = calendarManager.selectedCalendarID
        let targetCalendars: [EKCalendar]? = {
            if selectedCalId.isEmpty { return nil }
            return eventStore.calendars(for: .event).filter { $0.calendarIdentifier == selectedCalId }
        }()

        let predicate = eventStore.predicateForEvents(withStart: window.start, end: window.end, calendars: targetCalendars)
        let ekEvents = eventStore.events(matching: predicate)
        let mapped = ekEvents.map { ek in
            CalendarEvent(title: ek.title, startDate: ek.startDate, endDate: ek.endDate, location: ek.location, notes: ek.notes, url: ek.url, alarms: ek.alarms, travelTime: nil, ekIdentifier: ek.eventIdentifier, isReminder: false)
        }
        syncedEvents = mapped
        updateMetrics()
        // update precomputed counts
        let dates = mapped.map { calendar.startOfDay(for: $0.startDate) }
        _Concurrency.Task { @MainActor in
            eventsStore.update(dates: dates)
        }
        // Reminders (optional)
        let reminderCalendars: [EKCalendar]? = {
            if calendarManager.selectedReminderListID.isEmpty { return nil }
            return eventStore.calendars(for: .reminder).filter { $0.calendarIdentifier == calendarManager.selectedReminderListID }
        }()

        let reminderPredicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: window.start, ending: window.end, calendars: reminderCalendars)
        eventStore.fetchReminders(matching: reminderPredicate) { reminders in
            guard let reminders else { return }
            let mappedReminders = reminders.compactMap { reminder -> CalendarEvent? in
                guard let dueDate = reminder.dueDateComponents?.date else { return nil }
                return CalendarEvent(title: reminder.title, startDate: dueDate, endDate: dueDate, location: reminder.location, notes: reminder.notes, url: nil, alarms: nil, travelTime: nil, ekIdentifier: reminder.calendarItemIdentifier, isReminder: true)
            }
            DispatchQueue.main.async {
                self.syncedEvents.append(contentsOf: mappedReminders)
                // update counts with reminders too
                let dates = self.syncedEvents.map { calendar.startOfDay(for: $0.startDate) }
                _Concurrency.Task { @MainActor in
                    eventsStore.update(dates: dates)
                }
                updateMetrics()
            }
        }
    }

    private func formattedTimeRange(start: Date, end: Date) -> String {
        let use24 = AppSettingsModel.shared.use24HourTime
        let f = DateFormatter()
        f.dateFormat = use24 ? "HH:mm" : "h:mm a"
        return "\(f.string(from: start)) - \(f.string(from: end))"
    }

    private func events(on day: Date) -> [CalendarEvent] {
        let startOfDay = calendar.startOfDay(for: day)
        return effectiveEvents
            .filter { calendar.isDate($0.startDate, inSameDayAs: startOfDay) }
            .sorted { $0.startDate < $1.startDate }
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
        case .day:
            let start = calendar.startOfDay(for: focusedDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? focusedDate
            return DateInterval(start: start, end: end)
        case .year:
            if let interval = calendar.dateInterval(of: .year, for: focusedDate) {
                return interval
            }
        @unknown default:
            break
        }
        return DateInterval(start: focusedDate, end: focusedDate.addingTimeInterval(24*3600))
    }

    private func updateMetrics() {
        // CalendarStats.calculate expects [EKEvent]
        metrics = CalendarStats.calculate(from: deviceCalendar.events, for: focusedDate)
    }
}

// MARK: - Month View

private struct MonthCalendarSplitView: View {
    @Binding var focusedDate: Date
    @Binding var selectedDate: Date?
    let events: [CalendarEvent]
    let onSelectDate: (Date) -> Void
    let onSelectEvent: (CalendarEvent) -> Void
    let timeFormatter: (Date, Date) -> String
    @State private var selectedEvent: CalendarEvent?

    private let calendar = Calendar.current

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            MonthCalendarView(
                focusedDate: $focusedDate,
                events: events,
                onSelectDate: { day in
                    selectedDate = day
                    onSelectDate(day)
                    selectedEvent = events(on: day).first
                },
                onSelectEvent: { event in
                    selectedEvent = event
                    onSelectEvent(event)
                }
            )
        }
        .navigationSplitViewStyle(.balanced)
        .hideSplitViewDivider()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            VStack(alignment: .leading, spacing: 6) {
                Text("Selected Date")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if let day = selectedDate {
                    Text(day.formatted(.dateTime.weekday().month().day()))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                } else {
                    Text("No date selected")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Events list
            ScrollView {
                if let day = selectedDate {
                    let eventsForDay = events(on: day)
                    if eventsForDay.isEmpty {
                        VStack(spacing: DesignSystem.Layout.spacing.small) {
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
                        LazyVStack(spacing: DesignSystem.Layout.spacing.small) {
                            ForEach(eventsForDay) { event in
                                Button {
                                    selectedEvent = event
                                    onSelectEvent(event)
                                } label: {
                                    EventRow(event: event)
                                }
                                .buttonStyle(.plain)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.Corners.pill, style: .continuous)
                                        .fill(event.id == selectedEvent?.id ? Color(nsColor: .controlAccentColor).opacity(0.1) : Color.clear)
                                )
                            }
                        }
                        .padding(12)
                    }
                } else {
                    VStack(spacing: DesignSystem.Layout.spacing.small) {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Select a day in the calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
            if let event = selectedEvent {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(DesignSystem.Typography.subHeader)
                    Text(timeFormatter(event.startDate, event.endDate))
                        .font(DesignSystem.Typography.body)
                    if let location = event.location, !location.isEmpty {
                        Text("Location: \(location)")
                            .font(DesignSystem.Typography.body)
                    }
                    if let notes = event.notes, !notes.isEmpty {
                        Text(notes)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 260, maxWidth: 280)
        .glassCard(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
    }

    private func events(on day: Date) -> [CalendarEvent] {
        events
            .filter { calendar.isDate($0.startDate, inSameDayAs: day) }
            .sorted { $0.startDate < $1.startDate }
    }
}

private struct MonthCalendarView: View {
    @Binding var focusedDate: Date
    let events: [CalendarEvent]
    let onSelectDate: (Date) -> Void
    let onSelectEvent: (CalendarEvent) -> Void
    @EnvironmentObject var eventsStore: EventsCountStore
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(monthHeader)
                    .font(DesignSystem.Typography.subHeader)
                weekdayHeader
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(days) { day in
                        let normalized = calendar.startOfDay(for: day.date)
                        let count = eventsStore.eventsByDate[normalized] ?? events(for: day.date).count
                        let isSelected = calendar.isDate(day.date, inSameDayAs: focusedDate)
                        let calendarDay = CalendarDay(
                            date: day.date,
                            isToday: calendar.isDateInToday(day.date),
                            isSelected: isSelected,
                            hasEvents: count > 0,
                            densityLevel: EventDensityLevel.fromCount(count),
                            isInCurrentMonth: day.isCurrentMonth
                        )
                        let dayEvents = events(for: day.date).sorted { $0.startDate < $1.startDate }
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                withAnimation(DesignSystem.Motion.snappyEase) {
                                    focusedDate = day.date
                                }
                                onSelectDate(day.date)
                            } label: {
                                MonthDayCell(day: calendarDay)
                            }
                            .buttonStyle(.plain)

                            if !dayEvents.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(dayEvents.prefix(3)) { event in
                                        Button {
                                            onSelectEvent(event)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(event.category.color)
                                                    .frame(width: 8, height: 8)
                                                Text(event.category.rawValue)
                                                    .font(DesignSystem.Typography.caption)
                                                    .foregroundStyle(.secondary)
                                                Text(event.title)
                                                    .font(DesignSystem.Typography.caption)
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                                Spacer(minLength: 0)
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .fill(event.category.color.opacity(0.08))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    if dayEvents.count > 3 {
                                        Text("+\(dayEvents.count - 3) more")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(6)
                        .frame(maxWidth: 180)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                                .fill(isSelected ? DesignSystem.Materials.surfaceHover : DesignSystem.Materials.surface)
                        )
                    }
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
        // Generate a safe, non-duplicating grid of days covering the month view
        guard let monthInterval = calendar.dateInterval(of: .month, for: focusedDate) else { return [] }
        let monthStart = calendar.startOfDay(for: monthInterval.start)
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: monthStart)) else { return [] }

        // last day of month is monthInterval.end - 1 second
        let lastOfMonth = calendar.date(byAdding: .second, value: -1, to: monthInterval.end) ?? monthInterval.end
        guard let endOfWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastOfMonth)),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: endOfWeekStart) else { return [] }

        var items: [DayItem] = []
        var seen = Set<Date>()
        var current = startOfWeek

        while current < endOfWeek && items.count < 42 {
            let s = calendar.startOfDay(for: current)
            if !seen.contains(s) {
                let isCurrentMonth = calendar.isDate(s, equalTo: focusedDate, toGranularity: .month)
                items.append(dayItem(for: s, isCurrentMonth: isCurrentMonth))
                seen.insert(s)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        // Ensure full weeks
        while items.count % 7 != 0 {
            if let last = items.last?.date, let next = calendar.date(byAdding: .day, value: 1, to: last) {
                let s = calendar.startOfDay(for: next)
                if !seen.contains(s) {
                    let isCurrentMonth = calendar.isDate(s, equalTo: focusedDate, toGranularity: .month)
                    items.append(dayItem(for: s, isCurrentMonth: isCurrentMonth))
                    seen.insert(s)
                } else { break }
            } else { break }
        }

        return items
    }

    private func dayItem(for date: Date, isCurrentMonth: Bool) -> DayItem {
        DayItem(id: UUID(), date: date, isCurrentMonth: isCurrentMonth, isToday: calendar.isDateInToday(date))
    }

    private func events(for date: Date) -> [CalendarEvent] {
        events.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }
    
    private func categoryColor(for title: String) -> Color {
        if let category = parseEventCategory(from: title) {
            return category.color
        }
        return Color.accentColor
    }

    private struct DayItem: Hashable, Identifiable {
        let id: UUID
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
                .font(DesignSystem.Typography.subHeader)

            WeekHeaderView(weekDays: weekDays, focusedDate: $focusedDate, calendar: calendar, events: events)

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
                HStack(alignment: .top, spacing: DesignSystem.Layout.spacing.small) {
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
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                        .fill(settings.activeAccentColor.opacity(0.2))
                        .overlay(
                            VStack(alignment: .leading, spacing: 2) {
                                Text(block.title).font(.caption.weight(.semibold))
                                Text(formatHour(block.startHour)).font(.caption2).foregroundColor(.secondary)
                            }
                            .padding(DesignSystem.Layout.spacing.small)
                        )
                        .frame(width: columnWidth - 8)
                        .frame(height: CGFloat(block.duration) * hourHeight)
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
                .font(DesignSystem.Typography.subHeader)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(isToday ? Color.accentColor.opacity(0.9) : Color(nsColor: .controlBackgroundColor).opacity(0.08))
                )
                .foregroundColor(isToday ? .white : .primary.opacity(0.8))
        }
        .padding(DesignSystem.Layout.spacing.small)
        .glassChrome(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
    }

    private func formatHour(_ hour: Double) -> String {
        let base = calendar.date(bySettingHour: Int(hour), minute: Int((hour.truncatingRemainder(dividingBy: 1)) * 60), second: 0, of: focusedDate) ?? focusedDate
        let formatter = DateFormatter()
        formatter.dateFormat = AppSettingsModel.shared.use24HourTime ? "HH:mm" : "h a"
        return formatter.string(from: base)
    }
}

// MARK: - Sidebar & Event Detail

private struct CalendarSidebarView: View {
    let selectedDate: Date
    let events: [CalendarEvent]
    let onSelectEvent: (CalendarEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            VStack(alignment: .leading, spacing: 6) {
                Text("Selected Date")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(selectedDate.formatted(.dateTime.weekday().month().day()))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Events list
            ScrollView {
                if events.isEmpty {
                    VStack(spacing: DesignSystem.Layout.spacing.small) {
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
                    LazyVStack(spacing: DesignSystem.Layout.spacing.small) {
                        ForEach(events) { event in
                            Button {
                                onSelectEvent(event)
                            } label: {
                                EventRow(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(DesignSystem.Materials.popup, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }
}

private struct EventRow: View {
    let event: CalendarEvent
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Layout.spacing.small) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(timeRange)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(location)
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                .fill(isHovered ? Color(nsColor: .controlBackgroundColor).opacity(0.15) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(DesignSystem.Motion.snappyEase) {
                isHovered = hovering
            }
        }
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
    }
}

private struct EventDetailView: View {
    let item: CalendarEvent
    @Binding var isPresented: Bool
    @EnvironmentObject private var calendarManager: CalendarManager
    @State private var showDeleteConfirm = false
    @State private var showEdit = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(item.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Date and time
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: DesignSystem.Layout.spacing.small) {
                    Image(systemName: "calendar")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text(dateRange)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                HStack(spacing: DesignSystem.Layout.spacing.small) {
                    Image(systemName: "clock")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text(timeRange)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                if let location = item.location, !location.isEmpty {
                    HStack(spacing: DesignSystem.Layout.spacing.small) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.body)
                            .foregroundStyle(.red)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 24)
                        Text(location)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
                
                if let url = item.url {
                    HStack(spacing: DesignSystem.Layout.spacing.small) {
                        Image(systemName: "link.circle.fill")
                            .font(.body)
                            .foregroundStyle(.blue)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 24)
                        Link(url.absoluteString, destination: url)
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                }
                
                if let alarms = item.alarms, !alarms.isEmpty {
                    HStack(spacing: DesignSystem.Layout.spacing.small) {
                        Image(systemName: "bell.fill")
                            .font(.body)
                            .foregroundStyle(.orange)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 24)
                        Text(alarms.compactMap { alarm in
                            CalendarManager.AlertOption.from(alarm: alarm).rawValue
                        }.joined(separator: ", "))
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
                
                if let travelTime = item.travelTime, travelTime > 0 {
                    HStack(spacing: DesignSystem.Layout.spacing.small) {
                        Image(systemName: "car.fill")
                            .font(.body)
                            .foregroundStyle(.green)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 24)
                        Text("Travel time: \(CalendarManager.TravelTimeOption.from(interval: travelTime).rawValue)")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
            }

            if let notes = item.notes, !notes.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                    Text("Notes")
                        .font(DesignSystem.Typography.subHeader)
                        .foregroundStyle(.primary)

                    ScrollView {
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                }
            }

            Spacer()

            if let identifier = item.ekIdentifier {
                Divider()
                HStack {
                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
                .confirmationDialog("Delete this item?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        _Concurrency.Task {
                            try? await calendarManager.deleteCalendarItem(identifier: identifier, isReminder: item.isReminder)
                            isPresented = false
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will remove the item from your \(item.isReminder ? "Reminders" : "Calendar").")
                }
            }
        }
        .padding(DesignSystem.Layout.spacing.large)
        .frame(minWidth: 420, minHeight: 320)
        .glassCard(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
        .sheet(isPresented: $showEdit) {
            EventEditSheet(item: item) { updated in
                _Concurrency.Task {
                    guard let id = item.ekIdentifier else { 
                        await MainActor.run {
                            errorMessage = "Event identifier not found"
                            showError = true
                        }
                        return 
                    }
                    
                    do {
                        try await calendarManager.updateEvent(
                            identifier: id,
                            title: updated.title,
                            startDate: updated.startDate,
                            endDate: updated.endDate,
                            isAllDay: updated.isAllDay,
                            location: updated.location,
                            notes: updated.notes,
                            url: updated.url,
                            primaryAlert: updated.primaryAlert,
                            secondaryAlert: updated.secondaryAlert,
                            travelTime: updated.travelTime.timeInterval,
                            recurrence: updated.recurrence,
                            category: updated.category
                        )
                        await MainActor.run {
                            isPresented = false
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = "Failed to save event: \(error.localizedDescription)"
                            showError = true
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
    }

    private var dateRange: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f.string(from: item.startDate)
    }

    private var timeRange: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: item.startDate)) – \(f.string(from: item.endDate))"
    }
}

// MARK: - Event Chips

private struct EventChipsRow: View {
    var title: String
    var events: [CalendarEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            if events.isEmpty {
                Text("No events yet.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Layout.spacing.small) {
                        ForEach(events) { event in
                            HStack(spacing: DesignSystem.Layout.spacing.small) {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.9))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.caption.weight(.semibold))
                                    Text(event.formattedTimeRange() + (event.location != nil ? " · \(event.location!)" : ""))
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

// MARK: - Editable Event Sheet

private struct EventEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: CalendarEvent
    var onSave: (EditableEvent) -> Void

    @State private var title: String
    @State private var category: EventCategory
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var location: String
    @State private var notes: String
    @State private var urlString: String
    @State private var primaryAlert: CalendarManager.AlertOption
    @State private var secondaryAlert: CalendarManager.AlertOption
    @State private var travelTime: CalendarManager.TravelTimeOption
    @State private var recurrence: CalendarManager.RecurrenceOption = .none
    @State private var urlError: String?

    init(item: CalendarEvent, onSave: @escaping (EditableEvent) -> Void) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item.title)
        _category = State(initialValue: item.category)
        _startDate = State(initialValue: item.startDate)
        _endDate = State(initialValue: item.endDate)
        _isAllDay = State(initialValue: false)
        _location = State(initialValue: item.location ?? "")
        _notes = State(initialValue: item.notes ?? "")
        _urlString = State(initialValue: item.url?.absoluteString ?? "")
        _primaryAlert = State(initialValue: item.alarms?.first.map { CalendarManager.AlertOption.from(alarm: $0) } ?? .none)
        _secondaryAlert = State(initialValue: item.alarms?.dropFirst().first.map { CalendarManager.AlertOption.from(alarm: $0) } ?? .none)
        _travelTime = State(initialValue: CalendarManager.TravelTimeOption.from(interval: item.travelTime))
    }
    
    private var isValidURL: Bool {
        guard !urlString.isEmpty else { return true }
        return URL(string: urlString) != nil
    }
    
    private var canSave: Bool {
        !title.isEmpty && isValidURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Edit Event")
                    .font(.title2.weight(.semibold))
                Spacer()
            }

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.body.weight(.medium))

            Picker("Category", selection: $category) {
                ForEach(EventCategory.allCases) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.segmented)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Time")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Toggle("All Day", isOn: $isAllDay)
                
                VStack(alignment: .leading, spacing: 6) {
                    DatePicker("Start", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Details")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                TextField("Location", text: $location)
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("URL", text: $urlString)
                        .textContentType(.URL)
                    
                    if !urlString.isEmpty && !isValidURL {
                        Text("Invalid URL format")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2, reservesSpace: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Picker("Repeat", selection: $recurrence) {
                    ForEach(CalendarManager.RecurrenceOption.allCases) { opt in
                        Text(opt.rawValue.capitalized).tag(opt)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Primary Alert", selection: $primaryAlert) {
                        ForEach(CalendarManager.AlertOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    
                    if primaryAlert != .none {
                        Picker("Secondary Alert", selection: $secondaryAlert) {
                            ForEach(CalendarManager.AlertOption.allCases) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                    }
                }
                
                Picker("Travel Time", selection: $travelTime) {
                    ForEach(CalendarManager.TravelTimeOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
            }

            Divider()
                .padding(.top, 4)

            HStack {
                Button("Cancel") { 
                    dismiss() 
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    let updated = EditableEvent(
                        title: title.isEmpty ? item.title : title,
                        category: category,
                        startDate: startDate,
                        endDate: endDate,
                        isAllDay: isAllDay,
                        location: location.isEmpty ? nil : location,
                        notes: notes.isEmpty ? nil : notes,
                        url: urlString.isEmpty ? nil : urlString,
                        primaryAlert: primaryAlert,
                        secondaryAlert: secondaryAlert,
                        travelTime: travelTime,
                        recurrence: recurrence
                    )
                    onSave(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding()
        .frame(minWidth: 440)
    }

    struct EditableEvent {
        var title: String
        var category: EventCategory
        var startDate: Date
        var endDate: Date
        var isAllDay: Bool
        var location: String?
        var notes: String?
        var url: String?
        var primaryAlert: CalendarManager.AlertOption
        var secondaryAlert: CalendarManager.AlertOption
        var travelTime: CalendarManager.TravelTimeOption
        var recurrence: CalendarManager.RecurrenceOption
    }
}

// MARK: - Sample Data

private extension CalendarPageView {
    static var sampleEvents: [CalendarEvent] { [] }
}

private extension CalendarEvent {
    func formattedTimeRange(use24HourTime: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = use24HourTime ? "HH:mm" : "h:mm a"
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
}

// MARK: - Week Header View & Styles

private struct DayColumnStyle: ViewModifier {
    let cornerRadius: CGFloat = 14
    let height: CGFloat = 80
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(DesignSystem.Layout.spacing.small)
            .glassChrome(cornerRadius: cornerRadius)
    }
}

private extension View {
    func dayColumnStyle() -> some View { modifier(DayColumnStyle()) }
}

private struct WeekHeaderView: View {
    let weekDays: [Date]
    @Binding var focusedDate: Date
    let calendar: Calendar
    let events: [CalendarEvent]
    private let spacing: CGFloat = 8

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(weekDays, id: \.self) { date in
                let count = eventsCount(for: date)
                let day = CalendarDay(
                    date: date,
                    isToday: calendar.isDateInToday(date),
                    isSelected: calendar.isDate(date, inSameDayAs: focusedDate),
                    hasEvents: count > 0,
                    densityLevel: EventDensityLevel.fromCount(count),
                    isInCurrentMonth: true
                )
                Button {
                    withAnimation(DesignSystem.Motion.snappyEase) {
                        focusedDate = date
                    }
                } label: {
                    DayHeaderCard(day: day)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func eventsCount(for date: Date) -> Int {
        let start = calendar.startOfDay(for: date)
        return events.filter { calendar.isDate($0.startDate, inSameDayAs: start) }.count
    }
}

// MARK: - Modern Calendar Entry

struct CalendarView: View {
    private static let debugDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f
    }()
    @EnvironmentObject private var calendarManager: CalendarManager
    @EnvironmentObject private var deviceCalendar: DeviceCalendarManager
    @State private var viewMode: CalendarViewMode = .month
    @State private var currentMonth: Date = Date()
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var keyMonitor: Any?

    private var monthEvents: [EKEvent] {
        displayEKEvents
    }

    private var calendarEvents: [CalendarEvent] {
        displayEKEvents.map {
            CalendarEvent(title: $0.title, startDate: $0.startDate, endDate: $0.endDate, location: $0.location, notes: $0.notes, url: $0.url, alarms: $0.alarms, travelTime: nil, ekIdentifier: $0.eventIdentifier, isReminder: false)
        }
    }

    private var displayEKEvents: [EKEvent] {
        let selectedId = calendarManager.selectedCalendarID
        guard !selectedId.isEmpty else { return [] }
        return deviceCalendar.events.filter { $0.calendar.calendarIdentifier == selectedId }
    }

    private var isLoading: Bool {
        calendarManager.isLoading
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CalendarStatsRow()
                    .frame(height: 100)

                HStack(spacing: 20) {
                    DayDetailSidebar(
                        date: calendarManager.selectedDate ?? Date(),
                        events: sidebarEvents(for: calendarManager.selectedDate ?? Date())
                    ) { event in
                        selectedEvent = event
                    }

                    VStack(spacing: 0) {
                        CalendarHeader(
                            viewMode: $viewMode,
                            currentMonth: $currentMonth,
                            onPrevious: { step(by: -1) },
                            onNext: { step(by: 1) },
                            onToday: { jumpToToday() },
                            onSearch: nil
                        )
                        .padding()

                        if isLoading {
                            loadingState
                        } else if !calendarManager.isAuthorized {
                            CalendarEmptyState(
                                title: "Calendar access needed",
                                message: "Grant permission to pull your events. You can do this in Settings → Privacy."
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if displayEKEvents.isEmpty {
                            CalendarEmptyState(
                                title: "No events found",
                                message: "Nothing is scheduled for this calendar yet. Create an event to see it here."
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            switch viewMode {
                            case .day:
                                CalendarDayView(
                                    date: calendarManager.selectedDate ?? Date(),
                                    events: displayEKEvents.filter { Calendar.current.isDate($0.startDate, inSameDayAs: calendarManager.selectedDate ?? Date()) },
                                    onSelectEvent: { ek in selectedEvent = mapEvent(ek) }
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            case .week:
                                CalendarWeekView(
                                    currentDate: currentMonth,
                                    events: displayEKEvents,
                                    onSelectEvent: { ek in selectedEvent = mapEvent(ek) }
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            case .month:
                                CalendarGrid(currentMonth: $currentMonth, events: monthEvents)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.horizontal, 8)
                            case .year:
                                CalendarYearView(currentYear: currentMonth)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            @unknown default:
                                CalendarGrid(currentMonth: $currentMonth, events: monthEvents)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .background(DesignSystem.Materials.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(20)
            // Reserve space so the floating tab bar in the root ContentView stays visible.
            .padding(.bottom, 120)
        }
        .onAppear {
            calendarManager.selectedDate = calendarManager.selectedDate ?? Date()
            currentMonth = calendarManager.selectedDate ?? Date()
            calendarManager.ensureMonthCache(for: currentMonth)
            startKeyboardMonitoring()
        }
        .overlay(alignment: .topTrailing) {
            if AppSettingsModel.shared.devModeEnabled {
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(DeviceCalendarManager.shared.isAuthorized ? "Authorized" : "Unauthorized")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.45)))

                        Text("Events: \(DeviceCalendarManager.shared.events.count)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.45)))
                    }

                    Text("Last refresh: \(DeviceCalendarManager.shared.lastRefreshAt.map { Self.debugDateFormatter.string(from: $0) } ?? "never")")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.35)))

                    Text(DeviceCalendarManager.shared.isObservingStoreChanges ? "Observer: registered" : "Observer: not registered")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.35)))
                }
                .padding(8)
                .opacity(0.8)
            }
        }
        .onDisappear {
            stopKeyboardMonitoring()
        }
        .onChange(of: currentMonth) { _, newValue in
            calendarManager.ensureMonthCache(for: newValue)
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(
                item: event,
                isPresented: Binding(get: { selectedEvent != nil }, set: { if !$0 { selectedEvent = nil } })
            )
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading events…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func step(by value: Int) {
        var components = DateComponents()
        switch viewMode {
        case .day:
            components.day = value
        case .week:
            components.day = value * 7
        case .month:
            components.month = value
        case .year:
            components.year = value
        }
        if let newDate = Calendar.current.date(byAdding: components, to: currentMonth) {
            currentMonth = newDate
            calendarManager.selectedDate = newDate
        }
    }

    private func jumpToToday() {
        let today = Date()
        currentMonth = today
        calendarManager.selectedDate = today
    }

    // MARK: - Keyboard navigation (arrow keys)
#if os(macOS)
    private func startKeyboardMonitoring() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 123: // left
                step(by: -1)
                return nil
            case 124: // right
                step(by: 1)
                return nil
            default:
                return event
            }
        }
    }

    private func stopKeyboardMonitoring() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
#endif

    private func eventsForDay(_ date: Date) -> [EKEvent] {
        displayEKEvents.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    private func sidebarEvents(for date: Date) -> [CalendarEvent] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return calendarEvents
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: startOfDay) }
            .sorted { $0.startDate < $1.startDate }
    }

    private func mapEvent(_ ek: EKEvent) -> CalendarEvent {
        let (cleanNotes, storedCategory) = calendarManager.decodeNotesWithCategory(notes: ek.notes)
        return CalendarEvent(title: ek.title, startDate: ek.startDate, endDate: ek.endDate, location: ek.location, notes: cleanNotes, url: ek.url, alarms: ek.alarms, travelTime: nil, ekIdentifier: ek.eventIdentifier, isReminder: false, category: storedCategory)
    }

    private func eventCategoryLabel(for title: String) -> String {
        let lower = title.lowercased()
        let pairs: [(String, String)] = [
            ("exam", "Exam"),
            ("midterm", "Exam"),
            ("final", "Exam"),
            ("class", "Class"),
            ("lecture", "Class"),
            ("lab", "Class"),
            ("study", "Study"),
            ("read", "Reading"),
            ("homework", "Homework"),
            ("assignment", "Homework"),
            ("problem set", "Homework"),
            ("practice test", "Practice Test"),
            ("mock", "Practice Test"),
            ("quiz", "Practice Test"),
            ("meeting", "Meeting"),
            ("sync", "Meeting"),
            ("1:1", "Meeting"),
            ("one-on-one", "Meeting")
        ]
        for (key, label) in pairs {
            if lower.contains(key) { return label }
        }
        return "Other"
    }
    
    private func categoryColor(for title: String) -> Color {
        if let category = parseEventCategory(from: title) {
            return category.color
        }
        return Color.accentColor
    }
}

struct CalendarPageView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CalendarPageView()
                .environmentObject(AppSettingsModel.shared)
                .environmentObject(EventsCountStore())
                .environmentObject(CalendarManager.shared)
                .previewLayout(.sizeThatFits)
                .frame(width: 1100, height: 720)

            CalendarPageView()
                .environmentObject(AppSettingsModel.shared)
                .environmentObject(EventsCountStore())
                .environmentObject(CalendarManager.shared)
                .preferredColorScheme(.dark)
                .previewLayout(.sizeThatFits)
                .frame(width: 1100, height: 720)
        }
    }
}

private struct NewEventPlaceholder: View {
    var date: Date
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Event")
                .font(.title2.weight(.semibold))
            Text(date.formatted(date: .long, time: .omitted))
                .foregroundStyle(.secondary)
            Text("Event creation flow goes here.")
                .foregroundStyle(.secondary)
            Spacer()
            HStack {
                Spacer()
                Button("Close") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(DesignSystem.Layout.padding.window)
    }
}

private struct CalendarEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Shared Day Helpers

struct CalendarDay: Hashable {
    var date: Date
    var isToday: Bool
    var isSelected: Bool
    var hasEvents: Bool
    var densityLevel: EventDensityLevel
    var isInCurrentMonth: Bool
}

private struct DayHeaderCard: View {
    let day: CalendarDay
    private let calendar = Calendar.current
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            Text(weekdaySymbol.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(day.isSelected ? .white : .secondary)
            Text("\(calendar.component(.day, from: day.date))")
                .font(DesignSystem.Typography.subHeader)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(day.isSelected ? Color.accentColor : Color.clear)
                        .background(
                            Circle().fill(DesignSystem.Materials.hud)
                        )
                )
                .foregroundColor(day.isSelected ? .white : .primary.opacity(0.8))
        }
        .padding(DesignSystem.Layout.spacing.small)
        .frame(maxWidth: .infinity)
        .glassChrome(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
        .scaleEffect(hovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: DesignSystem.Motion.instant), value: hovering)
        .onHover { hovering = $0 }
    }

    private var weekdaySymbol: String {
        Calendar.current.shortWeekdaySymbols[(Calendar.current.component(.weekday, from: day.date) - 1 + 7) % 7]
    }
}

private struct MonthDayCell: View {
    let day: CalendarDay
    private let calendar = Calendar.current
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 7) {
            Text(dayNumber)
                .font(DesignSystem.Typography.body)
                .frame(width: 32, height: 32)
                .foregroundColor(textColor)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(DesignSystem.Materials.hud)
                        
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(backgroundFill)
                            .padding(2)
                    }
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(outlineColor, lineWidth: outlineWidth)
                )

        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .scaleEffect(hovering ? 1.01 : 1.0)
        .animation(.easeInOut(duration: DesignSystem.Motion.instant), value: hovering)
        .onHover { hovering = $0 }
    }

    private var dayNumber: String { String(calendar.component(.day, from: day.date)) }

    private var textColor: Color {
        if day.isSelected { return .white }
        if !day.isInCurrentMonth { return .secondary.opacity(0.5) }
        if day.isToday { return .accentColor }
        return .primary
    }

    private var backgroundFill: Color {
        if day.isSelected { return .accentColor }
        if day.isToday { return .accentColor.opacity(0.12) }
        return .clear
    }

    private var outlineColor: Color {
        if day.isSelected { return Color.accentColor.opacity(0.3) }
        if day.isToday { return Color.accentColor.opacity(0.4) }
        return .clear
    }
    
    private var outlineWidth: CGFloat {
        day.isSelected ? 2.5 : 1
    }
    
    private var shadowColor: Color {
        if day.isSelected { return Color.accentColor.opacity(0.4) }
        return .clear
    }
    
    private var shadowRadius: CGFloat {
        day.isSelected ? 6 : 0
    }
    
    private var shadowY: CGFloat {
        day.isSelected ? 3 : 0
    }
}

// MARK: - Metrics

private struct CalendarStats {
    let averagePerDay: Double
    let totalItems: Int
    let busiestDayName: String
    let busiestDayCount: Int

    static let empty = CalendarStats(averagePerDay: 0, totalItems: 0, busiestDayName: "—", busiestDayCount: 0)

    static func calculate(from events: [EKEvent], for date: Date) -> CalendarStats {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: date) ?? 0..<0
        let numDaysInMonth = range.count

        let components = calendar.dateComponents([.year, .month], from: date)
        let monthEvents = events.filter { event in
            let eventComponents = calendar.dateComponents([.year, .month], from: event.startDate)
            return eventComponents.year == components.year && eventComponents.month == components.month
        }

        let total = monthEvents.count
        let average = numDaysInMonth > 0 ? Double(total) / Double(numDaysInMonth) : 0.0

        let eventsByDay = Dictionary(grouping: monthEvents) { event in
            calendar.component(.day, from: event.startDate)
        }

        if let maxEntry = eventsByDay.max(by: { $0.value.count < $1.value.count }) {
            var dayComponents = components
            dayComponents.day = maxEntry.key
            if let busyDate = calendar.date(from: dayComponents) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return CalendarStats(
                    averagePerDay: average,
                    totalItems: total,
                    busiestDayName: formatter.string(from: busyDate),
                    busiestDayCount: maxEntry.value.count
                )
            }
        }

        return CalendarStats(
            averagePerDay: average,
            totalItems: total,
            busiestDayName: "—",
            busiestDayCount: 0
        )
    }
}

private struct MetricsRow: View {
    var metrics: CalendarStats
    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            MetricCard(title: "Average / Day", value: String(format: "%.1f", metrics.averagePerDay), subtitle: "This month", systemImage: "chart.bar.xaxis")
            MetricCard(title: "Total This Month", value: "\(metrics.totalItems)", subtitle: "Calendar items", systemImage: "calendar")
            MetricCard(title: "Busiest Day", value: metrics.busiestDayName, subtitle: busiestSubtitle, systemImage: "flame")
        }
        .transition(DesignSystem.Motion.slideUpTransition)
        .animation(DesignSystem.Motion.standardEase, value: metrics.totalItems)
    }

    private var busiestSubtitle: String {
        metrics.busiestDayCount > 0 ? "\(metrics.busiestDayCount) items" : "No items"
    }
}

private struct MetricCard: View {
    var title: String
    var value: String
    var subtitle: String
    var systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(RootsColor.subtleFill))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .glassCard(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
    }
}
#endif
