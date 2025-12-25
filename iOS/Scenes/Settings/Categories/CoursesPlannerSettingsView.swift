import SwiftUI
#if os(iOS)

struct CoursesPlannerSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    
    var body: some View {
        List {
            Section {
                Picker(selection: Binding(
                    get: { plannerHorizon },
                    set: { settings.plannerHorizonStorage = $0.rawValue }
                )) {
                    Text(NSLocalizedString("settings.planner.horizon.1_week", comment: "1 Week")).tag(PlannerHorizon.oneWeek)
                    Text(NSLocalizedString("settings.planner.horizon.2_weeks", comment: "2 Weeks")).tag(PlannerHorizon.twoWeeks)
                    Text(NSLocalizedString("settings.planner.horizon.1_month", comment: "1 Month")).tag(PlannerHorizon.oneMonth)
                } label: {
                    Text(NSLocalizedString("settings.planner.horizon", comment: "Planning Horizon"))
                }
            } header: {
                Text(NSLocalizedString("settings.planner.scheduling.header", comment: "Scheduling"))
            } footer: {
                Text(NSLocalizedString("settings.planner.scheduling.footer", comment: "How far ahead to schedule tasks and study sessions"))
            }
            
            Section {
                Toggle(isOn: $settings.enableAIPlannerStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.planner.ai", comment: "AI-Powered Planning"))
                        Text(NSLocalizedString("settings.planner.ai.detail", comment: "Use intelligent suggestions for task scheduling"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $settings.autoScheduleBreaksStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.planner.auto_breaks", comment: "Auto-Schedule Breaks"))
                        Text(NSLocalizedString("settings.planner.auto_breaks.detail", comment: "Automatically add break periods between study sessions"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("settings.planner.intelligence.header", comment: "Intelligence"))
            }
            
            Section {
                Toggle(isOn: $settings.showEnergyPanelStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.planner.energy_tracking", comment: "Energy Tracking"))
                        Text(NSLocalizedString("settings.planner.energy_tracking.detail", comment: "Track and optimize based on your energy levels"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $settings.trackStudyHoursStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.planner.track_hours", comment: "Track Study Hours"))
                        Text(NSLocalizedString("settings.planner.track_hours.detail", comment: "Monitor total time spent studying"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("settings.planner.tracking.header", comment: "Tracking"))
            }
            
            Section {
                Picker(selection: Binding(
                    get: { courseDisplayMode },
                    set: { newMode in
                        UserDefaults.standard.set(newMode.rawValue, forKey: "courseDisplayMode")
                    }
                )) {
                    Text(NSLocalizedString("settings.courses.display.name", comment: "Name")).tag(CourseDisplayMode.name)
                    Text(NSLocalizedString("settings.courses.display.code", comment: "Code")).tag(CourseDisplayMode.code)
                    Text(NSLocalizedString("settings.courses.display.both", comment: "Both")).tag(CourseDisplayMode.both)
                } label: {
                    Text(NSLocalizedString("settings.courses.display", comment: "Course Display"))
                }
            } header: {
                Text(NSLocalizedString("settings.courses.display.header", comment: "Courses"))
            } footer: {
                Text(NSLocalizedString("settings.courses.display.footer", comment: "How to display course information throughout the app"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("settings.category.courses_planner", comment: "Courses & Planner"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var plannerHorizon: PlannerHorizon {
        PlannerHorizon(rawValue: settings.plannerHorizonStorage) ?? .twoWeeks
    }
    
    private var courseDisplayMode: CourseDisplayMode {
        CourseDisplayMode.from(userDefaults: .standard)
    }
}

// MARK: - Planner Horizon

enum PlannerHorizon: String {
    case oneWeek = "1w"
    case twoWeeks = "2w"
    case oneMonth = "1m"
}

#Preview {
    NavigationStack {
        CoursesPlannerSettingsView()
            .environmentObject(AppSettingsModel.shared)
    }
}
#endif
