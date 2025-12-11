import SwiftUI

struct PlannerSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel

    var body: some View {
        Form {
            Section("Planner") {
                Toggle("Enable AI Planner", isOn: Binding(
                    get: { settings.enableAIPlanner },
                    set: { newValue in settings.enableAIPlanner = newValue; settings.save() }
                ))
                .toggleStyle(.switch)
                .onChange(of: settings.enableAIPlanner) { _, _ in settings.save() }

                Picker("Default Planning Horizon", selection: Binding(
                    get: { settings.plannerHorizon },
                    set: { newValue in settings.plannerHorizon = newValue; settings.save() }
                )) {
                    Text("1 Week").tag("1w")
                    Text("2 Weeks").tag("2w")
                    Text("1 Month").tag("1m")
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.plannerHorizon) { _, _ in settings.save() }

                Picker("Default Planning Horizon", selection: Binding(
                    get: { settings.plannerHorizon },
                    set: { newValue in settings.plannerHorizon = newValue; settings.save() }
                )) {
                    Text("1 Week").tag("1w")
                    Text("2 Weeks").tag("2w")
                    Text("1 Month").tag("1m")
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }
}
