#if os(macOS)
import SwiftUI

struct PlannerSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel

    var body: some View {
        Form {
            Section(String(localized: "planner.settings.section.title")) {
                Toggle(String(localized: "planner.settings.enable_ai"), isOn: Binding(
                    get: { settings.enableAIPlanner },
                    set: { newValue in settings.enableAIPlanner = newValue; settings.save() }
                ))
                .toggleStyle(.switch)
                .onChange(of: settings.enableAIPlanner) { _, _ in settings.save() }

                Picker(String(localized: "planner.settings.horizon"), selection: Binding(
                    get: { settings.plannerHorizon },
                    set: { newValue in settings.plannerHorizon = newValue; settings.save() }
                )) {
                    Text(String(localized: "planner.settings.horizon.one_week")).tag("1w")
                    Text(String(localized: "planner.settings.horizon.two_weeks")).tag("2w")
                    Text(String(localized: "planner.settings.horizon.one_month")).tag("1m")
                    Text(String(localized: "planner.settings.horizon.two_months")).tag("2m")
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }
}
#endif
