#if os(macOS)
import SwiftUI
import Combine
import AppKit
import EventKit

// MARK: - Models

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

enum TimerDisplayStyle: String, CaseIterable, Identifiable {
    case digital
    case analog

    var id: String { rawValue }

    var label: String {
        switch self {
        case .digital:
            return NSLocalizedString("timer.display.digital", comment: "")
        case .analog:
            return NSLocalizedString("timer.display.analog", comment: "")
        }
    }
}

// MARK: - Root View

struct TimerPageView: View {
    @EnvironmentObject private var settings: AppSettingsModel
    @EnvironmentObject private var settingsCoordinator: SettingsCoordinator
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var calendarManager: CalendarManager
    @EnvironmentObject private var calendarRefresh: CalendarRefreshCoordinator
    @EnvironmentObject private var appModel: AppModel

    @State private var mode: LocalTimerMode = .pomodoro
    @State private var activities: [LocalTimerActivity] = []
    @State private var selectedActivityID: UUID? = nil

    @State private var isRunning: Bool = false
    @State private var remainingSeconds: TimeInterval = 0
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var pomodoroSessions: Int = 4
    @State private var completedPomodoroSessions: Int = 0
    @State private var isPomodorBreak: Bool = false
    @State private var activeSession: LocalTimerSession? = nil
    @State private var sessions: [LocalTimerSession] = []
    @State private var activityNotes: [UUID: String] = [:]
    private let notesKeyPrefix = "timer.activity.notes."
    @State private var loadedSessions = false

    @State private var showActivityEditor: Bool = false
    @State private var editingActivity: LocalTimerActivity? = nil

    @State private var showHistoryGraph: Bool = false
    @State private var selectedRange: HistoryRange = .today

    @State private var searchText: String = ""
    @State private var selectedCollection: String = "All"
    @State private var focusWindowController: NSWindowController? = nil
    @State private var focusWindowDelegate: FocusWindowDelegate? = nil
    @FocusState private var isSearchFocused: Bool
    @AppStorage("timer.display.style") private var displayStyleRaw: String = TimerDisplayStyle.digital.rawValue

    private let cardCorner: CGFloat = 24
    @State private var timerCancellable: AnyCancellable?
    @State private var notificationObservers: [NSObjectProtocol] = []
    @State private var tickCancellable: AnyCancellable?
    private let maxSessionHistoryDays = 400
    private let maxSessionCount = 20000
    private static let refreshDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var displayStyle: TimerDisplayStyle {
        get { TimerDisplayStyle(rawValue: displayStyleRaw) ?? .digital }
        set { displayStyleRaw = newValue.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar region
            VStack(spacing: 20) {
                topBar
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            
            // Main content region (fills available space)
            mainGrid
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .frame(maxHeight: .infinity, alignment: .top)
            
            // Bottom dock/summary region
            VStack(spacing: 0) {
                bottomSummary
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .timerContextMenu(
            isRunning: $isRunning,
            onStart: startTimer,
            onStop: pauseTimer,
            onEnd: endTimerSession
        )
        .sheet(isPresented: $showActivityEditor) {
            ActivityEditorSheet(activity: editingActivity) { updated in
                upsertActivity(updated)
            }
        }
        .onAppear {
            print("[TimerPageView] onAppear START")
            
            // Start the tick timer
            startTickTimer()
            
            updateCachedValues()  // Cache computed values to avoid repeated filtering
            pomodoroSessions = settings.pomodoroIterations
            // Initialize timer duration from settings
            if remainingSeconds == 0 {
                remainingSeconds = TimeInterval(settings.pomodoroFocusMinutes * 60)
            }
            print("[TimerPageView] setupTimerNotificationObservers START")
            setupTimerNotificationObservers()
            print("[TimerPageView] setupTimerNotificationObservers END")
            if !loadedSessions {
                print("[TimerPageView] loadSessions START")
                loadSessions()
                loadedSessions = true
                print("[TimerPageView] loadSessions END")
            }
            print("[TimerPageView] syncTimerWithAssignment START")
            syncTimerWithAssignment()
            print("[TimerPageView] syncTimerWithAssignment END")
            print("[TimerPageView] onAppear END")
        }
        .onChange(of: activities) { updateCachedValues() }
        .onChange(of: searchText) { updateCachedValues() }
        .onChange(of: selectedCollection) { updateCachedValues() }
        .onDisappear {
            // Stop the tick timer
            stopTickTimer()
            
            // Clean up notification observers to prevent dangling references
            notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
            notificationObservers.removeAll()
            
            // Cancel any active timer
            timerCancellable?.cancel()
            timerCancellable = nil
        }
        .onChange(of: sessions) { _, _ in
            persistSessions()
        }
        .onChange(of: selectedActivityID) { _, _ in
            syncTimerWithAssignment()
        }
        .onChange(of: settings.pomodoroIterations) { _, newValue in
            pomodoroSessions = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            isSearchFocused = true
        }
        .onKeyPress(.space) {
            guard !isSearchFocused, !showActivityEditor else { return .ignored }
            if isRunning {
                pauseTimer()
            } else {
                startTimer()
            }
            return .handled
        }
        .alert(item: $calendarRefresh.error) { error in
            switch error {
            case .permissionDenied:
                return Alert(
                    title: Text(NSLocalizedString("calendar.refresh.failed", comment: "")),
                    message: Text(error.localizedDescription),
                    primaryButton: .default(Text(NSLocalizedString("calendar.refresh.open_settings", comment: ""))) {
                        calendarManager.openCalendarPrivacySettings()
                    },
                    secondaryButton: .cancel(Text(NSLocalizedString("common.button.cancel", comment: "")))
                )
            case .schedulingFailed:
                return Alert(
                    title: Text(NSLocalizedString("calendar.refresh.failed", comment: "")),
                    message: Text(error.localizedDescription),
                    dismissButton: .default(Text(NSLocalizedString("common.button.ok", comment: "")))
                )
            }
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 16) {
            Spacer()
            calendarRefreshStatus
            Spacer()
        }
    }

    private var calendarRefreshStatus: some View {
        let text: String = {
            if calendarRefresh.isRefreshing {
                return NSLocalizedString("calendar.refresh.in_progress", comment: "")
            }
            guard let last = calendarRefresh.lastRefreshedAt else {
                return NSLocalizedString("calendar.refresh.last.never", comment: "")
            }
            let formatted = Self.refreshDateFormatter.string(from: last)
            return String(format: NSLocalizedString("calendar.refresh.last", comment: ""), formatted)
        }()

        return HStack(spacing: 8) {
            if calendarRefresh.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
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
        let snapshot = sessions
        let url = sessionsURL
        DispatchQueue.global(qos: .utility).async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                print("Failed to persist timer sessions: \(error)")
            }
        }
    }

    private func loadSessions() {
        let url = sessionsURL
        let maxDays = maxSessionHistoryDays
        let maxCount = maxSessionCount
        
        Task {
            // Perform heavy I/O and processing on background thread
            let finalSessions = await Task.detached(priority: .userInitiated) { () -> [LocalTimerSession] in
                let loadedData: [LocalTimerSession]
                do {
                    let data = try Data(contentsOf: url)
                    loadedData = try JSONDecoder().decode([LocalTimerSession].self, from: data)
                } catch {
                    // OK if first run or missing file
                    return []
                }
                
                let cutoff = Calendar.current.date(byAdding: .day, value: -maxDays, to: Date()) ?? .distantPast
                var trimmed = loadedData.filter { session in
                    let anchor = session.endDate ?? session.startDate
                    return anchor >= cutoff
                }
                
                if trimmed.count > maxCount {
                    trimmed.sort { ($0.endDate ?? $0.startDate) > ($1.endDate ?? $1.startDate) }
                    trimmed = Array(trimmed.prefix(maxCount)).sorted { $0.startDate < $1.startDate }
                }
                
                // Compact file if needed (before returning)
                if trimmed.count != loadedData.count {
                    do {
                        let data = try JSONEncoder().encode(trimmed)
                        try data.write(to: url, options: .atomic)
                    } catch {
                        print("Failed to compact timer sessions: \(error)")
                    }
                }
                
                return trimmed
            }.value
            
            // Update UI on main actor - Task in view context is already on MainActor
            self.sessions = finalSessions
        }
    }

    private var currentActivityPill: some View {
        HStack(spacing: DesignSystem.Layout.spacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("common.label.current_activity", comment: ""))
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
                    Text(NSLocalizedString("common.label.no_activity", comment: ""))
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 8)

            Button(NSLocalizedString("common.button.change", comment: "")) {
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
        HStack(alignment: .top, spacing: 20) {
            // LEFT: Activities panel
            activitiesColumn
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 360)
                .layoutPriority(0)
            
            // CENTER: Timer card (should stay centered)
            VStack(spacing: 16) {
                timerCoreCard
                activityDetailPanel
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
            
            // RIGHT: Study summary pane
            TimerRightPane(activities: activities)
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
                .layoutPriority(0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Activities Column

    private var activitiesColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("common.label.activities", comment: ""))
                    .font(DesignSystem.Typography.body)
                Spacer()
            }

            collectionsRow

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                    if !pinnedActivities.isEmpty {
                        Text(NSLocalizedString("common.label.pinned", comment: ""))
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

                    Text(NSLocalizedString("common.label.all_activities", comment: ""))
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

    // Memoized to avoid recomputing on every render
    @State private var cachedPinnedActivities: [LocalTimerActivity] = []
    @State private var cachedFilteredActivities: [LocalTimerActivity] = []
    @State private var cachedCollections: [String] = ["All"]
    
    private var pinnedActivities: [LocalTimerActivity] {
        cachedPinnedActivities
    }

    private var filteredActivities: [LocalTimerActivity] {
        cachedFilteredActivities
    }

    private var collections: [String] {
        cachedCollections
    }
    
    private func updateCachedValues() {
        cachedPinnedActivities = activities.filter { $0.isPinned }
        
        let query = searchText.lowercased()
        cachedFilteredActivities = activities.filter { activity in
            (!activity.isPinned) &&
            (selectedCollection == "All" || activity.category.lowercased().contains(selectedCollection.lowercased())) &&
            (query.isEmpty || activity.name.lowercased().contains(query) || activity.category.lowercased().contains(query) || (activity.courseCode?.lowercased().contains(query) ?? false))
        }
        
        var set: Set<String> = ["All"]
        set.formUnion(activities.map { $0.category })
        cachedCollections = Array(set).sorted()
    }

    private func openFocusWindow() {
        // Check if Focus window already exists and bring it to front
        if let existing = focusWindowController, let win = existing.window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let tasks = selectedActivity.flatMap { activityTasks($0.id) } ?? []
        let focusView = FocusWindowView(
            mode: mode,
            timeText: TimerCoreCard.timeDisplayStatic(mode: mode, remainingSeconds: remainingSeconds, elapsedSeconds: elapsedSeconds),
            accentColor: settings.activeAccentColor,
            activity: selectedActivity,
            tasks: tasks,
            pomodoroSessions: settings.pomodoroIterations,
            completedPomodoroSessions: completedPomodoroSessions,
            isPomodorBreak: isPomodorBreak,
            remainingSeconds: remainingSeconds,
            elapsedSeconds: elapsedSeconds,
            isRunning: isRunning,
            toggleTask: { task in
                var updated = task
                updated.isCompleted.toggle()
                assignmentsStore.updateTask(updated)
            }
        )
        let focusViewWithEnv = focusView.environmentObject(assignmentsStore)
        let hosting = NSHostingController(rootView: focusViewWithEnv)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = NSWindow.StyleMask([.titled, .closable, .miniaturizable, .resizable])
        window.setContentSize(NSSize(width: 640, height: 480))
        window.center()
        window.title = "Focus"
        window.isReleasedWhenClosed = false
        
        // Create and store delegate with strong reference to prevent deallocation
        let delegate = FocusWindowDelegate { [weak self] in
            // Window closed - clear the controller reference
            self?.focusWindowController = nil
            self?.focusWindowDelegate = nil
        }
        window.delegate = delegate
        focusWindowDelegate = delegate
        
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
            displayStyle: Binding(
                get: { displayStyle },
                set: { displayStyle = $0 }
            ),
            pomodoroSessions: settings.pomodoroIterations,
            completedPomodoroSessions: completedPomodoroSessions,
            isPomodorBreak: isPomodorBreak,
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
                        Text(NSLocalizedString("timer.label.tasks_for_activity", comment: ""))
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

                NotesEditor(
                    title: "Notes",
                    text: Binding(
                        get: { activityNotes[activity.id] ?? "" },
                        set: { newValue in
                            activityNotes[activity.id] = newValue
                            saveNotes(newValue, for: activity.id)
                        }
                    ),
                    minHeight: 120
                )
            } else {
                Text(NSLocalizedString("common.label.select_prompt", comment: ""))
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

    private var selectedActivity: LocalTimerActivity? {
        currentActivity
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
    
    private func startTickTimer() {
        // Cancel any existing timer first
        stopTickTimer()
        
        // Create a new timer publisher and subscribe to it
        tickCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.tick()
            }
    }
    
    private func stopTickTimer() {
        tickCancellable?.cancel()
        tickCancellable = nil
    }

    private func postTimerStateChangeNotification() {
        var userInfo: [String: Any] = [
            "mode": mode,
            "isRunning": isRunning,
            "remainingSeconds": remainingSeconds,
            "elapsedSeconds": elapsedSeconds,
            "pomodoroSessions": pomodoroSessions,
            "completedPomodoroSessions": completedPomodoroSessions,
            "isPomodorBreak": isPomodorBreak,
            "activities": activities,
            "sessions": sessions
        ]
        if let activityID = selectedActivityID {
            userInfo["selectedActivityID"] = activityID
        }
        NotificationCenter.default.post(name: .timerStateDidChange, object: nil, userInfo: userInfo)
    }

    private func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        if activeSession == nil, let activity = currentActivity {
            activeSession = LocalTimerSession(id: UUID(), activityID: activity.id, mode: mode, startDate: Date(), endDate: nil, duration: 0, workSeconds: 0, breakSeconds: 0, isBreakSession: isPomodorBreak)
        }
        postTimerStateChangeNotification()
    }

    private func pauseTimer() {
        isRunning = false
        postTimerStateChangeNotification()
    }

    private func resetTimer() {
        isRunning = false
        elapsedSeconds = 0
        remainingSeconds = TimeInterval(settings.pomodoroFocusMinutes * 60)
        completedPomodoroSessions = 0
        isPomodorBreak = false
        postTimerStateChangeNotification()
    }
    
    private func endTimerSession() {
        pauseTimer()
        if var session = activeSession {
            session.endDate = Date()
            let elapsed = Date().timeIntervalSince(session.startDate)
            session.duration = elapsed
            
            // Update work/break seconds based on mode and phase
            if mode == .pomodoro {
                if session.isBreakSession {
                    session.breakSeconds = elapsed
                    session.workSeconds = 0
                } else {
                    session.workSeconds = elapsed
                    session.breakSeconds = 0
                }
            } else {
                // Stopwatch and Timer: all time is work time
                session.workSeconds = elapsed
                session.breakSeconds = 0
            }
            
            logSession(session)
            sessions.append(session)
            activeSession = nil
        }
        resetTimer()
    }
    
    private func setupTimerNotificationObservers() {
        // Remove any existing observers first
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
        
        // Add observers and store their tokens for cleanup
        let startObserver = NotificationCenter.default.addObserver(forName: .timerStartRequested, object: nil, queue: .main) { _ in
            self.startTimer()
        }
        notificationObservers.append(startObserver)
        
        let stopObserver = NotificationCenter.default.addObserver(forName: .timerStopRequested, object: nil, queue: .main) { _ in
            self.pauseTimer()
        }
        notificationObservers.append(stopObserver)
        
        let endObserver = NotificationCenter.default.addObserver(forName: .timerEndRequested, object: nil, queue: .main) { _ in
            self.endTimerSession()
        }
        notificationObservers.append(endObserver)
    }

    private func assignmentForCurrentActivity() -> AppTask? {
        guard let activity = currentActivity, let tasks = activityTasks(activity.id) else { return nil }
        return tasks.first
    }

    private func syncTimerWithAssignment() {
        guard !isRunning, let task = assignmentForCurrentActivity() else { return }
        remainingSeconds = TimeInterval(max(1, task.estimatedMinutes) * 60)
        postTimerStateChangeNotification()
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
        postTimerStateChangeNotification()
    }

    private func completeCurrentBlock() {
        isRunning = false
        let duration: TimeInterval
        switch mode {
        case .stopwatch:
            duration = elapsedSeconds
            elapsedSeconds = 0
            
            // Send notification for stopwatch complete
            NotificationManager.shared.scheduleTimerCompleted(mode: "Stopwatch", duration: duration)
        case .pomodoro:
            let workDuration = TimeInterval(settings.pomodoroFocusMinutes * 60)
            duration = workDuration - remainingSeconds
            
            // Pomodoro cycle logic: work → break → work → break...
            if isPomodorBreak {
                // Break just finished - increment completed sessions
                completedPomodoroSessions += 1
                isPomodorBreak = false
                remainingSeconds = workDuration // Reset to work time
                
                // Send notification for break complete
                let longBreakCadence = settings.longBreakCadence
                let wasLongBreak = completedPomodoroSessions % longBreakCadence == 0
                NotificationManager.shared.schedulePomodoroBreakComplete(isLongBreak: wasLongBreak)
            } else {
                // Work just finished - switch to break
                isPomodorBreak = true
                
                // Send notification for work complete
                NotificationManager.shared.schedulePomodoroWorkComplete()
                
                // Determine if it's time for a long break
                let longBreakCadence = settings.longBreakCadence
                let isLongBreak = (completedPomodoroSessions + 1) % longBreakCadence == 0
                
                if isLongBreak {
                    remainingSeconds = TimeInterval(settings.pomodoroLongBreakMinutes * 60)
                } else {
                    remainingSeconds = TimeInterval(settings.pomodoroShortBreakMinutes * 60)
                }
            }
        case .countdown:
            let countdownDuration = TimeInterval(settings.pomodoroFocusMinutes * 60)
            duration = countdownDuration - remainingSeconds
            remainingSeconds = countdownDuration
            
            // Send notification for countdown complete
            NotificationManager.shared.scheduleTimerCompleted(mode: "Timer", duration: duration)
        }

        if var session = activeSession {
            session.endDate = Date()
            session.duration = duration
            
            // Update work/break seconds based on mode and phase
            if mode == .pomodoro {
                if session.isBreakSession {
                    session.breakSeconds = duration
                    session.workSeconds = 0
                } else {
                    session.workSeconds = duration
                    session.breakSeconds = 0
                }
            } else {
                // Stopwatch and Timer: all time is work time
                session.workSeconds = duration
                session.breakSeconds = 0
            }
            
            logSession(session)
            // store session for analytics
            sessions.append(session)
        }
        activeSession = nil
        postTimerStateChangeNotification()
    }

    private func logSession(_ session: LocalTimerSession) {
        guard let idx = activities.firstIndex(where: { $0.id == session.activityID }) else { return }
        // Only count work time toward study metrics (not break time)
        activities[idx].todayTrackedSeconds += session.workSeconds
        activities[idx].totalTrackedSeconds += session.workSeconds
    }

    // MARK: Static formatters

    static var timeFormatter: DateFormatter {
        LocaleFormatters.timeFormatter(use24Hour: true, includeSeconds: true)
    }

    static var dateFormatter: DateFormatter {
        LocaleFormatters.mediumDate
    }
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
                Button(NSLocalizedString("common.button.edit", comment: ""), action: onEdit)
                Button(NSLocalizedString("common.button.reset_totals", comment: ""), action: onReset)
                Divider()
                Button(NSLocalizedString("common.button.delete", comment: ""), role: .destructive, action: onDelete)
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
    @Binding var displayStyle: TimerDisplayStyle
    var pomodoroSessions: Int
    var completedPomodoroSessions: Int
    var isPomodorBreak: Bool

    var onStart: () -> Void
    var onPause: () -> Void
    var onReset: () -> Void
    var onSkip: () -> Void
    var onOpenFocus: () -> Void
    
    @State private var showingModeMenu = false

    private var clockSeconds: TimeInterval {
        mode == .stopwatch ? elapsedSeconds : remainingSeconds
    }

    var body: some View {
        VStack(spacing: 16) {
            // Top bar with expand button and ellipsis menu
            HStack(alignment: .center) {
                Button(action: onOpenFocus) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if !isRunning {
                    Button(action: { showingModeMenu = true }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingModeMenu, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(LocalTimerMode.allCases, id: \.self) { timerMode in
                                Button(action: {
                                    mode = timerMode
                                    showingModeMenu = false
                                }) {
                                    HStack {
                                        if mode == timerMode {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                        Text(timerMode.label)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                            Divider()
                            Button(action: {
                                displayStyle = displayStyle == .digital ? .analog : .digital
                                showingModeMenu = false
                            }) {
                                Text(displayStyle == .digital ? TimerDisplayStyle.analog.label : TimerDisplayStyle.digital.label)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .frame(minWidth: 150)
                    }
                }
            }
            .frame(height: 36)
            
            if isRunning {
                FocusSessionView(
                    mode: mode,
                    timeText: timeDisplay,
                    timerSeconds: clockSeconds,
                    displayStyle: displayStyle,
                    pomodoroSessions: pomodoroSessions,
                    completedPomodoroSessions: completedPomodoroSessions,
                    isPomodorBreak: isPomodorBreak,
                    onPause: onPause,
                    onStop: onReset
                )
            } else {
                TimerSetupView(
                    mode: $mode,
                    timeText: timeDisplay,
                    timerSeconds: clockSeconds,
                    displayStyle: displayStyle,
                    pomodoroSessions: pomodoroSessions,
                    completedPomodoroSessions: completedPomodoroSessions,
                    isPomodorBreak: isPomodorBreak,
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
    var timerSeconds: TimeInterval
    var displayStyle: TimerDisplayStyle
    var pomodoroSessions: Int
    var completedPomodoroSessions: Int
    var isPomodorBreak: Bool
    var onStart: () -> Void
    var onOpenFocus: () -> Void
    var onReset: () -> Void
    var settingsCoordinator: SettingsCoordinator

    var body: some View {
        VStack(alignment: .center, spacing: 14) {

            VStack(spacing: 8) {
                if mode == .pomodoro {
                    Text(isPomodorBreak ? "Break" : "Work")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .frame(height: 18)
                } else {
                    Text(mode.label)
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(height: 18)
                }
                if displayStyle == .analog {
                    RootsAnalogClock(
                        diameter: 200,
                        showSecondHand: true,
                        accentColor: .accentColor,
                        timerSeconds: timerSeconds
                    )
                    .frame(height: 200)
                } else {
                    Text(timeText)
                        .font(.system(.largeTitle, design: .monospaced).weight(.light))
                        .monospacedDigit()
                        .frame(height: 72)
                }
            }
            .padding(.vertical, 12)
            
            // Circles container - fixed height
            Group {
                if mode == .pomodoro {
                    HStack(spacing: 8) {
                        ForEach(0..<pomodoroSessions, id: \.self) { index in
                            Circle()
                                .fill(index < completedPomodoroSessions ? Color.accentColor : Color.accentColor.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(completedPomodoroSessions) of \(pomodoroSessions) completed")
                } else {
                    Color.clear.frame(height: 8)
                }
            }
            .frame(height: 12)
            .padding(.bottom, 4)

            Button(NSLocalizedString("timer.action.start", comment: ""), action: onStart)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
                .frame(height: 28)
            
            // Spacer to match FocusSessionView's bottom text
            Text("")
                .font(.caption2)
                .frame(height: 16)
                .opacity(0)
        }
    }
}

// Active session view with analog clock + icon controls.
private struct FocusSessionView: View {
    var mode: LocalTimerMode
    var timeText: String
    var timerSeconds: TimeInterval
    var displayStyle: TimerDisplayStyle
    var pomodoroSessions: Int
    var completedPomodoroSessions: Int
    var isPomodorBreak: Bool
    var onPause: () -> Void
    var onStop: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            VStack(spacing: 8) {
                if mode == .pomodoro {
                    Text(isPomodorBreak ? "Break" : "Work")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .frame(height: 18)
                } else {
                    Text(mode.label)
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(height: 18)
                }
                if displayStyle == .analog {
                    RootsAnalogClock(
                        diameter: 200,
                        showSecondHand: true,
                        accentColor: .accentColor,
                        timerSeconds: timerSeconds
                    )
                    .frame(height: 200)
                } else {
                    Text(timeText)
                        .font(.system(.largeTitle, design: .monospaced).weight(.light))
                        .monospacedDigit()
                        .frame(height: 72)
                }
            }
            .padding(.vertical, 12)
            
            // Circles container - fixed height
            Group {
                if mode == .pomodoro {
                    HStack(spacing: 8) {
                        ForEach(0..<pomodoroSessions, id: \.self) { index in
                            Circle()
                                .fill(index < completedPomodoroSessions ? Color.accentColor : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(completedPomodoroSessions) of \(pomodoroSessions) completed")
                } else {
                    Color.clear.frame(height: 8)
                }
            }
            .frame(height: 12)
            .padding(.bottom, 4)

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
            .padding(.top, 4)
            .frame(height: 28)

            Text("\(mode.label) running")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(0.35)
                .frame(height: 16)
        }
    }
}

private struct FocusWindowView: View {
    var mode: LocalTimerMode
    var timeText: String
    var accentColor: Color
    var activity: LocalTimerActivity?
    var tasks: [AppTask]
    var pomodoroSessions: Int
    var completedPomodoroSessions: Int
    var isPomodorBreak: Bool
    var remainingSeconds: TimeInterval
    var elapsedSeconds: TimeInterval
    var isRunning: Bool
    var toggleTask: (AppTask) -> Void
    @AppStorage("timer.display.style") private var displayStyleRaw: String = TimerDisplayStyle.digital.rawValue
    
    private var clockTime: TimeInterval {
        // Stopwatch shows elapsed time, others show remaining time
        // When idle (not running), default to 0 which shows 12:00:00
        guard isRunning else { return 0 }
        
        switch mode {
        case .stopwatch:
            return elapsedSeconds
        case .pomodoro, .countdown:
            return remainingSeconds
        }
    }

    private var displayStyle: TimerDisplayStyle {
        TimerDisplayStyle(rawValue: displayStyleRaw) ?? .digital
    }

    var body: some View {
        VStack(spacing: 24) {
            if displayStyle == .analog {
                RootsAnalogClock(
                    diameter: 240,
                    showSecondHand: true,
                    accentColor: accentColor,
                    timerSeconds: clockTime
                )
            } else {
                Text(timeText)
                    .font(.system(.largeTitle, design: .monospaced).weight(.light))
                    .monospacedDigit()
            }

            VStack(spacing: 8) {
                if mode == .pomodoro {
                    Text(isPomodorBreak ? "Break" : "Work")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                
                if displayStyle == .analog {
                    Text(timeText)
                        .font(.system(.title, design: .monospaced).weight(.light))
                        .monospacedDigit()
                }
                    
                if mode == .pomodoro {
                    HStack(spacing: 8) {
                        ForEach(0..<pomodoroSessions, id: \.self) { index in
                            Circle()
                                .fill(index < completedPomodoroSessions ? accentColor : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(completedPomodoroSessions) of \(pomodoroSessions) completed")
                } else {
                    Text("\(mode.label) running")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            activityCard
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Materials.card)
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Activity")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let activity {
                VStack(alignment: .leading, spacing: 10) {
                    Text(activity.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    if let course = activity.courseCode {
                        Text(course)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if tasks.isEmpty {
                        Text(NSLocalizedString("timer.label.no_linked_tasks", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(tasks, id: \.id) { task in
                                Button {
                                    toggleTask(task)
                                } label: {
                                    HStack {
                                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(task.isCompleted ? .green : .secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(task.title)
                                                .font(.body)
                                            if let due = task.due {
                                                Text(due, style: .date)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else {
                Text(NSLocalizedString("common.label.no_activity", comment: ""))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private class FocusWindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

// MARK: - Analytics Card

struct StudyAnalyticsCard: View {
    @Binding var showHistory: Bool
    @Binding var selectedRange: HistoryRange
    var activity: LocalTimerActivity?
    var activities: [LocalTimerActivity]
    var sessions: [LocalTimerSession]
    @State private var aggregatedToday: [AnalyticsBucket] = []
    @State private var aggregatedRange: [AnalyticsBucket] = []
    @State private var didLoadAggregates = false

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
        .onAppear {
            if !didLoadAggregates {
                didLoadAggregates = true
                updateAggregates()
            }
        }
        .onChange(of: sessions) { updateAggregates() }
        .onChange(of: activities) { updateAggregates() }
        .onChange(of: selectedRange) { updateAggregates() }
    }

    private var stackedTodayView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
            if #available(macOS 13.0, *), (true) {
                let buckets = aggregatedToday.isEmpty ? StudyAnalyticsAggregator.bucketsForToday() : aggregatedToday
                ChartViewVerticalStacked(buckets: buckets, categoryColors: categoryColorMap(), showLabels: false)
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
                let buckets = aggregatedRange.isEmpty ? bucketsForSelectedRange() : aggregatedRange
                ChartViewVerticalStacked(buckets: buckets, categoryColors: categoryColorMap(), showLabels: false)
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

    private func bucketsForSelectedRange() -> [AnalyticsBucket] {
        switch selectedRange {
        case .today: return StudyAnalyticsAggregator.bucketsForToday()
        case .week: return StudyAnalyticsAggregator.bucketsForWeek()
        case .month: return StudyAnalyticsAggregator.bucketsForMonth()
        case .year: return StudyAnalyticsAggregator.bucketsForYear()
        }
    }

    private func updateAggregates() {
        let sessionsSnapshot = sessions
        let activitiesSnapshot = activities
        let selected = selectedRange
        DispatchQueue.global(qos: .userInitiated).async {
            let todayBuckets = StudyAnalyticsAggregator.bucketsForToday()
            let aggregatedToday = StudyAnalyticsAggregator.aggregate(
                sessions: sessionsSnapshot,
                activities: activitiesSnapshot,
                into: todayBuckets
            )
            let rangeBuckets = {
                switch selected {
                case .today: return StudyAnalyticsAggregator.bucketsForToday()
                case .week: return StudyAnalyticsAggregator.bucketsForWeek()
                case .month: return StudyAnalyticsAggregator.bucketsForMonth()
                case .year: return StudyAnalyticsAggregator.bucketsForYear()
                }
            }()
            let aggregatedRange = StudyAnalyticsAggregator.aggregate(
                sessions: sessionsSnapshot,
                activities: activitiesSnapshot,
                into: rangeBuckets
            )
            DispatchQueue.main.async {
                self.aggregatedToday = aggregatedToday
                self.aggregatedRange = aggregatedRange
            }
        }
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
            Text(NSLocalizedString("timer.help.edit_activities", comment: ""))
                .rootsCaption()
            Spacer()
            Button(NSLocalizedString("common.button.cancel", comment: "")) { dismiss() }
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

// MARK: - Focus Window Delegate

/// Delegate for managing focus window lifecycle.
/// Stored as a strong reference to prevent premature deallocation.
#if os(macOS)
import AppKit

#endif

#endif
