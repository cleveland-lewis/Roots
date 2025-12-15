#if os(macOS)
import SwiftUI

struct PlannerSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel

    var body: some View {
        Form {
            Section(NSLocalizedString("planner.settings.section.title", comment: "Planner settings section title")) {
                Toggle(NSLocalizedString("planner.settings.enable_ai", comment: "Enable AI Planner toggle label"), isOn: Binding(
                    get: { settings.enableAIPlanner },
                    set: { newValue in settings.enableAIPlanner = newValue; settings.save() }
                ))
                .toggleStyle(.switch)
                .onChange(of: settings.enableAIPlanner) { _, _ in settings.save() }

                Picker(NSLocalizedString("planner.settings.horizon", comment: "Default planning horizon picker label"), selection: Binding(
                    get: { settings.plannerHorizon },
                    set: { newValue in settings.plannerHorizon = newValue; settings.save() }
                )) {
                    Text(NSLocalizedString("planner.settings.horizon.one_week", comment: "1 week horizon option")).tag("1w")
                    Text(NSLocalizedString("planner.settings.horizon.two_weeks", comment: "2 weeks horizon option")).tag("2w")
                    Text(NSLocalizedString("planner.settings.horizon.one_month", comment: "1 month horizon option")).tag("1m")
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.plannerHorizon) { _, _ in settings.save() }

                Picker(NSLocalizedString("planner.settings.horizon", comment: "Default planning horizon picker label"), selection: Binding(
                    get: { settings.plannerHorizon },
                    set: { newValue in settings.plannerHorizon = newValue; settings.save() }
                )) {
                    Text(NSLocalizedString("planner.settings.horizon.one_week", comment: "1 week horizon option")).tag("1w")
                    Text(NSLocalizedString("planner.settings.horizon.two_weeks", comment: "2 weeks horizon option")).tag("2w")
                    Text(NSLocalizedString("planner.settings.horizon.one_month", comment: "1 month horizon option")).tag("1m")
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }
}
#endif
