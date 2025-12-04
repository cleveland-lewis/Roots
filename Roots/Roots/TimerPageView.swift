import SwiftUI
import Combine

// MARK: - Models

enum LocalTimerMode: String, CaseIterable, Identifiable {
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

struct LocalTimerSession: Identifiable {
    let id: UUID
    var activityID: UUID
    var mode: LocalTimerMode
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval
}

// MARK: - Root View

struct TimerPageView: View {
    @EnvironmentObject private var settings: AppSettingsModel
    @EnvironmentObject private var settingsCoordinator: SettingsCoordinator

    @State private var mode: LocalTimerMode = .pomodoro
    @State private var activities: [LocalTimerActivity] = TimerPageView.sampleActivities
    @State private var selectedActivityID: UUID? = nil

    @State private var isRunning: Bool = false
    @State private var remainingSeconds: TimeInterval = 25 * 60
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var activeSession: LocalTimerSession? = nil
    @State private var sessions: [LocalTimerSession] = []

    @State private var showActivityEditor: Bool = false
    @State private var editingActivity: LocalTimerActivity? = nil

    @State private var showHistoryGraph: Bool = false
    @State private var selectedRange: HistoryRange = .today

    @State private var clockString: String = TimerPageView.timeFormatter.string(from: Date())
    @State private var dateString: String = TimerPageView.dateFormatter.string(from: Date())

    @State private var searchText: String = ""
    @State private var selectedCollection: String = "All"

    private let cardCorner: CGFloat = 24
    private var timerCancellable: AnyCancellable?

    var body: some View {
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
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 16) {
            Picker("Mode", selection: $mode.animation(.spring(response: 0.3, dampingFraction: 0.85))) {
                ForEach(LocalTimerMode.allCases) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            // Make clock occupy flexible center space so Current Activity stays right-aligned
            VStack(spacing: 2) {
                Text(clockString)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(dateString)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            currentActivityPill
                .frame(width: 320, alignment: .trailing)
        }
    }

    private var currentActivityPill: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Current Activity")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                if let activity = currentActivity {
                    Text(activity.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    if let code = activity.courseCode {
                        Text(code)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No activity selected")
                        .font(.system(size: 14, weight: .semibold))
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
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        )
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
                    analyticsCard
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    activitiesColumn
                        .frame(width: width * 0.30)
                    timerCoreCard
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
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }

            collectionsRow

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !pinnedActivities.isEmpty {
                        Text("Pinned")
                            .font(.caption)
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
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(filteredActivities) { activity in
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
                .padding(.vertical, 4)
            }

            Button {
                editingActivity = nil
                showActivityEditor = true
            } label: {
                Label("New Activity", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(16)
        .background(glassyCardBackground)
        .overlay(glassyCardStroke)
    }

    private var collectionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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

    private var glassyCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(RootsColor.glassBorder, lineWidth: 1)
            )
    }

    private var glassyCardStroke: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(RootsColor.glassBorder, lineWidth: 1)
    }

    // MARK: Timer Core Card

    private var timerCoreCard: some View {
        TimerCoreCard(
            mode: $mode,
            isRunning: $isRunning,
            remainingSeconds: $remainingSeconds,
            elapsedSeconds: $elapsedSeconds,
            onStart: startTimer,
            onPause: pauseTimer,
            onReset: resetTimer,
            onSkip: completeCurrentBlock
        )
        .padding(16)
        .background(glassyCardBackground)
        .overlay(glassyCardStroke)
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
        .padding(16)
        .background(glassyCardBackground)
        .overlay(glassyCardStroke)
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
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(activity.category)
                    if let code = activity.courseCode { Text("· \(code)") }
                }
                .font(.caption)
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
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color(nsColor: .controlAccentColor).opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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

    var onStart: () -> Void
    var onPause: () -> Void
    var onReset: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("\(mode.label)")
                .font(.system(size: 14, weight: .semibold))

            Text(timeDisplay)
                .font(.system(size: 58, weight: .semibold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 12) {
                Button(isRunning ? "Pause" : "Start") {
                    isRunning ? onPause() : onStart()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Reset", action: onReset)
                    .buttonStyle(.bordered)

                if mode == .pomodoro {
                    Button("Skip", action: onSkip)
                        .buttonStyle(.bordered)
                }
            }

            HStack(alignment: .center) {
                Text(infoLine)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Edit") {
                    // open settings and request Timer pane selection
                    settingsCoordinator.show(selecting: "timer")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
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

    private var infoLine: String {
        switch mode {
        case .pomodoro:
            return "Focus 25m · Break 5m · Session 1 of 4"
        case .countdown:
            return "Countdown in progress"
        case .stopwatch:
            return "Tracking elapsed time"
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

    @State private var expandedSection: String? = nil

    // category color helper local to the analytics card
    private func categoryColorMap() -> [String: Color] {
        var map: [String: Color] = [:]
        for a in activities { map[a.category] = a.colorTag.color }
        return map
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Time Studying")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Picker("Mode", selection: $showHistory) {
                    Text("Live").tag(false)
                    Text("History").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }

            summaryView

            Divider()

            stackedTodayView

            Divider()

            stackedWeekView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    let completed = Int(totalToday / 60)
                    let target = 120 // minutes target placeholder
                    let remaining = max(0, target - completed)
                    Text("Completed: \(completed/60)h \(completed%60)m • Remaining: \(remaining/60)h \(remaining%60)m")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    GeometryReader { proxy in
                        let progress = min(max(totalToday / Double(target*60), 0), 1)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.12))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                                .frame(width: proxy.size.width * progress)
                        }
                    }
                    .frame(height: 10)
                }
                Spacer()
                Button(action: { expandedSection = "summary" }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var stackedTodayView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today by Category")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: { expandedSection = "today" }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                }
                .buttonStyle(.plain)
            }

            if #available(macOS 13.0, *), (true) {
                // Build hour buckets and stack
                let buckets: [AnalyticsBucket] = { StudyAnalyticsAggregator.bucketsForToday() }()
                let aggregated = StudyAnalyticsAggregator.aggregate(sessions: sessions, activities: activities, into: buckets)
                ChartViewVerticalStacked(buckets: aggregated, categoryColors: categoryColorMap())
                    .frame(height: expandedSection == "today" ? 280 : 160)
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
                                .overlay(Text(seg.label).font(.caption2).foregroundColor(.white).padding(4), alignment: .center)
                        }
                    }
                }
                .frame(height: 28)
            }
        }
    }

    private var stackedWeekView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("This Week by Category")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: { expandedSection = "week" }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                }
                .buttonStyle(.plain)
            }

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
                ChartViewVerticalStacked(buckets: aggregated, categoryColors: categoryColorMap())
                    .frame(height: expandedSection == "week" ? 320 : 160)
            } else {
                GeometryReader { proxy in
                    let segments = segmentsForWeek()
                    HStack(spacing: 0) {
                        ForEach(segments.indices, id: \.self) { idx in
                            let seg = segments[idx]
                            Rectangle()
                                .fill(seg.color)
                                .frame(width: proxy.size.width * CGFloat(seg.frac))
                                .overlay(Text(seg.label).font(.caption2).foregroundColor(.white).padding(4), alignment: .center)
                        }
                    }
                }
                .frame(height: 28)
            }
        }
    }

    private var totalToday: Double {
        activities.reduce(0) { $0 + $1.todayTrackedSeconds }
    }

    private func segmentsForToday() -> [(label: String, color: Color, frac: Double)] {
        let grouped = Dictionary(grouping: activities) { $0.category }
        let total = max(1, totalToday)
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
    static var sampleActivities: [LocalTimerActivity] {
        [
            LocalTimerActivity(id: UUID(), name: "MA 231 – Problem Set 5", category: "Studying", courseCode: "MA 231", assignmentTitle: "Problem Set 5", colorTag: .blue, isPinned: true, totalTrackedSeconds: 60*60*5, todayTrackedSeconds: 60*42),
            LocalTimerActivity(id: UUID(), name: "CS 240 – Project", category: "Coding", courseCode: "CS 240", assignmentTitle: nil, colorTag: .purple, isPinned: false, totalTrackedSeconds: 60*60*12, todayTrackedSeconds: 60*30),
            LocalTimerActivity(id: UUID(), name: "Writing – Essay", category: "Writing", courseCode: nil, assignmentTitle: nil, colorTag: .orange, isPinned: false, totalTrackedSeconds: 60*60*3, todayTrackedSeconds: 60*25)
        ]
    }
}
