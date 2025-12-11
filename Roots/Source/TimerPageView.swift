import SwiftUI
import Combine
import AppKit
import EventKit

// MARK: - Models

enum LocalTimerMode: String, CaseIterable, Identifiable, Codable {
    case pomodoro
    case countdown
    case stopwatch

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pomodoro: return "Pomodoro"
        case .countdown: return "Timer"
        case .stopwatch: return "Stopwatch"
        }
    }
}

enum HistoryRange: String, CaseIterable, Identifiable {
    case today, week, month, year
    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }
}

struct LocalTimerActivity: Identifiable, Hashable {
    let id: UUID
    var name: String
    var category: String
    var courseCode: String?
    var assignmentTitle: String?
    var colorTag: ColorTag
    var isPinned: Bool
    var totalTrackedSeconds: TimeInterval
    var todayTrackedSeconds: TimeInterval
}

struct LocalTimerSession: Identifiable, Codable, Hashable {
    let id: UUID
    var activityID: UUID
    var mode: LocalTimerMode
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id, activityID, mode, startDate, endDate, duration
    }
}

// MARK: - Root View

struct TimerPageView: View {
    @EnvironmentObject private var settings: AppSettingsModel
    @EnvironmentObject private var settingsCoordinator: SettingsCoordinator
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var calendarManager: CalendarManager

    @State private var mode: LocalTimerMode = .pomodoro
    @State private var activities: [LocalTimerActivity] = []
    @State private var selectedActivityID: UUID? = nil

    @State private var isRunning: Bool = false
    @State private var remainingSeconds: TimeInterval = 25 * 60
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var pomodoroSessions: Int = 4
    @State private var activeSession: LocalTimerSession? = nil
    @State private var sessions: [LocalTimerSession] = []
    @State private var activityNotes: [UUID: String] = [:]
    private let notesKeyPrefix = "timer.activity.notes."
    @State private var loadedSessions = false

    @State private var showActivityEditor: Bool = false
    @State private var editingActivity: LocalTimerActivity? = nil

    @State private var showHistoryGraph: Bool = false
    @State private var selectedRange: HistoryRange = .today

    @State private var clockString: String = TimerPageView.timeFormatter.string(from: Date())
    @State private var dateString: String = TimerPageView.dateFormatter.string(from: Date())

    @State private var searchText: String = ""
    @State private var selectedCollection: String = "All"
    @State private var focusWindowController: NSWindowController? = nil

    private let cardCorner: CGFloat = 24
    private var timerCancellable: AnyCancellable?

    var body: some View {
        ScrollView {
            ZStack {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

                VStack(spacing: 20) {
                    topBar
                    mainGrid
                    bottomSummary
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            let use24h = AppSettingsModel.shared.use24HourTime
            let df = DateFormatter()
            df.dateFormat = use24h ? "HH:mm:ss" : "h:mm:ss a"
            clockString = df.string(from: Date())
            dateString = TimerPageView.dateFormatter.string(from: Date())
            tick()
        }
        .sheet(isPresented: $showActivityEditor) {
            ActivityEditorSheet(activity: editingActivity) { updated in
                upsertActivity(updated)
            }
        }
        .onAppear {
            if !loadedSessions {
                loadSessions()
                loadedSessions = true
            }
            syncTimerWithAssignment()
        }
        .onChange(of: sessions) { _, _ in
            persistSessions()
        }
        .onChange(of: selectedActivityID) { _, _ in
            syncTimerWithAssignment()
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 16) {
            Spacer()
            // Top spacer only; time/date removed per request
            Spacer()
        }
    }

    private func activityTasks(_ activityId: UUID) -> [AppTask]? {
        guard let activity = activities.first(where: { $0.id == activityId }) else { return nil }
        let normName = activity.name.lowercased()
        let tasks = assignmentsStore.tasks.filter { task in
            guard !task.isCompleted else { return false }
            let title = task.title.lowercased()
            return normName.contains(title) || title.contains(normName)
        }
        return tasks.isEmpty ? nil : tasks
    }

    private func saveNotes(_ notes: String, for activityId: UUID) {
        let key = notesKeyPrefix + activityId.uuidString
        UserDefaults.standard.set(notes, forKey: key)
    }

    private func loadNotes(for activityId: UUID) {
        let key = notesKeyPrefix + activityId.uuidString
        if let stored = UserDefaults.standard.string(forKey: key) {
            activityNotes[activityId] = stored
        }
    }

    // MARK: Persistence

    private var sessionsURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("TimerSessions.json")
    }

    private func persistSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: sessionsURL, options: .atomic)
        } catch {
            print("Failed to persist timer sessions: \(error)")
        }
    }

    private func loadSessions() {
        do {
            let data = try Data(contentsOf: sessionsURL)
            let decoded = try JSONDecoder().decode([LocalTimerSession].self, from: data)
            sessions = decoded
        } catch {
            // OK if first run or missing file
        }
    }

    private var currentActivityPill: some View {
        HStack(spacing: DesignSystem.Layout.spacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Current Activity")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                if let activity = currentActivity {
                    Text(activity.name)
                        .font(DesignSystem.Typography.body)
                        .lineLimit(1)
                    if let code = activity.courseCode {
                        Text(code)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No activity selected")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 8)

            Button("Change") {
                // focus left list; for now open editor
                showActivityEditor = true
                editingActivity = nil
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassChrome(cornerRadius: 14)
    }

    // MARK: Main Grid

    private var mainGrid: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let isCompact = width < 1100

            if isCompact {
                VStack(spacing: 16) {
                    activitiesColumn
                    timerCoreCard
                    activityDetailPanel
                    analyticsCard
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    activitiesColumn
                        .frame(width: width * 0.30)
                    VStack(spacing: 16) {
                        timerCoreCard
                        activityDetailPanel
                    }
                    .frame(width: width * 0.38)
                    StudyAnalyticsCard(showHistory: $showHistoryGraph, selectedRange: $selectedRange, activity: currentActivity, activities: activities, sessions: sessions)
                        .frame(width: width * 0.32)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: Activities Column

    private var activitiesColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activities")
                    .font(DesignSystem.Typography.body)
                Spacer()
            }

            collectionsRow

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                    if !pinnedActivities.isEmpty {
                        Text("Pinned")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.secondary)
                        ForEach(pinnedActivities) { activity in
                            TimerActivityRow(
                                activity: activity,
                                isSelected: activity.id == selectedActivityID,
                                onSelect: { selectedActivityID = activity.id },
                                onEdit: {
                                    editingActivity = activity
                                    showActivityEditor = true
                                },
                                onPinToggle: { togglePin(activity) },
                                onReset: { resetActivity(activity) },
                                onDelete: { deleteActivity(activity) }
                            )
                        }
                    }

                    Text("All Activities")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                    ForEach(filteredActivities) { activity in
                        TimerActivityRow(
                            activity: activity,
                            isSelected: activity.id == selectedActivityID,
                            onSelect: {
                                selectedActivityID = activity.id
                                loadNotes(for: activity.id)
                            },
                            onEdit: {
                                editingActivity = activity
                                showActivityEditor = true
                            },
                            onPinToggle: { togglePin(activity) },
                            onReset: { resetActivity(activity) },
                            onDelete: { deleteActivity(activity) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            Button {
                editingActivity = nil
                showActivityEditor = true
            } label: {
                Label("New Activity", systemImage: "plus")
                    .font(DesignSystem.Typography.body)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(DesignSystem.Layout.padding.card)
        .glassCard(cornerRadius: 24)
    }

    private var collectionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Layout.spacing.small) {
                ForEach(collections, id: \.self) { collection in
                    let isSelected = selectedCollection == collection
                    Button(action: { selectedCollection = collection }) {
                        Text(collection)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var pinnedActivities: [LocalTimerActivity] {
        activities.filter { $0.isPinned }
    }

    private var filteredActivities: [LocalTimerActivity] {
        let query = searchText.lowercased()
        return activities.filter { activity in
            (!activity.isPinned) &&
            (selectedCollection == "All" || activity.category.lowercased().contains(selectedCollection.lowercased())) &&
            (query.isEmpty || activity.name.lowercased().contains(query) || activity.category.lowercased().contains(query) || (activity.courseCode?.lowercased().contains(query) ?? false))
        }
    }

    private var collections: [String] {
        var set: Set<String> = ["All"]
        set.formUnion(activities.map { $0.category })
        return Array(set).sorted()
    }

    private func openFocusWindow() {
        let selectedActivity = currentActivity
        let notesBinding: Binding<String> = Binding(
            get: { selectedActivity.flatMap { activityNotes[$0.id] } ?? "" },
            set: { newValue in
                if let id = selectedActivity?.id {
                    activityNotes[id] = newValue
                    saveNotes(newValue, for: id)
                }
            }
        )

        let tasksLeft = assignmentsStore.tasks.filter { task in
            guard let due = task.due else { return false }
            let cal = Calendar.current
            return !task.isCompleted && cal.isDateInToday(due)
        }.count

        let nextEvent: EKEvent? = {
            let selectedId = calendarManager.selectedCalendarID
            let events = calendarManager.cachedMonthEvents.filter {
                selectedId.isEmpty || $0.calendar.calendarIdentifier == selectedId
            }
            let todayEvents = events.filter { Calendar.current.isDateInToday($0.startDate) && $0.startDate > Date() }
            return todayEvents.sorted(by: { $0.startDate < $1.startDate }).first
        }()

        let focusView = FocusWindowView(
            mode: mode,
            timerText: TimerCoreCard.timeDisplayStatic(mode: mode, remainingSeconds: remainingSeconds, elapsedSeconds: elapsedSeconds),
            clockString: clockString,
            activityName: selectedActivity?.name,
            activityNotes: notesBinding,
            tasksLeftToday: tasksLeft,
            nextEventTitle: nextEvent?.title,
            nextEventTime: nextEvent?.startDate,
            activityCourse: selectedActivity?.courseCode
        )
        let hosting = NSHostingController(rootView: focusView)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 640, height: 480))
        window.center()
        window.title = "Focus"
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        focusWindowController = NSWindowController(window: window)
    }

    // MARK: Timer Core Card

    private var timerCoreCard: some View {
        TimerCoreCard(
            mode: $mode,
            isRunning: $isRunning,
            remainingSeconds: $remainingSeconds,
            elapsedSeconds: $elapsedSeconds,
            pomodoroSessions: pomodoroSessions,
            onStart: startTimer,
            onPause: pauseTimer,
            onReset: resetTimer,
            onSkip: completeCurrentBlock,
            onOpenFocus: openFocusWindow
        )
        .padding(DesignSystem.Layout.padding.card)
        .glassCard(cornerRadius: 24)
    }

    // MARK: Analytics Card

    private var analyticsCard: some View {
        StudyAnalyticsCard(
            showHistory: $showHistoryGraph,
            selectedRange: $selectedRange,
            activity: currentActivity,
            activities: activities,
            sessions: sessions
        )
        .padding(DesignSystem.Layout.padding.card)
        .glassCard(cornerRadius: 24)
    }

    private var activityDetailPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            currentActivityPill
                .frame(maxWidth: .infinity, alignment: .leading)

            if let activity = currentActivity {
                if let tasks = activityTasks(activity.id), !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tasks for this Activity")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                        ForEach(tasks, id: \.id) { task in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                        .font(DesignSystem.Typography.body)
                                    if let due = task.due {
                                        Text(due, style: .date)
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if task.isCompleted {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                }
                            }
                            .padding(8)
                            .background(DesignSystem.Materials.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: Binding(
                        get: { activityNotes[activity.id] ?? "" },
                        set: { newValue in
                            activityNotes[activity.id] = newValue
                            saveNotes(newValue, for: activity.id)
                        })
                    )
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(DesignSystem.Materials.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            } else {
                Text("Select an activity to view details.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .glassCard(cornerRadius: 24)
    }

    // MARK: Bottom Summary

    private var bottomSummary: some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                Text("Today: \(formattedDuration(totalToday))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let activity = currentActivity {
                Text("Selected: \(activity.name) • \(formattedDuration(activity.todayTrackedSeconds)) today")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Helpers

    private var totalToday: TimeInterval {
        activities.reduce(0) { $0 + $1.todayTrackedSeconds }
    }

    private var currentActivity: LocalTimerActivity? {
        activities.first(where: { $0.id == selectedActivityID }) ?? activities.first
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func togglePin(_ activity: LocalTimerActivity) {
        guard let idx = activities.firstIndex(of: activity) else { return }
        activities[idx].isPinned.toggle()
    }

    private func resetActivity(_ activity: LocalTimerActivity) {
        guard let idx = activities.firstIndex(of: activity) else { return }
        activities[idx].todayTrackedSeconds = 0
        activities[idx].totalTrackedSeconds = 0
    }

    private func deleteActivity(_ activity: LocalTimerActivity) {
        activities.removeAll { $0.id == activity.id }
        if selectedActivityID == activity.id { selectedActivityID = activities.first?.id }
    }

    private func upsertActivity(_ activity: LocalTimerActivity) {
        if let idx = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[idx] = activity
        } else {
            activities.append(activity)
        }
        selectedActivityID = activity.id
    }

    // MARK: Timer Logic Skeleton

    private func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        if activeSession == nil, let activity = currentActivity {
            activeSession = LocalTimerSession(id: UUID(), activityID: activity.id, mode: mode, startDate: Date(), endDate: nil, duration: 0)
        }
    }

    private func pauseTimer() {
        isRunning = false
    }

    private func resetTimer() {
        isRunning = false
        elapsedSeconds = 0
        remainingSeconds = 25 * 60
    }

    private func assignmentForCurrentActivity() -> AppTask? {
        guard let activity = currentActivity, let tasks = activityTasks(activity.id) else { return nil }
        return tasks.first
    }

    private func syncTimerWithAssignment() {
        guard !isRunning, let task = assignmentForCurrentActivity() else { return }
        remainingSeconds = TimeInterval(max(1, task.estimatedMinutes) * 60)
        if mode == .pomodoro {
            pomodoroSessions = max(1, Int(ceil(Double(task.estimatedMinutes) / 25.0)))
        }
    }

    private func tick() {
        guard isRunning else { return }

        switch mode {
        case .pomodoro, .countdown:
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                completeCurrentBlock()
            }
        case .stopwatch:
            elapsedSeconds += 1
        }
    }

    private func completeCurrentBlock() {
        isRunning = false
        let duration: TimeInterval
        switch mode {
        case .stopwatch:
            duration = elapsedSeconds
            elapsedSeconds = 0
        case .pomodoro, .countdown:
            duration = 25 * 60 - remainingSeconds
            remainingSeconds = 25 * 60
        }

        if var session = activeSession {
            session.endDate = Date()
            session.duration = duration
            logSession(session)
            // store session for analytics
            sessions.append(session)
        }
        activeSession = nil
    }

    private func logSession(_ session: LocalTimerSession) {
        guard let idx = activities.firstIndex(where: { $0.id == session.activityID }) else { return }
        activities[idx].todayTrackedSeconds += session.duration
        activities[idx].totalTrackedSeconds += session.duration
    }

    // MARK: Static formatters

    static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }()

    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }()
}

// MARK: - Activity Row

struct TimerActivityRow: View {
    var activity: LocalTimerActivity
    var isSelected: Bool
    var onSelect: () -> Void
    var onEdit: () -> Void
    var onPinToggle: () -> Void
    var onReset: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(activity.colorTag.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(DesignSystem.Typography.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(activity.category)
                    if let code = activity.courseCode { Text("· \(code)") }
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

                Text("Today \(timeString(activity.todayTrackedSeconds)) · Total \(timeString(activity.totalTrackedSeconds))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Menu {
                Button(activity.isPinned ? "Unpin" : "Pin", action: onPinToggle)
                Button("Edit", action: onEdit)
                Button("Reset totals", action: onReset)
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                .fill(isSelected ? Color(nsColor: .controlAccentColor).opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .onTapGesture { onSelect() }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 { return "\(hours)h \(mins)m" } else { return "\(mins)m" }
    }
}

// MARK: - Timer Core Card

struct TimerCoreCard: View {
    @EnvironmentObject private var settingsCoordinator: SettingsCoordinator

    @Binding var mode: LocalTimerMode
    @Binding var isRunning: Bool
    @Binding var remainingSeconds: TimeInterval
    @Binding var elapsedSeconds: TimeInterval
    var pomodoroSessions: Int

    var onStart: () -> Void
    var onPause: () -> Void
    var onReset: () -> Void
    var onSkip: () -> Void
    var onOpenFocus: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if isRunning {
                FocusSessionView(
                    mode: mode,
                    timeText: timeDisplay,
                    onPause: onPause,
                    onStop: onReset
                )
            } else {
                TimerSetupView(
                    mode: $mode,
                    timeText: timeDisplay,
                    onStart: onStart,
                    onOpenFocus: onOpenFocus,
                    onReset: onReset,
                    settingsCoordinator: settingsCoordinator
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var timeDisplay: String {
        switch mode {
        case .stopwatch:
            let h = Int(elapsedSeconds) / 3600
            let m = (Int(elapsedSeconds) % 3600) / 60
            let s = Int(elapsedSeconds) % 60
            if h > 0 {
                return String(format: "%02d:%02d:%02d", h, m, s)
            } else {
                return String(format: "%02d:%02d", m, s)
            }
        case .pomodoro, .countdown:
            let m = Int(remainingSeconds) / 60
            let s = Int(remainingSeconds) % 60
            return String(format: "%02d:%02d", m, s)
        }
    }

    // Static helper for focus window
    static func timeDisplayStatic(mode: LocalTimerMode, remainingSeconds: TimeInterval, elapsedSeconds: TimeInterval) -> String {
        switch mode {
        case .stopwatch:
            let h = Int(elapsedSeconds) / 3600
            let m = (Int(elapsedSeconds) % 3600) / 60
            let s = Int(elapsedSeconds) % 60
            if h > 0 {
                return String(format: "%02d:%02d:%02d", h, m, s)
            } else {
                return String(format: "%02d:%02d", m, s)
            }
        case .pomodoro, .countdown:
            let m = Int(remainingSeconds) / 60
            let s = Int(remainingSeconds) % 60
            return String(format: "%02d:%02d", m, s)
        }
    }
}

// Minimal setup card: time + start + mode menu.
private struct TimerSetupView: View {
    @Binding var mode: LocalTimerMode
    var timeText: String
    var onStart: () -> Void
    var onOpenFocus: () -> Void
    var onReset: () -> Void
    var settingsCoordinator: SettingsCoordinator

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            HStack {
                Menu {
                    ForEach(LocalTimerMode.allCases) { m in
                        Button {
                            mode = m
                        } label: {
                            HStack {
                                if mode == m {
                                    Image(systemName: "checkmark")
                                }
                                Text(m.label)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "speedometer")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .menuStyle(.borderlessButton)
            }

            Text(timeText)
                .font(.system(size: 60, weight: .light, design: .monospaced))
                .monospacedDigit()
                .padding(.vertical, 12)

            Button("Start Focus", action: onStart)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
        }
    }
}

// Active session view with analog clock + icon controls.
private struct FocusSessionView: View {
    var mode: LocalTimerMode
    var timeText: String
    var onPause: () -> Void
    var onStop: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            RootsAnalogClock(diameter: 280, showSecondHand: true)

            Text(timeText)
                .font(.system(size: 60, weight: .light, design: .monospaced))
                .monospacedDigit()

            HStack(spacing: 18) {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                }
                .buttonStyle(.bordered)

                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
            }

            Text(mode.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(0.35)
        }
    }
}

// MARK: - Analytics Card

struct StudyAnalyticsCard: View {
    @Binding var showHistory: Bool
    @Binding var selectedRange: HistoryRange
    var activity: LocalTimerActivity?
    var activities: [LocalTimerActivity]
    var sessions: [LocalTimerSession]

    // category color helper local to the analytics card
    private func categoryColorMap() -> [String: Color] {
        var map: [String: Color] = [:]
        for a in activities { map[a.category] = a.colorTag.color }
        return map
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            stackedTodayView
            stackedWeekView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stackedTodayView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
            if #available(macOS 13.0, *), (true) {
                // Build hour buckets and stack
                let buckets: [AnalyticsBucket] = { StudyAnalyticsAggregator.bucketsForToday() }()
                let aggregated = StudyAnalyticsAggregator.aggregate(sessions: sessions, activities: activities, into: buckets)
                ChartViewVerticalStacked(buckets: aggregated, categoryColors: categoryColorMap(), showLabels: false)
                    .frame(height: 200)
            } else {
                // fallback simple horizontal
                GeometryReader { proxy in
                    let segments = segmentsForToday()
                    HStack(spacing: 0) {
                        ForEach(segments.indices, id: \.self) { idx in
                            let seg = segments[idx]
                            Rectangle()
                                .fill(seg.color)
                                .frame(width: proxy.size.width * CGFloat(seg.frac))
                        }
                    }
                }
                .frame(height: 28)
            }
        }
    }

    private var stackedWeekView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
            if #available(macOS 13.0, *), (true) {
                let buckets: [AnalyticsBucket] = {
                    switch selectedRange {
                    case .today: return StudyAnalyticsAggregator.bucketsForToday()
                    case .week: return StudyAnalyticsAggregator.bucketsForWeek()
                    case .month: return StudyAnalyticsAggregator.bucketsForMonth()
                    case .year: return StudyAnalyticsAggregator.bucketsForYear()
                    }
                }()
                let aggregated = StudyAnalyticsAggregator.aggregate(sessions: sessions, activities: activities, into: buckets)
                ChartViewVerticalStacked(buckets: aggregated, categoryColors: categoryColorMap(), showLabels: false)
                    .frame(height: 200)
            } else {
                GeometryReader { proxy in
                    let segments = segmentsForWeek()
                    HStack(spacing: 0) {
                        ForEach(segments.indices, id: \.self) { idx in
                            let seg = segments[idx]
                            Rectangle()
                                .fill(seg.color)
                                .frame(width: proxy.size.width * CGFloat(seg.frac))
                        }
                    }
                }
                .frame(height: 28)
            }
        }
    }

    private func segmentsForToday() -> [(label: String, color: Color, frac: Double)] {
        let grouped = Dictionary(grouping: activities) { $0.category }
        let total = max(1, activities.reduce(0) { $0 + $1.todayTrackedSeconds })
        return grouped.map { (k, v) in
            let secs = v.reduce(0) { $0 + $1.todayTrackedSeconds }
            return (label: k, color: v.first?.colorTag.color ?? .gray, frac: secs / total)
        }
    }

    private func segmentsForWeek() -> [(label: String, color: Color, frac: Double)] {
        // Simple placeholder: reuse today proportions
        let segs = segmentsForToday()
        return segs
    }
}

// MARK: - Focus Window

private struct FocusWindowView: View {
    let mode: LocalTimerMode
    let timerText: String
    let clockString: String
    let activityName: String?
    let activityNotes: Binding<String>
    let tasksLeftToday: Int
    let nextEventTitle: String?
    let nextEventTime: Date?
    let activityCourse: String?

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tasks Left Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(tasksLeftToday)")
                        .font(.title2.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next Event")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let title = nextEventTitle, let time = nextEventTime {
                        Text(title)
                            .font(.headline)
                        Text(time, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("None")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(spacing: 8) {
                Text(mode.label)
                    .font(.title.weight(.semibold))
                Text(timerText)
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activityName ?? "No Activity")
                        .font(.headline)
                    if let course = activityCourse {
                        Text(course)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: activityNotes)
                        .frame(minHeight: 80, maxHeight: 140)
                        .padding(8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Current Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(clockString)
                        .font(.title3.monospacedDigit())
                }
                .frame(alignment: .trailing)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 400)
    }
}

// MARK: - Activity Editor Sheet

struct ActivityEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    var activity: LocalTimerActivity?
    var onSave: (LocalTimerActivity) -> Void

    @State private var name: String = ""
    @State private var category: String = "Studying"
    @State private var course: String = ""
    @State private var assignment: String = ""
    @State private var colorTag: ColorTag = .blue
    @State private var isPinned: Bool = false
    @State private var totalTracked: TimeInterval = 0

    private var isNew: Bool { activity == nil }
    private var isSaveDisabled: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        RootsPopupContainer(
            title: isNew ? "New Activity" : "Edit Activity",
            subtitle: "Activities connect to Planner and Assignments."
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: RootsSpacing.l) {
                    activitySection
                    detailsSection
                }
            }
        } footer: {
            footerBar
        }
        .frame(maxWidth: 580, maxHeight: 460)
        .frame(minWidth: RootsWindowSizing.minPopupWidth, minHeight: RootsWindowSizing.minPopupHeight)
        .onAppear(perform: loadDraft)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            Text("Activity").rootsSectionHeader()
            RootsFormRow(label: "Name") {
                TextField("Activity name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            .validationHint(isInvalid: name.trimmingCharacters(in: .whitespaces).isEmpty, text: "Name is required.")

            RootsFormRow(label: "Category") {
                TextField("e.g. Studying", text: $category)
                    .textFieldStyle(.roundedBorder)
            }

            RootsFormRow(label: "Course") {
                TextField("Course code (optional)", text: $course)
                    .textFieldStyle(.roundedBorder)
            }

            RootsFormRow(label: "Assignment") {
                TextField("Assignment link (optional)", text: $assignment)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            Text("Details").rootsSectionHeader()
            RootsFormRow(label: "Color") {
                ColorTagPicker(selected: $colorTag)
            }
            RootsFormRow(label: "Pin to top") {
                Toggle("", isOn: $isPinned).labelsHidden()
            }
            RootsFormRow(label: "Total time") {
                Text(timeString(totalTracked))
                    .rootsBodySecondary()
            }
        }
    }

    private var footerBar: some View {
        HStack {
            Text("You can edit activities later from the Timer page.")
                .rootsCaption()
            Spacer()
            Button("Cancel") { dismiss() }
            Button(isNew ? "Create" : "Save") {
                let new = LocalTimerActivity(
                    id: activity?.id ?? UUID(),
                    name: name,
                    category: category,
                    courseCode: course.isEmpty ? nil : course,
                    assignmentTitle: assignment.isEmpty ? nil : assignment,
                    colorTag: colorTag,
                    isPinned: isPinned,
                    totalTrackedSeconds: totalTracked,
                    todayTrackedSeconds: activity?.todayTrackedSeconds ?? 0
                )
                onSave(new)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isSaveDisabled)
        }
    }

    private func loadDraft() {
        if let activity {
            name = activity.name
            category = activity.category
            course = activity.courseCode ?? ""
            assignment = activity.assignmentTitle ?? ""
            colorTag = activity.colorTag
            isPinned = activity.isPinned
            totalTracked = activity.totalTrackedSeconds
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 { return "\(hours)h \(mins)m" } else { return "\(mins)m" }
    }
}

private extension View {
    func validationHint(isInvalid: Bool, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            self
            if isInvalid {
                Text(text)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Samples

private extension TimerPageView {
    static var sampleActivities: [LocalTimerActivity] { [] }
}
