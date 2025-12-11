import SwiftUI
import EventKit
import Foundation
import Combine
import _Concurrency

struct DashboardView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var calendarManager: CalendarManager
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var coursesStore: CoursesStore
    @State private var isLoaded = false
    @State private var cancellables: Set<AnyCancellable> = []
    @State private var todayBounce = false
    @State private var energyBounce = false
    @State private var selectedDate: Date = Date()
    @State private var tasks: [DashboardTask] = []
    @State private var events: [DashboardEvent] = []

    var body: some View {
        ScrollView {
            GeometryReader { geo in
                let spacing: CGFloat = DesignSystem.Layout.spacing.medium

                HStack(alignment: .top, spacing: spacing) {
                    VStack(alignment: .leading, spacing: spacing) {
                        todayCard
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animateEntry(isLoaded: isLoaded, index: 0)
                        eventsCard
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animateEntry(isLoaded: isLoaded, index: 1)
                        calendarCard
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animateEntry(isLoaded: isLoaded, index: 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: spacing) {
                        clockCard
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animateEntry(isLoaded: isLoaded, index: 3)
                        assignmentsCard
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animateEntry(isLoaded: isLoaded, index: 4)
                        energyCard
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animateEntry(isLoaded: isLoaded, index: 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, DesignSystem.Layout.padding.window)
                .padding(.vertical, DesignSystem.Layout.spacing.medium)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minHeight: 0)
        }
        .onAppear {
            isLoaded = true
            LOG_UI(.info, "Navigation", "Displayed DashboardView")
            syncTasks()
            syncEvents()

            // subscribe to course deletions
            CoursesStore.courseDeletedPublisher
                .receive(on: DispatchQueue.main)
                .sink { deletedId in
                    assignmentsStore.tasks.removeAll { $0.courseId == deletedId }
                    syncTasks()
                }
                .store(in: &cancellables)
        }
        .background(DesignSystem.Colors.appBackground)
        .onReceive(assignmentsStore.$tasks) { _ in
            syncTasks()
        }
        .onReceive(calendarManager.$dailyEvents) { _ in
            syncEvents()
        }
        .onReceive(calendarManager.$cachedMonthEvents) { _ in
            syncEvents()
        }
        .onChange(of: calendarManager.selectedCalendarID) { _, _ in
            syncEvents()
        }
    }

    private var todayCard: some View {
        RootsCard(
            title: cardTitle("Today Overview"),
            icon: "sun.max"
        ) {
            VStack(alignment: .leading, spacing: RootsSpacing.m) {
                let eventStatus = EKEventStore.authorizationStatus(for: .event)
                switch eventStatus {
                case .notDetermined:
                    HStack {
                        Text("Connect Apple Calendar to show events")
                            .rootsBody()
                        Spacer()
                        Button("Connect Apple Calendar", action: {
                            print("🔘 [Dashboard] Connect button tapped")
                            _Concurrency.Task {
                                await calendarManager.requestAccess()
                            }
                        })
                        .buttonStyle(RootsLiquidButtonStyle())
                    }
                case .denied, .restricted:
                    HStack {
                        Text("Access Denied. Open Settings.")
                            .rootsBody()
                        Spacer()
                        Button("Open Settings") {
                            calendarManager.openSystemPrivacySettings()
                        }
                        .buttonStyle(RootsLiquidButtonStyle())
                    }
                default:
                    dashboardTodayStats
                }
            }
        }
        .onTapGesture {
            todayBounce.toggle()
            print("[Dashboard] card tapped: todayOverview")
        }
        .help("Today Overview")
        .accessibilityIdentifier("DashboardHeader")
    }

    private var energyCard: some View {
        Group {
            if settings.showEnergyPanel {
                RootsCard(
                    title: cardTitle("Energy"),
                    icon: "bolt.heart.fill"
                ) {
                    HStack(spacing: 10) {
                        Button("High") { setEnergy(.high) }
                            .buttonStyle(.borderedProminent)
                        Button("Medium") { setEnergy(.medium) }
                            .buttonStyle(.bordered)
                        Button("Low") { setEnergy(.low) }
                            .buttonStyle(.bordered)
                    }
                    .font(DesignSystem.Typography.body)
                }
                .onTapGesture {
                    energyBounce.toggle()
                    print("[Dashboard] card tapped: energyFocus")
                }
                .help("Energy & Focus")
            }
        }
    }

    private var eventsCard: some View {
        RootsCard {
            VStack(alignment: .leading, spacing: RootsSpacing.m) {
                Text("Events Today").rootsSectionHeader()
                DashboardEventsColumn(events: events)
            }
        }
    }

    private var assignmentsCard: some View {
        RootsCard {
            VStack(alignment: .leading, spacing: RootsSpacing.m) {
                Text("Assignments Due Today").rootsSectionHeader()
                DashboardTasksColumn(tasks: $tasks)
            }
        }
    }

    private var calendarCard: some View {
        RootsCard {
            VStack(alignment: .leading, spacing: RootsSpacing.m) {
                Text("Calendar").rootsSectionHeader()
                DashboardCalendarColumn(selectedDate: $selectedDate, events: events)
            }
        }
    }

    private var clockCard: some View {
        RootsCard {
            HStack(alignment: .center, spacing: RootsSpacing.l) {
                RootsAnalogClock(diameter: 180, showSecondHand: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: RootsSpacing.m) {
                    ForEach(quickActions, id: \.label) { action in
                        Button {
                            action.handler()
                        } label: {
                            Label(action.label, systemImage: action.icon)
                                .font(.title3.weight(.semibold))
                                .frame(maxWidth: 220, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }

    private var quickActions: [(label: String, icon: String, handler: () -> Void)] {
        [
            ("Add Assignment", "plus.circle", { print("[Dashboard] Quick action: Add Assignment") }),
            ("Add Event", "calendar.badge.plus", { print("[Dashboard] Quick action: Add Event") }),
            ("Add Course", "graduationcap", { print("[Dashboard] Quick action: Add Course") }),
            ("Open Planner", "list.bullet.rectangle", { print("[Dashboard] Quick action: Open Planner") })
        ]
    }

    private func cardTitle(_ title: String) -> String? { title }

    private var dashboardTodayStats: some View {
        let eventsTodayCount = todaysCalendarEvents().count
        let dueToday = tasksDueToday().count

        return DashboardTileBody(
            rows: [
                ("Events Today", "\(eventsTodayCount)"),
                ("Items Due Today", "\(dueToday)")
            ]
        )
    }

    private func syncTasks() {
        let dueTodayTasks = tasksDueToday()
        tasks = dueTodayTasks.map { appTask in
            DashboardTask(title: appTask.title, course: appTask.courseId?.uuidString, isDone: appTask.isCompleted)
        }
    }

    private func syncEvents() {
        let todayEvents = todaysCalendarEvents()
        let mapped = todayEvents.map { event in
            DashboardEvent(
                title: event.title,
                time: "\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))",
                location: event.location,
                date: event.startDate
            )
        }
        events = mapped.sorted { $0.date < $1.date }
    }

    private func todaysCalendarEvents() -> [EKEvent] {
        let cal = Calendar.current
        let source = calendarManager.dailyEvents.isEmpty ? calendarManager.cachedMonthEvents : calendarManager.dailyEvents
        return source.filter { event in
            cal.isDateInToday(event.startDate) &&
            (calendarManager.selectedCalendarID.isEmpty || event.calendar.calendarIdentifier == calendarManager.selectedCalendarID)
        }
    }

    private func tasksDueToday() -> [AppTask] {
        let cal = Calendar.current
        return assignmentsStore.tasks
            .filter { !$0.isCompleted }
            .filter { task in
                guard let due = task.due else { return false }
                return cal.isDateInToday(due)
            }
            .sorted { ($0.due ?? Date.distantFuture) < ($1.due ?? Date.distantFuture) }
    }

    private func setEnergy(_ level: EnergyLevel) {
        let current = SchedulerPreferencesStore.shared.preferences.learnedEnergyProfile
        let base: [Int: Double]
        switch level {
        case .high:
            base = current.mapValues { min(1.0, $0 + 0.2) }
        case .medium:
            base = current
        case .low:
            base = current.mapValues { max(0.1, $0 - 0.2) }
        }
        SchedulerPreferencesStore.shared.updateEnergyProfile(base)
    }

    private enum EnergyLevel {
        case high, medium, low
    }
}

struct DashboardTileBody: View {
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.0)
                        .rootsBodySecondary()
                    Text(row.1)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(RootsColor.textPrimary)
                }
            }
        }
    }
}

private extension View {
    func animateEntry(isLoaded: Bool, index: Int) -> some View {
        self
            .opacity(isLoaded ? 1 : 0)
            .offset(y: isLoaded ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.05), value: isLoaded)
    }
}

// MARK: - Models for dashboard layout

struct DashboardTask: Identifiable {
    let id = UUID()
    var title: String
    var course: String?
    var isDone: Bool
}

struct DashboardEvent: Identifiable {
    let id = UUID()
    var title: String
    var time: String
    var location: String?
    var date: Date
}

// MARK: - Columns

private struct DashboardCalendarColumn: View {
    @Binding var selectedDate: Date
    var events: [DashboardEvent]
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendar").rootsSectionHeader()
            Text(monthHeader(for: selectedDate)).rootsBodySecondary()

            LazyVGrid(columns: columns, spacing: DesignSystem.Layout.spacing.small) {
                       ForEach(dayItems) { item in
                         let day = item.date
                    let isInMonth = calendar.isDate(day, equalTo: selectedDate, toGranularity: .month)
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                    let normalized = calendar.startOfDay(for: day)
                    let count = eventsByDate[normalized] ?? 0

                    Button {
                        selectedDate = day
                    } label: {
                        CalendarDayCell(
                            date: day,
                            isInCurrentMonth: isInMonth,
                            isSelected: isSelected,
                            eventCount: count,
                            calendar: calendar
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .rootsCardBackground(radius: 20)
        }
        .padding(DesignSystem.Layout.padding.card)
        .rootsCardBackground(radius: 22)
    }

    private var eventsByDate: [Date: Int] {
        Dictionary(grouping: events, by: { calendar.startOfDay(for: $0.date) })
            .mapValues { $0.count }
    }

    private struct DayItem: Identifiable, Hashable {
        let id = UUID()
        let date: Date
        let isCurrentMonth: Bool
    }

    private var dayItems: [DayItem] {
        days.map { DayItem(date: $0, isCurrentMonth: calendar.isDate($0, equalTo: selectedDate, toGranularity: .month)) }
    }

    private var days: [Date] {
        // Safe generator that yields unique start-of-day Dates covering the month grid
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else { return [] }
        let monthStart = calendar.startOfDay(for: monthInterval.start)
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: monthStart)) else { return [] }

        let lastOfMonth = calendar.date(byAdding: .second, value: -1, to: monthInterval.end) ?? monthInterval.end
        guard let endOfWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastOfMonth)),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: endOfWeekStart) else { return [] }

        var items: [Date] = []
        var seen = Set<Date>()
        var current = startOfWeek

        while current < endOfWeek && items.count < 42 {
            let s = calendar.startOfDay(for: current)
            if !seen.contains(s) {
                items.append(s)
                seen.insert(s)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        // ensure full week rows
        while items.count % 7 != 0 {
            if let last = items.last, let next = calendar.date(byAdding: .day, value: 1, to: last) {
                let s = calendar.startOfDay(for: next)
                if !seen.contains(s) {
                    items.append(s)
                    seen.insert(s)
                } else { break }
            } else { break }
        }

        return items
    }

    private func monthHeader(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}

private struct DashboardTasksColumn: View {
    @Binding var tasks: [DashboardTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Due Today")
                .rootsSectionHeader()

            if tasks.isEmpty {
                Text("No assignments due today.")
                    .rootsBodySecondary()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(tasks.indices, id: \.self) { index in
                            TaskRow(task: $tasks[index],
                                    showConnectorAbove: index != 0,
                                    showConnectorBelow: index != tasks.count - 1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .rootsCardBackground(radius: 22)
    }
}

private struct DashboardEventsColumn: View {
    var events: [DashboardEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Events")
                .rootsSectionHeader()

            if events.isEmpty {
                Text("No upcoming events.")
                    .rootsBodySecondary()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(events) { event in
                            HStack(alignment: .top, spacing: DesignSystem.Layout.spacing.small) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(DesignSystem.Typography.body)
                                    Text(event.time)
                                        .rootsBodySecondary()
                                    if let location = event.location {
                                        Text(location)
                                            .rootsCaption()
                                    }
                                }
                                Spacer()
                            }
                            .padding(10)
                            .rootsCardBackground(radius: 18)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .background(DesignSystem.Materials.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Calendar Load Helpers


// MARK: - Task Row

private struct TaskRow: View {
    @Binding var task: DashboardTask
    var showConnectorAbove: Bool
    var showConnectorBelow: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                VStack {
                    if showConnectorAbove {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(width: 2, height: 8)
                            .offset(y: -6)
                    }
                    Spacer()
                    if showConnectorBelow {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(width: 2, height: 8)
                            .offset(y: 6)
                    }
                }

                Button {
                    task.isDone.toggle()
                } label: {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(task.isDone ? Color.accentColor : Color.clear)
                        )
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(.white)
                                .opacity(task.isDone ? 1.0 : 0.0)
                        )
                }
                .buttonStyle(.plain)
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(DesignSystem.Typography.body)
                    .strikethrough(task.isDone, color: .secondary)

                if let course = task.course {
                    Text(course)
                        .rootsCaption()
                }
            }

            Spacer()
        }
        .padding(10)
        .rootsCardBackground(radius: 18)
    }
}

// MARK: - Static Month Calendar

struct StaticMonthCalendarView: View {
    let currentDate: Date
    var events: [DashboardEvent] = []
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: DesignSystem.Layout.spacing.small) {
            weekdayHeader
            LazyVGrid(columns: columns, spacing: DesignSystem.Layout.spacing.small) {
                ForEach(leadingBlanks, id: \.self) { _ in
                    Text(" ")
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                ForEach(daysInMonth, id: \.self) { day in
                    let date = calendar.date(bySetting: .day, value: day, of: currentDate) ?? currentDate
                    let count = events.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
                    let isSelected = calendar.isDate(date, inSameDayAs: currentDate)
                    CalendarDayCell(date: date, isInCurrentMonth: calendar.isDate(date, equalTo: currentDate, toGranularity: .month), isSelected: isSelected, eventCount: count, calendar: calendar)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1 // Calendar is 1-based
        let ordered = Array(symbols[firstWeekdayIndex..<symbols.count] + symbols[0..<firstWeekdayIndex])

        return HStack(spacing: 6) {
            ForEach(ordered, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayView(_ day: Int) -> some View {
        let isToday = day == todayDay && isCurrentMonth
        return Text("\(day)")
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 32)
            .padding(6)
            .background(
                Circle()
                    .fill(isToday ? Color.accentColor.opacity(0.85) : Color.clear)
                    .background(
                        Circle().fill(Color(nsColor: .controlBackgroundColor).opacity(isToday ? 0.12 : 0.06))
                    )
            )
            .foregroundColor(isToday ? .white : .primary.opacity(0.7))
    }

    private var todayDay: Int {
        calendar.component(.day, from: currentDate)
    }

    private var isCurrentMonth: Bool {
        let now = Date()
        return calendar.isDate(now, equalTo: currentDate, toGranularity: .month)
    }

    private var daysInMonth: [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: currentDate) else { return [] }
        return Array(range)
    }

    private var leadingBlanks: [Int] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: currentDate),
            let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
        else { return [] }

        let adjusted = (firstWeekday - calendar.firstWeekday + 7) % 7
        return Array(0..<adjusted)
    }
}
