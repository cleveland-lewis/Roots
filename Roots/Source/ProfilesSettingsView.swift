import SwiftUI

struct ProfilesSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel

    enum FocusDuration: String, CaseIterable, Identifiable {
        case fifteen = "15 minutes"
        case twentyFive = "25 minutes"
        case fortyFive = "45 minutes"
        case sixty = "60 minutes"

        var id: String { rawValue }

        var minutes: Int {
            switch self {
            case .fifteen: return 15
            case .twentyFive: return 25
            case .fortyFive: return 45
            case .sixty: return 60
            }
        }
    }

    enum BreakDuration: String, CaseIterable, Identifiable {
        case five = "5 minutes"
        case ten = "10 minutes"
        case fifteen = "15 minutes"

        var id: String { rawValue }

        var minutes: Int {
            switch self {
            case .five: return 5
            case .ten: return 10
            case .fifteen: return 15
            }
        }
    }

    enum EnergyLevel: String, CaseIterable, Identifiable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var id: String { rawValue }
    }

    @State private var focusDuration: FocusDuration = .twentyFive
    @State private var breakDuration: BreakDuration = .five
    @State private var energyLevel: EnergyLevel = .medium

    var body: some View {
        Form {
            Section {
                Picker("Default Focus Duration", selection: $focusDuration) {
                    ForEach(FocusDuration.allCases) { duration in
                        Text(duration.rawValue).tag(duration)
                    }
                }
                .onChange(of: focusDuration) { _, newValue in
                    settings.defaultFocusDuration = newValue.minutes
                    settings.save()
                }

                Picker("Break Duration", selection: $breakDuration) {
                    ForEach(BreakDuration.allCases) { duration in
                        Text(duration.rawValue).tag(duration)
                    }
                }
                .onChange(of: breakDuration) { _, newValue in
                    settings.defaultBreakDuration = newValue.minutes
                    settings.save()
                }

                Picker("Default Energy Level", selection: $energyLevel) {
                    ForEach(EnergyLevel.allCases) { level in
                        HStack {
                            energyIcon(for: level)
                            Text(level.rawValue)
                        }
                        .tag(level)
                    }
                }
                .onChange(of: energyLevel) { _, newValue in
                    settings.defaultEnergyLevel = newValue.rawValue
                    settings.save()
                }
            } header: {
                Text("Study Session Defaults")
            } footer: {
                Text("These settings determine your default study session configuration. You can adjust them for individual sessions.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Enable Study Coach", isOn: $settings.enableStudyCoach)
                    .onChange(of: settings.enableStudyCoach) { _, _ in
                        settings.save()
                    }

                Toggle("Smart Notifications", isOn: $settings.smartNotifications)
                    .onChange(of: settings.smartNotifications) { _, _ in
                        settings.save()
                    }

                Toggle("Auto-Schedule Breaks", isOn: $settings.autoScheduleBreaks)
                    .onChange(of: settings.autoScheduleBreaks) { _, _ in
                        settings.save()
                    }
            } header: {
                Text("Study Coach")
            } footer: {
                Text("The Study Coach helps you maintain focus and suggests optimal study patterns based on your energy levels.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Track Study Hours", isOn: $settings.trackStudyHours)
                    .onChange(of: settings.trackStudyHours) { _, _ in
                        settings.save()
                    }

                Toggle("Show Productivity Insights", isOn: $settings.showProductivityInsights)
                    .onChange(of: settings.showProductivityInsights) { _, _ in
                        settings.save()
                    }

                Toggle("Weekly Summary Notifications", isOn: $settings.weeklySummaryNotifications)
                    .onChange(of: settings.weeklySummaryNotifications) { _, _ in
                        settings.save()
                    }
            } header: {
                Text("Productivity Tracking")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cognitive Preferences")
                        .font(.subheadline.weight(.semibold))

                    Toggle("Prefer Morning Study Sessions", isOn: $settings.preferMorningSessions)
                        .onChange(of: settings.preferMorningSessions) { _, _ in
                            settings.save()
                        }

                    Toggle("Prefer Evening Study Sessions", isOn: $settings.preferEveningSessions)
                        .onChange(of: settings.preferEveningSessions) { _, _ in
                            settings.save()
                        }

                    Toggle("Enable Deep Work Mode", isOn: $settings.enableDeepWorkMode)
                        .onChange(of: settings.enableDeepWorkMode) { _, _ in
                            settings.save()
                        }
                }
            } footer: {
                Text("Customize your study preferences based on your peak productivity times.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadCurrentValues()
        }
    }

    private func energyIcon(for level: EnergyLevel) -> some View {
        Group {
            switch level {
            case .low:
                Image(systemName: "battery.25")
                    .foregroundStyle(.orange)
            case .medium:
                Image(systemName: "battery.50")
                    .foregroundStyle(.yellow)
            case .high:
                Image(systemName: "battery.100")
                    .foregroundStyle(.green)
            }
        }
        .font(DesignSystem.Typography.body)
    }

    private func loadCurrentValues() {
        // Focus Duration
        if let duration = settings.defaultFocusDuration {
            switch duration {
            case 15: focusDuration = .fifteen
            case 25: focusDuration = .twentyFive
            case 45: focusDuration = .fortyFive
            case 60: focusDuration = .sixty
            default: focusDuration = .twentyFive
            }
        }

        // Break Duration
        if let duration = settings.defaultBreakDuration {
            switch duration {
            case 5: breakDuration = .five
            case 10: breakDuration = .ten
            case 15: breakDuration = .fifteen
            default: breakDuration = .five
            }
        }

        // Energy Level
        energyLevel = EnergyLevel(rawValue: settings.defaultEnergyLevel ?? "Medium") ?? .medium
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    ProfilesSettingsView()
        .environmentObject(AppSettingsModel.shared)
        .frame(width: 500, height: 600)
}
#endif
