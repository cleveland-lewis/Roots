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
    @State private var newActivityName = ""
    @State private var activitySearchText = ""
    @State private var selectedCollectionID: UUID? = nil

    private var sessionState: FocusSession.State {
        viewModel.currentSession?.state ?? .idle
    }

    private var isRunning: Bool {
        sessionState == .running
    }

    private var isPaused: Bool {
        sessionState == .paused
    }

    var body: some View {
        mainScroll
            .modifier(IOSNavigationChrome(title: "Timer"))
            .modifier(TimerSyncModifiers(viewModel: viewModel, settings: settings, syncLiveActivity: syncLiveActivity, syncSettingsFromApp: syncSettingsFromApp))
    }

    private var mainScroll: some View {
        ScrollView {
            contentStack
        }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 20) {
            modePicker
            timerStatusCard
            durationControls
            settingsControls
            activityPicker
            activityCollections
            activitySearch
            activityNotes
            activityManager
            sessionHistory
#if DEBUG
            debugSection
#endif
        }
        .padding(20)
    }

    private var modePicker: some View {
        Picker("Mode", selection: $viewModel.currentMode) {
            ForEach(TimerMode.allCases) { mode in
                Label(mode.displayName, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var timerStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(statusTitle)
                .font(.headline)
                .accessibilityIdentifier("Timer.Status")
            Text(timeString(for: viewModel.sessionRemaining, elapsed: viewModel.sessionElapsed))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .accessibilityIdentifier("Timer.Time")
            if viewModel.currentMode == .pomodoro {
                Text(viewModel.isOnBreak ? "Break" : "Focus")
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
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            if isRunning {
                Button("Pause") { viewModel.pauseSession() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("Timer.Pause")
            } else if isPaused {
                Button("Resume") { viewModel.resumeSession() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("Timer.Resume")
            } else {
                Button("Start") { viewModel.startSession() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("Timer.Start")
            }

            Button("Stop") { viewModel.endSession(completed: false) }
                .buttonStyle(.bordered)
                .disabled(sessionState == .idle)
                .accessibilityIdentifier("Timer.Stop")

            if viewModel.currentMode == .pomodoro {
                Button("Skip") { viewModel.skipSegment() }
                    .buttonStyle(.bordered)
                    .disabled(!isRunning)
                    .accessibilityIdentifier("Timer.Skip")
            }
        }
    }

    private var durationControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("timer.label.durations", comment: "Durations"))
                .font(.headline)
            switch viewModel.currentMode {
            case .pomodoro:
                stepperRow(label: "Focus", value: $viewModel.focusDuration, range: 5 * 60...90 * 60, step: 5 * 60)
                stepperRow(label: "Break", value: $viewModel.breakDuration, range: 1 * 60...30 * 60, step: 1 * 60)
                stepperRow(label: "Long Break", value: longBreakDurationBinding, range: 5 * 60...60 * 60, step: 5 * 60)
                iterationsRow
            case .timer:
                stepperRow(label: "Timer", value: $viewModel.timerDuration, range: 1 * 60...180 * 60, step: 1 * 60)
            case .stopwatch:
                Text(NSLocalizedString("timer.mode.stopwatch_description", comment: "Stopwatch description"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func stepperRow(label: String, value: Binding<TimeInterval>, range: ClosedRange<TimeInterval>, step: TimeInterval) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(minutesString(value.wrappedValue))
                .monospacedDigit()
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
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
            Text(NSLocalizedString("timer.label.notes", comment: "Notes"))
                .font(.headline)
            if let activity = selectedActivity {
                Text(activity.name)
                    .font(.subheadline.weight(.semibold))
                TextEditor(text: activityNoteBinding)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
            } else {
                Text(NSLocalizedString("timer.focus.no_linked_tasks", comment: "No activity"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("timer.label.alerts", comment: "Alerts"))
                .font(.headline)
            Toggle("Timer Alerts", isOn: $settings.timerAlertsEnabled)
            Toggle("Pomodoro Alerts", isOn: $settings.pomodoroAlertsEnabled)
            Toggle("AlarmKit Loud Alarm (iOS)", isOn: $settings.alarmKitTimersEnabled)
        }
    }

    private var activityManager: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("timer.label.manage_activities", comment: "Manage"))
                .font(.headline)
            HStack {
                TextField("New activity name", text: $newActivityName)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { addActivity() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newActivityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !pinnedActivities.isEmpty {
                Text(NSLocalizedString("timer.label.pinned", comment: "Pinned"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(pinnedActivities) { activity in
                    activityRow(activity)
                }
            }

            Text(NSLocalizedString("timer.label.all_activities", comment: "All"))
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(filteredActivities) { activity in
                activityRow(activity)
            }
        }
    }

    private var sessionHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("timer.stats.recent_sessions", comment: "Recent"))
                .font(.headline)
            if viewModel.pastSessions.isEmpty {
                Text(NSLocalizedString("timer.stats.no_sessions", comment: "No sessions"))
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.pastSessions.prefix(5)) { session in
                    HStack {
                        Text(session.mode.displayName)
                        Spacer()
                        Text(durationString(session.actualDuration ?? 0))
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                }
            }
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

    private func minutesString(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds.rounded()) / 60
        return "\(minutes) min"
    }

    private var longBreakDurationBinding: Binding<TimeInterval> {
        Binding(
            get: { TimeInterval(settings.pomodoroLongBreakMinutes * 60) },
            set: { settings.pomodoroLongBreakMinutes = max(Int($0 / 60), 1) }
        )
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

    private var iterationsRow: some View {
        HStack {
            Text(NSLocalizedString("timer.pomodoro.iterations", comment: "Iterations"))
            Spacer()
            Text("\(settings.pomodoroIterations)")
                .monospacedDigit()
            Stepper("", value: $settings.pomodoroIterations, in: 1...12)
                .labelsHidden()
        }
    }

    private func addActivity() {
        let trimmed = newActivityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.addActivity(TimerActivity(name: trimmed))
        newActivityName = ""
    }

    private func activityRow(_ activity: TimerActivity) -> some View {
        HStack {
            Button(activity.name) {
                viewModel.selectActivity(activity.id)
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                togglePinned(activity)
            } label: {
                Image(systemName: activity.isPinned ? "pin.fill" : "pin")
            }
            .buttonStyle(.plain)
            Button(role: .destructive) {
                viewModel.deleteActivity(id: activity.id)
            } label: {
                Image(systemName: "trash")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }

    private func togglePinned(_ activity: TimerActivity) {
        var updated = activity
        updated.isPinned.toggle()
        viewModel.updateActivity(updated)
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
    }

    private var filteredActivities: [TimerActivity] {
        viewModel.activities
            .filter { activity in
                guard selectedCollectionID == nil || activity.collectionID == selectedCollectionID else { return false }
                guard !activity.isPinned else { return false }
                if activitySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return true
                }
                let query = activitySearchText.lowercased()
                return activity.name.lowercased().contains(query)
            }
    }

    private var pinnedActivities: [TimerActivity] {
        viewModel.activities
            .filter { $0.isPinned }
            .filter { activity in
                guard selectedCollectionID == nil || activity.collectionID == selectedCollectionID else { return false }
                if activitySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return true
                }
                let query = activitySearchText.lowercased()
                return activity.name.lowercased().contains(query)
            }
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
            .onChange(of: viewModel.focusDuration) { _, newValue in
                settings.pomodoroFocusMinutes = max(Int(newValue / 60), 1)
            }
            .onChange(of: viewModel.breakDuration) { _, newValue in
                settings.pomodoroShortBreakMinutes = max(Int(newValue / 60), 1)
            }
    }
}
#endif
