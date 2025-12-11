import SwiftUI

struct SettingsPane_General: View {
    @EnvironmentObject private var settings: AppSettingsModel

    var body: some View {
        Form {
            Section("Interaction") {
                Toggle("Hover Effects", isOn: $settings.wiggleOnHover)
                    .onChange(of: settings.wiggleOnHover) { _, _ in settings.save() }
                Toggle("Glass Accents", isOn: $settings.enableGlassEffects)
                    .onChange(of: settings.enableGlassEffects) { _, _ in settings.save() }
            }

            Section("Layout") {
                Picker("Tab Style", selection: $settings.tabBarMode) {
                    ForEach(TabBarMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.tabBarMode) { _, _ in settings.save() }

                Picker("Sidebar", selection: $settings.sidebarBehavior) {
                    ForEach(SidebarBehavior.allCases) { behavior in
                        Text(behavior.label).tag(behavior)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: settings.sidebarBehavior) { _, _ in settings.save() }

                Picker("Compact Density", selection: $settings.compactMode) {
                    Text("Off").tag(false)
                    Text("On").tag(true)
                }
                .onChange(of: settings.compactMode) { _, _ in settings.save() }
            }

            Section("Assignments") {
                Picker("Swipe Leading", selection: $settings.assignmentSwipeLeading) {
                    ForEach(AssignmentSwipeAction.allCases) { action in
                        Text(action.label).tag(action)
                    }
                }
                .onChange(of: settings.assignmentSwipeLeading) { _, _ in settings.save() }

                Picker("Swipe Trailing", selection: $settings.assignmentSwipeTrailing) {
                    ForEach(AssignmentSwipeAction.allCases) { action in
                        Text(action.label).tag(action)
                    }
                }
                .onChange(of: settings.assignmentSwipeTrailing) { _, _ in settings.save() }
            }
        }
        .formStyle(.grouped)
    }
}
