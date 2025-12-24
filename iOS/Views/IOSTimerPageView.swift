//
//  IOSTimerPageView.swift
//  Roots (iOS)
//

#if os(iOS)
import SwiftUI

struct IOSTimerPageView: View {
    @EnvironmentObject private var settings: AppSettingsModel
    @StateObject private var viewModel = TimerPageViewModel()
    @StateObject private var liveActivityManager = IOSTimerLiveActivityManager()
    @State private var activitySearchText = ""
    @State private var selectedCollectionID: UUID? = nil
    @AppStorage("timer.display.style") private var timerDisplayStyleRaw: String = TimerDisplayStyle.digital.rawValue
    @State private var timerCardWidth: CGFloat = 0
    @State private var showingFocusPage = false
    @State private var showingRecentSessions = false
    @State private var showingAddSession = false

    private var sessionState: FocusSession.State {
        viewModel.currentSession?.state ?? .idle
    }

    private var isRunning: Bool {
        sessionState == .running
    }

    private var isPaused: Bool {
        sessionState == .paused
    }

    private var displayStyle: TimerDisplayStyle {
        TimerDisplayStyle(rawValue: timerDisplayStyleRaw) ?? .digital
    }

    private var timerDialSeconds: TimeInterval {
        viewModel.currentMode == .stopwatch ? viewModel.sessionElapsed : viewModel.sessionRemaining
    }

    var body: some View {
        mainScroll
            .modifier(IOSNavigationChrome(title: NSLocalizedString("ios.timer.title", comment: "Timer")))
            .modifier(TimerSyncModifiers(viewModel: viewModel, settings: settings, syncLiveActivity: syncLiveActivity, syncSettingsFromApp: syncSettingsFromApp))
    }

    private var mainScroll: some View {
        ScrollView {
            contentStack
        }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 20) {
            timerStatusCard
            activityPicker
            activityCollections
            activitySearch
            activityNotes
            sessionButtons
#if DEBUG
            debugSection
#endif
        }
        .padding(20)
    }

    private var timerStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                if sessionState == .idle {
                    Button {
                        showingFocusPage = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NSLocalizedString("timer.focus.window_title", comment: "Focus"))
                } else {
                    Text(statusTitle)
                        .font(.headline)
                        .accessibilityIdentifier("Timer.Status")
                }
                Spacer()
                Menu {
                    ForEach(TimerMode.allCases) { mode in
                        Button {
                            viewModel.currentMode = mode
                        } label: {
                            Label(mode.displayName, systemImage: mode.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.headline)
                }
                .accessibilityLabel(NSLocalizedString("ios.timer.mode", comment: "Mode"))
            }
            if displayStyle == .analog {
                RootsAnalogClock(
                    style: .stopwatch,
                    diameter: max(180, timerDialDiameter),
                    showSecondHand: true,
                    accentColor: .accentColor,
                    timerSeconds: timerDialSeconds
                )
                .accessibilityIdentifier("Timer.Clock")
                .frame(maxWidth: .infinity)
            } else {
                Text(timeString(for: viewModel.sessionRemaining, elapsed: viewModel.sessionElapsed))
                    .font(.system(size: timerTextSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityIdentifier("Timer.Time")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            if viewModel.currentMode == .pomodoro {
                Text(viewModel.isOnBreak ? NSLocalizedString("ios.timer.break", comment: "Break") : NSLocalizedString("ios.timer.focus", comment: "Focus"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            controlRow
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: TimerCardWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(TimerCardWidthKey.self) { width in
            if width > 0 && abs(width - timerCardWidth) > 0.5 {
                timerCardWidth = width
            }
        }
        .sheet(isPresented: $showingFocusPage) {
            focusPage
        }
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            if isRunning {
                Button(NSLocalizedString("ios.timer.pause", comment: "Pause")) { viewModel.pauseSession() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("Timer.Pause")
            } else if isPaused {
                Button(NSLocalizedString("ios.timer.resume", comment: "Resume")) { viewModel.resumeSession() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("Timer.Resume")
            } else {
                Button(NSLocalizedString("ios.timer.start", comment: "Start")) { viewModel.startSession() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("Timer.Start")
            }

            Button(NSLocalizedString("ios.timer.stop", comment: "Stop")) { viewModel.endSession(completed: false) }
                .buttonStyle(.bordered)
                .disabled(sessionState == .idle)
                .accessibilityIdentifier("Timer.Stop")

            if viewModel.currentMode == .pomodoro {
                Button(NSLocalizedString("ios.timer.skip", comment: "Skip")) { viewModel.skipSegment() }
                    .buttonStyle(.bordered)
                    .disabled(!isRunning)
                    .accessibilityIdentifier("Timer.Skip")
            }
        }
    }

    private var activityPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("timer.label.activity", comment: "Activity"))
                .font(.headline)
            Picker("Activity", selection: $viewModel.currentActivityID) {
                Text(NSLocalizedString("timer.label.none", comment: "None")).tag(UUID?.none)
                ForEach(viewModel.activities) { activity in
                    Text(activity.name)
                        .tag(Optional(activity.id))
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var activityCollections: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    selectedCollectionID = nil
                } label: {
                    collectionChip(title: "All", isSelected: selectedCollectionID == nil)
                }
                .buttonStyle(.plain)

                ForEach(viewModel.collections) { collection in
                    Button {
                        selectedCollectionID = collection.id
                    } label: {
                        collectionChip(title: collection.name, isSelected: selectedCollectionID == collection.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func collectionChip(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(uiColor: .secondarySystemBackground))
            )
    }

    private var activitySearch: some View {
        TextField("Search activities", text: $activitySearchText)
            .textFieldStyle(.roundedBorder)
    }

    private var activityNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let activity = selectedActivity {
                Text(activity.name)
                    .font(.subheadline.weight(.semibold))
                NotesEditor(
                    title: NSLocalizedString("timer.label.notes", comment: "Notes"),
                    text: activityNoteBinding,
                    minHeight: 120
                )
            } else {
                Text(NSLocalizedString("timer.focus.no_linked_tasks", comment: "No activity"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var sessionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showingRecentSessions = true
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Recent Sessions")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            
            Button {
                showingAddSession = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Session")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingRecentSessions) {
            recentSessionsView
        }
        .sheet(isPresented: $showingAddSession) {
            addSessionView
        }
    }

    private var statusTitle: String {
        switch sessionState {
        case .running: return "Running"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .cancelled: return "Stopped"
        case .idle: return "Ready"
        }
    }

    private func timeString(for remaining: TimeInterval, elapsed: TimeInterval) -> String {
        switch viewModel.currentMode {
        case .stopwatch:
            return durationString(elapsed)
        case .timer, .pomodoro:
            return durationString(remaining)
        }
    }

    private var focusPage: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if displayStyle == .analog {
                    RootsAnalogClock(
                        style: .stopwatch,
                        diameter: min(max(220, timerDialDiameter), 520),
                        showSecondHand: true,
                        accentColor: .accentColor,
                        timerSeconds: timerDialSeconds
                    )
                } else {
                    Text(timeString(for: viewModel.sessionRemaining, elapsed: viewModel.sessionElapsed))
                        .font(.system(size: 84, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }
                if viewModel.currentMode == .pomodoro {
                    Text(viewModel.isOnBreak ? NSLocalizedString("ios.timer.break", comment: "Break") : NSLocalizedString("ios.timer.focus", comment: "Focus"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                controlRow
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(NSLocalizedString("timer.focus.window_title", comment: "Focus"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFocusPage = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private var timerDialDiameter: CGFloat {
        let available = max(0, timerCardWidth - 32)
        return min(available, 520)
    }

    private var timerTextSize: CGFloat {
        guard timerCardWidth > 0 else { return 48 }
        return min(max(timerCardWidth / 6, 48), 96)
    }
    
    // MARK: - Recent Sessions View
    
    private var recentSessionsView: some View {
        NavigationStack {
            List {
                ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { date in
                    Section(header: Text(sectionTitle(for: date))) {
                        ForEach(groupedSessions[date] ?? []) { session in
                            sessionRow(session)
                        }
                        .onDelete { indexSet in
                            deleteSessions(at: indexSet, in: date)
                        }
                    }
                }
            }
            .navigationTitle("Recent Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingRecentSessions = false
                    } label: {
                        Text("Done")
                    }
                }
            }
        }
    }
    
    private func sessionRow(_ session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: session.mode.systemImage)
                    .foregroundColor(.accentColor)
                Text(session.mode.displayName)
                    .font(.headline)
                Spacer()
                Text(durationString(session.actualDuration ?? 0))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            
            if let activityID = session.activityID,
               let activity = viewModel.activities.first(where: { $0.id == activityID }) {
                Text(activity.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("No Activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let startedAt = session.startedAt {
                Text(timeFormatter.string(from: startedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var groupedSessions: [Date: [FocusSession]] {
        let calendar = Calendar.current
        return Dictionary(grouping: viewModel.pastSessions) { session in
            guard let date = session.startedAt else { return Date() }
            return calendar.startOfDay(for: date)
        }
    }
    
    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return dateFormatter.string(from: date)
        }
    }
    
    private func deleteSessions(at indexSet: IndexSet, in date: Date) {
        guard let sessions = groupedSessions[date] else { return }
        let idsToDelete = indexSet.map { sessions[$0].id }
        viewModel.deleteSessions(ids: idsToDelete)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
    
    // MARK: - Add Session View
    
    private var addSessionView: some View {
        IOSAddSessionView(viewModel: viewModel) {
            showingAddSession = false
        }
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private var selectedActivity: TimerActivity? {
        guard let id = viewModel.currentActivityID else { return nil }
        return viewModel.activities.first(where: { $0.id == id })
    }

    private var activityNoteBinding: Binding<String> {
        guard let activity = selectedActivity else { return .constant("") }
        return Binding(
            get: { activity.note ?? "" },
            set: { newValue in
                var updated = activity
                updated.note = newValue
                viewModel.updateActivity(updated)
            }
        )
    }

    private func syncLiveActivity() {
        liveActivityManager.sync(
            currentMode: viewModel.currentMode,
            session: viewModel.currentSession,
            elapsed: viewModel.sessionElapsed,
            remaining: viewModel.sessionRemaining,
            isOnBreak: viewModel.isOnBreak
        )
    }

    private func syncSettingsFromApp() {
        viewModel.focusDuration = TimeInterval(settings.pomodoroFocusMinutes * 60)
        viewModel.breakDuration = TimeInterval(settings.pomodoroShortBreakMinutes * 60)
        viewModel.timerDuration = TimeInterval(settings.timerDurationMinutes * 60)
    }

#if DEBUG
    private var debugSection: some View {
        Group {
            if ProcessInfo.processInfo.arguments.contains("UITestTimerDebug") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("timer.debug.label", comment: "Debug"))
                        .font(.headline)
                    Text("Session: \(sessionState.rawValue)")
                        .accessibilityIdentifier("Timer.SessionState")
                    Text("LiveActivity: \(liveActivityStatus)")
                        .accessibilityIdentifier("Timer.LiveActivityState")
                    Button("Advance 10k") {
                        viewModel.debugAdvance(seconds: 10_000)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("Timer.DebugAdvance")
                }
            }
        }
    }

    private var liveActivityStatus: String {
        guard liveActivityManager.isAvailable else { return "Unavailable" }
        return liveActivityManager.isActive ? "Active" : "Inactive"
    }
#endif
}

private struct TimerCardWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

private struct TimerSyncModifiers: ViewModifier {
    @ObservedObject var viewModel: TimerPageViewModel
    @ObservedObject var settings: AppSettingsModel
    let syncLiveActivity: () -> Void
    let syncSettingsFromApp: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(TimerSettingsSync(settings: settings, requestAlarmAuthorization: requestAlarmAuthorization, syncSettingsFromApp: syncSettingsFromApp))
            .modifier(TimerLiveActivitySync(viewModel: viewModel, syncLiveActivity: syncLiveActivity))
            .modifier(TimerDurationSync(viewModel: viewModel, settings: settings))
            .onAppear {
                if viewModel.alarmScheduler == nil {
                    viewModel.alarmScheduler = IOSTimerAlarmScheduler()
                }
                syncSettingsFromApp()
            }
    }

    private func requestAlarmAuthorization() async -> Bool {
        guard let scheduler = viewModel.alarmScheduler as? IOSTimerAlarmScheduler else { return false }
        if #available(iOS 17.0, *) {
            return await scheduler.requestAuthorizationIfNeeded()
        }
        return false
    }
}

private struct TimerSettingsSync: ViewModifier {
    @ObservedObject var settings: AppSettingsModel
    let requestAlarmAuthorization: () async -> Bool
    let syncSettingsFromApp: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: settings.pomodoroFocusMinutes) { _, _ in syncSettingsFromApp() }
            .onChange(of: settings.pomodoroShortBreakMinutes) { _, _ in syncSettingsFromApp() }
            .onChange(of: settings.pomodoroLongBreakMinutes) { _, _ in syncSettingsFromApp() }
            .onChange(of: settings.timerDurationMinutes) { _, _ in syncSettingsFromApp() }
            .onChange(of: settings.timerAlertsEnabled) { _, _ in syncSettingsFromApp() }
            .onChange(of: settings.pomodoroAlertsEnabled) { _, _ in syncSettingsFromApp() }
            .onChange(of: settings.alarmKitTimersEnabled) { _, newValue in
                guard newValue else { return }
                Task { _ = await requestAlarmAuthorization() }
            }
    }
}

private struct TimerLiveActivitySync: ViewModifier {
    @ObservedObject var viewModel: TimerPageViewModel
    let syncLiveActivity: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.currentSession) { _, _ in syncLiveActivity() }
            .onChange(of: viewModel.sessionElapsed) { _, _ in syncLiveActivity() }
            .onChange(of: viewModel.sessionRemaining) { _, _ in syncLiveActivity() }
            .onChange(of: viewModel.isOnBreak) { _, _ in syncLiveActivity() }
            .onChange(of: viewModel.currentMode) { _, _ in syncLiveActivity() }
    }
}

private struct TimerDurationSync: ViewModifier {
    @ObservedObject var viewModel: TimerPageViewModel
    @ObservedObject var settings: AppSettingsModel

    func body(content: Content) -> some View {
        content
            .modifier(FocusDurationSync(viewModel: viewModel, settings: settings))
            .modifier(BreakDurationSync(viewModel: viewModel, settings: settings))
            .modifier(TimerValueSync(viewModel: viewModel, settings: settings))
    }
}

private struct FocusDurationSync: ViewModifier {
    @ObservedObject var viewModel: TimerPageViewModel
    @ObservedObject var settings: AppSettingsModel
    
    func body(content: Content) -> some View {
        content.onChange(of: viewModel.focusDuration) { _, newValue in
            settings.pomodoroFocusMinutes = max(Int(newValue / 60), 1)
        }
    }
}

private struct BreakDurationSync: ViewModifier {
    @ObservedObject var viewModel: TimerPageViewModel
    @ObservedObject var settings: AppSettingsModel
    
    func body(content: Content) -> some View {
        content.onChange(of: viewModel.breakDuration) { _, newValue in
            settings.pomodoroShortBreakMinutes = max(Int(newValue / 60), 1)
        }
    }
}

private struct TimerValueSync: ViewModifier {
    @ObservedObject var viewModel: TimerPageViewModel
    @ObservedObject var settings: AppSettingsModel
    
    func body(content: Content) -> some View {
        content.onChange(of: viewModel.timerDuration) { _, newValue in
            settings.timerDurationMinutes = max(Int(newValue / 60), 1)
        }
    }
}
#endif
