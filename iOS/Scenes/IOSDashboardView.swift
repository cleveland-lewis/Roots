//
//  IOSDashboardView.swift
//  Roots (iOS)
//

#if os(iOS)
import SwiftUI
import EventKit

struct IOSDashboardView: View {
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var deviceCalendar: DeviceCalendarManager
    @EnvironmentObject private var settings: AppSettingsModel

    @State private var selectedDate = Date()
    @AppStorage("dashboard.greeting.dateKey") private var greetingDateKey: String = ""
    @AppStorage("dashboard.greeting.text") private var storedGreeting: String = ""

    private let calendar = Calendar.current

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                heroHeader
                quickStatsRow
                weekStrip
                upcomingEventsCard
                dueTasksCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(DesignSystem.Colors.appBackground.ignoresSafeArea())
        .modifier(IOSNavigationChrome(title: NSLocalizedString("ios.dashboard.title", comment: "Dashboard")) {
            Button {
                selectedDate = Date()
            } label: {
                Image(systemName: "dot.circle.and.hand.point.up.left.fill")
            }
            .accessibilityLabel(NSLocalizedString("ios.dashboard.today", comment: "Jump to today"))
        })
        .task {
            await deviceCalendar.bootstrapOnLaunch()
        }
    }

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.24, blue: 0.32),
                            Color(red: 0.08, green: 0.18, blue: 0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 10) {
                Text(greeting)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))

                HStack(spacing: 10) {
                    Label("\(todayEventCount) events", systemImage: "calendar")
                    Label("\(todayTaskCount) tasks", systemImage: "checkmark.circle")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }

    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            statPill(title: NSLocalizedString("ios.dashboard.stats.due_soon", comment: "Due Soon"), value: "\(dueSoonTasks.count)", icon: "bolt")
            statPill(title: NSLocalizedString("ios.dashboard.stats.next_7_days", comment: "Next 7 Days"), value: "\(weekEventCount)", icon: "calendar.badge.clock")
            statPill(title: NSLocalizedString("ios.dashboard.stats.courses", comment: "Courses"), value: "\(coursesStore.activeCourses.count)", icon: "square.grid.2x2")
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 10) {
            ForEach(weekDays, id: \.self) { day in
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                Button {
                    selectedDate = day
                } label: {
                    VStack(spacing: 6) {
                        Text(weekdaySymbol(for: day))
                            .font(.caption2.weight(.semibold))
                        Text(dayNumber(for: day))
                            .font(.callout.weight(.semibold))
                    }
                    .frame(width: 42, height: 56)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? Color.accentColor : Color.white.opacity(0.7))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DesignSystem.Materials.hud)
        )
    }

    private var upcomingEventsCard: some View {
        RootsCard(title: NSLocalizedString("ios.dashboard.upcoming.title", comment: "Upcoming"), subtitle: NSLocalizedString("ios.dashboard.upcoming.subtitle", comment: "From your calendar"), icon: "calendar") {
            if !deviceCalendar.isAuthorized {
                Text(NSLocalizedString("dashboard.empty.calendar", comment: "Connect calendar"))
                    .rootsBodySecondary()
            } else if upcomingEvents.isEmpty {
                Text(NSLocalizedString("ios.dashboard.upcoming.no_events", comment: "No events"))
                    .rootsBodySecondary()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(upcomingEvents.prefix(4), id: \.eventIdentifier) { event in
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.accentColor.opacity(0.7))
                                .frame(width: 6)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.body.weight(.medium))
                                Text(eventTimeRange(event))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var dueTasksCard: some View {
        RootsCard(title: NSLocalizedString("ios.dashboard.due_soon.title", comment: "Due Soon"), subtitle: NSLocalizedString("ios.dashboard.due_soon.subtitle", comment: "Next 7 days"), icon: "checkmark.circle") {
            if dueSoonTasks.isEmpty {
                Text(NSLocalizedString("ios.dashboard.due_soon.no_tasks", comment: "No tasks"))
                    .rootsBodySecondary()
            } else {
                VStack(spacing: 12) {
                    ForEach(dueSoonTasks.prefix(5), id: \.id) { task in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isCompleted ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.body.weight(.medium))
                                if let course = courseName(for: task.courseId) {
                                    Text(course)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let due = task.due {
                                    Text("Due \(formattedShortDate(due))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private func statPill(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignSystem.Materials.card)
        )
    }

    private var backgroundView: some View {
        DesignSystem.Colors.appBackground
    }

    private var greeting: String {
        let todayKey = dateKey(for: Date())
        if greetingDateKey == todayKey, !storedGreeting.isEmpty {
            return storedGreeting
        }

        let hour = calendar.component(.hour, from: Date())
        let greetings: [String]

        switch hour {
        case 5..<12:
            greetings = [
                NSLocalizedString("ios.dashboard.greeting.morning.1", comment: "Good morning"),
                NSLocalizedString("ios.dashboard.greeting.morning.2", comment: "Rise and shine"),
                NSLocalizedString("ios.dashboard.greeting.morning.3", comment: "Morning"),
                NSLocalizedString("ios.dashboard.greeting.morning.4", comment: "Start strong today"),
                NSLocalizedString("ios.dashboard.greeting.morning.5", comment: "Welcome back")
            ]
        case 12..<17:
            greetings = [
                NSLocalizedString("ios.dashboard.greeting.afternoon.1", comment: "Good afternoon"),
                NSLocalizedString("ios.dashboard.greeting.afternoon.2", comment: "Afternoon"),
                NSLocalizedString("ios.dashboard.greeting.afternoon.3", comment: "Keep it up"),
                NSLocalizedString("ios.dashboard.greeting.afternoon.4", comment: "Stay focused"),
                NSLocalizedString("ios.dashboard.greeting.afternoon.5", comment: "Making progress")
            ]
        case 17..<22:
            greetings = [
                NSLocalizedString("ios.dashboard.greeting.evening.1", comment: "Good evening"),
                NSLocalizedString("ios.dashboard.greeting.evening.2", comment: "Evening"),
                NSLocalizedString("ios.dashboard.greeting.evening.3", comment: "Wrapping up"),
                NSLocalizedString("ios.dashboard.greeting.evening.4", comment: "Almost there"),
                NSLocalizedString("ios.dashboard.greeting.evening.5", comment: "Finish strong")
            ]
        default:
            greetings = [
                NSLocalizedString("ios.dashboard.greeting.night.1", comment: "Hello"),
                NSLocalizedString("ios.dashboard.greeting.night.2", comment: "Welcome back"),
                NSLocalizedString("ios.dashboard.greeting.night.3", comment: "Still working"),
                NSLocalizedString("ios.dashboard.greeting.night.4", comment: "Burning the midnight oil")
            ]
        }

        let selection = greetings.randomElement() ?? NSLocalizedString("ios.dashboard.greeting.default", comment: "Hello")
        greetingDateKey = todayKey
        storedGreeting = selection
        return selection
    }

    private func dateKey(for date: Date) -> String {
        let cutoffHour = 4
        let adjustedDate = calendar.date(byAdding: .hour, value: -cutoffHour, to: date) ?? date
        let comps = calendar.dateComponents([.year, .month, .day], from: adjustedDate)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        let day = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private var formattedDate: String {
        LocaleFormatters.fullDate.string(from: Date())
    }

    private var todayEventCount: Int {
        filteredCalendarEvents.filter { calendar.isDateInToday($0.startDate) }.count
    }

    private var todayTaskCount: Int {
        assignmentsStore.tasks.filter { task in
            guard let due = task.due else { return false }
            return calendar.isDateInToday(due) && !task.isCompleted
        }.count
    }

    private var upcomingEvents: [EKEvent] {
        let now = Date()
        return filteredCalendarEvents
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
    }

    private var weekEventCount: Int {
        let now = Date()
        let end = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        return filteredCalendarEvents.filter { $0.startDate >= now && $0.startDate <= end }.count
    }

    private var filteredCalendarEvents: [EKEvent] {
        let selectedID = settings.selectedSchoolCalendarID
        guard !selectedID.isEmpty else {
            return deviceCalendar.events
        }
        return deviceCalendar.events.filter { $0.calendar.calendarIdentifier == selectedID }
    }

    private var dueSoonTasks: [AppTask] {
        let now = Date()
        let end = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        return assignmentsStore.tasks
            .filter { !$0.isCompleted }
            .compactMap { task -> AppTask? in
                guard let due = task.due else { return nil }
                return (due >= now && due <= end) ? task : nil
            }
            .sorted { ($0.due ?? Date.distantFuture) < ($1.due ?? Date.distantFuture) }
    }

    private var weekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekInterval.start)
        }
    }

    private func weekdaySymbol(for date: Date) -> String {
        LocaleFormatters.shortDayName.string(from: date).uppercased()
    }

    private func dayNumber(for date: Date) -> String {
        LocaleFormatters.dayOfMonth.string(from: date)
    }

    private func eventTimeRange(_ event: EKEvent) -> String {
        let formatter = LocaleFormatters.shortTime
        return "\(formatter.string(from: event.startDate))-\(formatter.string(from: event.endDate))"
    }

    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func courseName(for id: UUID?) -> String? {
        guard let id else { return nil }
        if let course = coursesStore.courses.first(where: { $0.id == id }) {
            return course.code.isEmpty ? course.title : course.code
        }
        return nil
    }
}

#endif
