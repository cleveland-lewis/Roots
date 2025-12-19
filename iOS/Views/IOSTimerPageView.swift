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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    modePicker
                    timerStatusCard
                    durationControls
                    settingsControls
                    activityPicker
                    activityManager
                    sessionHistory
                }
                .padding(20)
            }
            .navigationTitle("Timer")
            .onAppear {
                if viewModel.alarmScheduler == nil {
                    viewModel.alarmScheduler = IOSTimerAlarmScheduler()
                }
                syncSettingsFromApp()
            }
            .onChange(of: settings.pomodoroFocusMinutes) { _, _ in syncSettingsFromApp() }
            .onChange(of: settings.pomodoroShortBreakMinutes) { _, _ in syncSettingsFromApp() }
            .onChange(of: settings.pomodoroLongBreakMinutes) { _, _ in syncSettingsFromApp() }
            .onChange(of: settings.timerAlertsEnabled) { _, _ in syncSettingsFromApp() }
            .onChange(of: settings.pomodoroAlertsEnabled) { _, _ in syncSettingsFromApp() }
            .onChange(of: viewModel.currentSession) { _, _ in
                syncLiveActivity()
            }
            .onChange(of: viewModel.sessionElapsed) { _, _ in
                syncLiveActivity()
            }
            .onChange(of: viewModel.sessionRemaining) { _, _ in
                syncLiveActivity()
            }
            .onChange(of: viewModel.isOnBreak) { _, _ in
                syncLiveActivity()
            }
            .onChange(of: viewModel.currentMode) { _, _ in
                syncLiveActivity()
            }
            .onChange(of: viewModel.focusDuration) { _, newValue in
                settings.pomodoroFocusMinutes = max(Int(newValue / 60), 1)
            }
            .onChange(of: viewModel.breakDuration) { _, newValue in
                settings.pomodoroShortBreakMinutes = max(Int(newValue / 60), 1)
            }
        }
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
            Text(timeString(for: viewModel.sessionRemaining, elapsed: viewModel.sessionElapsed))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
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
            } else if isPaused {
                Button("Resume") { viewModel.resumeSession() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Start") { viewModel.startSession() }
                    .buttonStyle(.borderedProminent)
            }

            Button("Stop") { viewModel.endSession(completed: false) }
                .buttonStyle(.bordered)
                .disabled(sessionState == .idle)

            if viewModel.currentMode == .pomodoro {
                Button("Skip") { viewModel.skipSegment() }
                    .buttonStyle(.bordered)
                    .disabled(!isRunning)
            }
        }
    }

    private var durationControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Durations")
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
                Text("Stopwatch counts up while running.")
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
            Text("Activity")
                .font(.headline)
            Picker("Activity", selection: $viewModel.currentActivityID) {
                Text("None").tag(UUID?.none)
                ForEach(viewModel.activities) { activity in
                    Text(activity.name)
                        .tag(Optional(activity.id))
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alerts")
                .font(.headline)
            Toggle("Timer Alerts", isOn: $settings.timerAlertsEnabled)
            Toggle("Pomodoro Alerts", isOn: $settings.pomodoroAlertsEnabled)
            Toggle("AlarmKit Loud Alarm (iOS)", isOn: $settings.alarmKitTimersEnabled)
        }
    }

    private var activityManager: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manage Activities")
                .font(.headline)
            HStack {
                TextField("New activity name", text: $newActivityName)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { addActivity() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newActivityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ForEach(viewModel.activities) { activity in
                HStack {
                    Button(activity.name) {
                        viewModel.selectActivity(activity.id)
                    }
                    .buttonStyle(.plain)
                    Spacer()
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
        }
    }

    private var sessionHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)
            if viewModel.pastSessions.isEmpty {
                Text("No sessions yet.")
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

    private var iterationsRow: some View {
        HStack {
            Text("Iterations")
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
}
#endif
