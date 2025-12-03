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
    @State private var events: [DashboardEvent] = [
        .init(title: "MA 231 Lecture", time: "9:00–9:50 AM", location: "Biltmore 204"),
        .init(title: "GN 311 Lab", time: "2:30–4:20 PM", location: "Jordan 112"),
        .init(title: "Study Block – Library", time: "7:00–9:00 PM", location: "DHH Hill")
    ]

    // Icons and text are now fixed for the dashboard homepage
    private var showIcons: Bool { true }
    private var showText: Bool { true }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.96).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    GlassCircleButton(systemName: "plus") { /* add */ }
                    Spacer()
                    Text("Dashboard")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    GlassCircleButton(systemName: "gearshape") { /* settings */ }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // ROW 1
                HStack(alignment: .top, spacing: 20) {
                    todayCard
                    energyCard
                    deadlinesCard
                }
                .frame(height: 200)
                .padding(.horizontal, 24)

                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.horizontal, 24)

                // ROW 2
                HStack(alignment: .top, spacing: 20) {
                    DashboardCalendarColumn(selectedDate: $selectedDate)
                    DashboardTasksColumn(tasks: $tasks)
                    DashboardEventsColumn(events: events)
                }
                .frame(height: 260)
                .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }

            GlassTabBar(selected: $selectedTab)
                .padding(.bottom, 20)
        }
        .onAppear { LOG_UI(.info, "Navigation", "Displayed DashboardView") }
    }

    private var headerControls: some View {
        HStack(spacing: 12) {
            Text("Dashboard")
                .font(settings.font(for: .headline))
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private var todayCard: some View {
        AppCard(
            title: cardTitle("Today Overview"),
            icon: cardIcon("sun.max"),
            iconBounceTrigger: todayBounce
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
        AppCard(
            title: cardTitle("Energy & Focus"),
            icon: cardIcon("heart.fill"),
            iconBounceTrigger: energyBounce
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
    }

    private var insightsCard: some View {
        AppCard(
            title: cardTitle("Insights"),
            icon: cardIcon("lightbulb.fill"),
            iconBounceTrigger: insightsBounce
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .font(settings.font(for: .body))
            }
        }
        .onTapGesture {
            insightsBounce.toggle()
            print("[Dashboard] card tapped: insights")
        }
        .help("Insights")
    }

    private var deadlinesCard: some View {
        AppCard(
            title: cardTitle("Upcoming Deadlines"),
            icon: cardIcon("clock.arrow.circlepath"),
            iconBounceTrigger: deadlinesBounce
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

    private func cardTitle(_ title: String) -> String? {
        showText ? title : nil
    }

    private func cardIcon(_ name: String) -> Image? {
        showIcons ? Image(systemName: name) : nil
    }
}

struct DashboardTileBody: View {
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.0)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(row.1)
                        .font(.headline)
                        .foregroundStyle(.primary)
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
}

// MARK: - Columns

private struct DashboardCalendarColumn: View {
    @Binding var selectedDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendar")
                .font(.headline)
            Text(shortHeader(for: selectedDate))
                .font(.subheadline)
                .foregroundColor(.secondary)
            DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .tint(.accentColor)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func shortHeader(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

private struct DashboardTasksColumn: View {
    @Binding var tasks: [DashboardTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today’s Tasks")
                .font(.headline)

            if tasks.isEmpty {
                Text("No tasks scheduled.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct DashboardEventsColumn: View {
    var events: [DashboardEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Events")
                .font(.headline)

            if events.isEmpty {
                Text("No upcoming events.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(events) { event in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(event.time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let location = event.location {
                                        Text(location)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
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
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(task.isDone, color: .secondary)

                if let course = task.course {
                    Text(course)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
