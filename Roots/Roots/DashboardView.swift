import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var todayBounce = false
    @State private var energyBounce = false
    @State private var insightsBounce = false
    @State private var deadlinesBounce = false
    @State private var selectedDate: Date = Date()
    @State private var tasks: [DashboardTask] = [
        .init(title: "MA 231 – Problem Set 5", course: "MA 231", isDone: false),
        .init(title: "ST 311 – Quiz Review", course: "ST 311", isDone: false),
        .init(title: "Read Genetics notes", course: "GN 311", isDone: true)
    ]
    @State private var events: [DashboardEvent] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return [
            .init(title: "MA 231 Lecture", time: "9:00–9:50 AM", location: "Biltmore 204", date: today),
            .init(title: "GN 311 Lab", time: "2:30–4:20 PM", location: "Jordan 112", date: calendar.date(byAdding: .day, value: 1, to: today) ?? today),
            .init(title: "Study Block – Library", time: "7:00–9:00 PM", location: "DHH Hill", date: calendar.date(byAdding: .day, value: 3, to: today) ?? today),
            .init(title: "Advisor Meeting", time: "3:00–3:45 PM", location: "Student Center", date: today)
        ]
    }()

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let columns: Int = width > 1400 ? 3 : (width > 900 ? 2 : 1)

            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: RootsSpacing.l), count: columns),
                    spacing: RootsSpacing.l
                ) {
                    todayCard
                    energyCard
                    deadlinesCard
                    DashboardCalendarColumn(selectedDate: $selectedDate, events: events)
                    DashboardTasksColumn(tasks: $tasks)
                    DashboardEventsColumn(events: events)
                }
                .padding(.horizontal, RootsSpacing.s)
                .padding(.bottom, RootsSpacing.xl)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, RootsSpacing.m)
            .background(Color.clear)
        }
        .onAppear { LOG_UI(.info, "Navigation", "Displayed DashboardView") }
        .rootsSystemBackground()
    }

    private var todayCard: some View {
        RootsCard(
            title: cardTitle("Today Overview"),
            icon: "sun.max"
        ) {
            DashboardTileBody(
                rows: [
                    ("Schedule Today", "No data available"),
                    ("Mood", "Balanced")
                ]
            )
        }
        .onTapGesture {
            todayBounce.toggle()
            print("[Dashboard] card tapped: todayOverview")
        }
        .help("Today Overview")
    }

    private var energyCard: some View {
        Group {
            if settings.showEnergyPanel {
                RootsCard(
                    title: cardTitle("Energy & Focus"),
                    icon: "heart.fill"
                ) {
                    DashboardTileBody(
                        rows: [
                            ("Streak", "4 days"),
                            ("Focus Window", "Next slot 2h")
                        ]
                    )
                }
                .onTapGesture {
                    energyBounce.toggle()
                    print("[Dashboard] card tapped: energyFocus")
                }
                .help("Energy & Focus")
            } else {
                EmptyView()
            }
        }
    }

    private var insightsCard: some View {
        RootsCard(
            title: cardTitle("Insights"),
            icon: "lightbulb.fill"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .rootsBody()
            }
        }
        .onTapGesture {
            insightsBounce.toggle()
            print("[Dashboard] card tapped: insights")
        }
        .help("Insights")
    }

    private var deadlinesCard: some View {
        RootsCard(
            title: cardTitle("Upcoming Deadlines"),
            icon: "clock.arrow.circlepath"
        ) {
            DashboardTileBody(
                rows: [
                    ("Next", "Assignment - due tomorrow"),
                    ("Following", "Quiz - Friday")
                ]
            )
        }
        .onTapGesture {
            deadlinesBounce.toggle()
            print("[Dashboard] card tapped: upcomingDeadlines")
        }
        .help("Upcoming Deadlines")
    }

    private func cardTitle(_ title: String) -> String? { title }

}

struct DashboardTileBody: View {
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.0)
                        .rootsBodySecondary()
                    Text(row.1)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RootsColor.textPrimary)
                }
            }
        }
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

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days, id: \.self) { day in
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
        .padding()
        .rootsCardBackground(radius: 22)
    }

    private var eventsByDate: [Date: Int] {
        Dictionary(grouping: events, by: { calendar.startOfDay(for: $0.date) })
            .mapValues { $0.count }
    }

    private var days: [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
            let startWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday,
            let range = calendar.range(of: .day, in: .month, for: selectedDate)
        else { return [] }

        let firstWeekdayIndex = (startWeekday - calendar.firstWeekday + 7) % 7
        var items: [Date] = []

        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: selectedDate),
           let prevRange = calendar.range(of: .day, in: .month, for: prevMonth) {
            let prefixDays = prevRange.suffix(firstWeekdayIndex)
            for day in prefixDays {
                if let date = calendar.date(bySetting: .day, value: day, of: prevMonth) {
                    items.append(date)
                }
            }
        }

        for day in range {
            if let date = calendar.date(bySetting: .day, value: day, of: selectedDate) {
                items.append(date)
            }
        }

        while items.count % 7 != 0 {
            if let nextDate = calendar.date(byAdding: .day, value: 1, to: items.last ?? selectedDate) {
                items.append(nextDate)
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
            Text("Today’s Tasks")
                .rootsSectionHeader()

            if tasks.isEmpty {
                Text("No tasks scheduled.")
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
        .padding()
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
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.system(size: 13, weight: .semibold))
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
        .padding()
        .background(.regularMaterial)
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
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(task.isDone ? 1.0 : 0.0)
                        )
                }
                .buttonStyle(.plain)
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
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
        VStack(spacing: 10) {
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 8) {
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
