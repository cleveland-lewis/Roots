import SwiftUI

struct SettingsPane_General: View {
    @EnvironmentObject private var settings: AppSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Enable hover wiggle", isOn: $settings.wiggleOnHover)
                    Toggle("Keep glass accents active", isOn: $settings.enableGlassEffects)
                }
                .toggleStyle(.switch)
            } label: {
                Label("Interaction", systemImage: "hand.point.up.left.fill")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Tab bar mode", selection: $settings.tabBarMode) {
                        ForEach(TabBarMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Sidebar behavior", selection: $settings.sidebarBehavior) {
                        ForEach(SidebarBehavior.allCases) { behavior in
                            Text(behavior.label).tag(behavior)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Automatic keeps the sidebar responsive to window size while still letting it stay pinned when you want it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            } label: {
                Label("Layout", systemImage: "sidebar.leading")
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: 640)
    }
}
