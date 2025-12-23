import SwiftUI
#if os(iOS)

struct TimerSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @AppStorage("timer.display.style") private var timerDisplayStyleRaw: String = TimerDisplayStyle.digital.rawValue
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text(NSLocalizedString("settings.timer.focus_duration", comment: "Focus Duration"))
                    Spacer()
                    Text("\(settings.pomodoroFocusStorage) " + NSLocalizedString("time.minutes", comment: "min"))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { Double(settings.pomodoroFocusStorage) },
                    set: { settings.pomodoroFocusStorage = Int($0) }
                ), in: 5...90, step: 5)
                
                HStack {
                    Text(NSLocalizedString("settings.timer.short_break", comment: "Short Break"))
                    Spacer()
                    Text("\(settings.pomodoroShortBreakStorage) " + NSLocalizedString("time.minutes", comment: "min"))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { Double(settings.pomodoroShortBreakStorage) },
                    set: { settings.pomodoroShortBreakStorage = Int($0) }
                ), in: 1...30, step: 1)
                
                HStack {
                    Text(NSLocalizedString("settings.timer.long_break", comment: "Long Break"))
                    Spacer()
                    Text("\(settings.pomodoroLongBreakStorage) " + NSLocalizedString("time.minutes", comment: "min"))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { Double(settings.pomodoroLongBreakStorage) },
                    set: { settings.pomodoroLongBreakStorage = Int($0) }
                ), in: 5...60, step: 5)
                
                Stepper(value: $settings.pomodoroIterationsStorage, in: 1...10) {
                    HStack {
                        Text(NSLocalizedString("settings.timer.iterations", comment: "Pomodoro Cycles"))
                        Spacer()
                        Text("\(settings.pomodoroIterationsStorage)")
                            .foregroundColor(.secondary)
                    }
                }
                
            } header: {
                Text(NSLocalizedString("settings.timer.pomodoro.header", comment: "Pomodoro Settings"))
            }

            Section {
                HStack {
                    Text(NSLocalizedString("settings.timer.timer_duration", comment: "Timer Duration"))
                    Spacer()
                    Text("\(settings.timerDurationMinutes) " + NSLocalizedString("time.minutes", comment: "min"))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { Double(settings.timerDurationMinutes) },
                    set: { settings.timerDurationMinutes = Int($0) }
                ), in: 1...180, step: 1)
            } header: {
                Text(NSLocalizedString("settings.timer.timer_duration", comment: "Timer Duration"))
            }

            Section {
                Picker(NSLocalizedString("settings.timer.display", comment: "Timer display"), selection: timerDisplayStyleBinding) {
                    ForEach(TimerDisplayStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
            } header: {
                Text(NSLocalizedString("settings.timer.display", comment: "Timer display"))
            }
            
            Section {
                Toggle(isOn: $settings.timerAlertsEnabledStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.timer.alerts", comment: "Timer Alerts"))
                        Text(NSLocalizedString("settings.timer.alerts.detail", comment: "Show notification when timer completes"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $settings.pomodoroAlertsEnabledStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.timer.pomodoro_alerts", comment: "Pomodoro Alerts"))
                        Text(NSLocalizedString("settings.timer.pomodoro_alerts.detail", comment: "Alert at each pomodoro phase change"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $settings.alarmKitTimersEnabledStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.timer.alarmkit", comment: "AlarmKit Timers"))
                        Text(NSLocalizedString("settings.timer.alarmkit.detail", comment: "Use iOS AlarmKit for loud system alarms"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("settings.timer.alerts.header", comment: "Alerts"))
            } footer: {
                Text(NSLocalizedString("settings.timer.alerts.footer", comment: "AlarmKit provides system-level alarms that work even when the app is closed."))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("settings.category.timer", comment: "Timer"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var timerDisplayStyleBinding: Binding<TimerDisplayStyle> {
        Binding(
            get: { TimerDisplayStyle(rawValue: timerDisplayStyleRaw) ?? .digital },
            set: { timerDisplayStyleRaw = $0.rawValue }
        )
    }
}

#Preview {
    NavigationStack {
        TimerSettingsView()
            .environmentObject(AppSettingsModel.shared)
    }
}
#endif
