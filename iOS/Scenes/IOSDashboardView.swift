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

    @State private var selectedDate = Date()

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
        .background(backgroundView.ignoresSafeArea())
        .modifier(IOSNavigationChrome(title: "Dashboard") {
            Button {
                selectedDate = Date()
            } label: {
                Image(systemName: "dot.circle.and.hand.point.up.left.fill")
            }
            .accessibilityLabel("Jump to today")
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
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 160, height: 160)
                        .offset(x: 120, y: -90)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 10) {
                Text(greeting)
                    .font(.title2.weight(.semibold))
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
            statPill(title: "Due Soon", value: "\(dueSoonTasks.count)", icon: "bolt")
            statPill(title: "Next 7 Days", value: "\(weekEventCount)", icon: "calendar.badge.clock")
            statPill(title: "Courses", value: "\(coursesStore.activeCourses.count)", icon: "square.grid.2x2")
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
        RootsCard(title: "Upcoming", subtitle: "From your calendar", icon: "calendar") {
            if !deviceCalendar.isAuthorized {
                Text("Connect your calendar to see upcoming events.")
                    .rootsBodySecondary()
            } else if upcomingEvents.isEmpty {
                Text("No upcoming events.")
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
                                if let location = event.location, !location.isEmpty {
                                    Text(location)
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

    private var dueTasksCard: some View {
        RootsCard(title: "Due Soon", subtitle: "Next 7 days", icon: "checkmark.circle") {
            if dueSoonTasks.isEmpty {
                Text("No tasks due soon.")
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
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.96, blue: 0.94),
                    Color(red: 0.92, green: 0.94, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.7)

            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(x: 160, y: -220)
        }
    }

    private var greeting: String {
        let hour = calendar.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Hello"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    private var todayEventCount: Int {
        deviceCalendar.events.filter { calendar.isDateInToday($0.startDate) }.count
    }

    private var todayTaskCount: Int {
        assignmentsStore.tasks.filter { task in
            guard let due = task.due else { return false }
            return calendar.isDateInToday(due) && !task.isCompleted
        }.count
    }

    private var upcomingEvents: [EKEvent] {
        let now = Date()
        return deviceCalendar.events
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
    }

    private var weekEventCount: Int {
        let now = Date()
        let end = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        return deviceCalendar.events.filter { $0.startDate >= now && $0.startDate <= end }.count
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
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func eventTimeRange(_ event: EKEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
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
