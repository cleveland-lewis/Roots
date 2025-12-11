import SwiftUI

extension SettingsPane_Interface {
    // Tab visibility editor
    var tabEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tab Bar Pages")
                .font(DesignSystem.Typography.subHeader)
            Text("Choose which pages appear in the floating tab bar and reorder them.")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)

            TabEditorView()
        }
    }
}

struct TabEditorView: View {
    @EnvironmentObject private var settings: AppSettingsModel
    @State private var list: [RootTab] = []

    var body: some View {
        VStack {
            List {
                ForEach(list, id: \.self) { tab in
                    HStack {
                        Image(systemName: tab.systemImage)
                        Text(tab.title)
                        Spacer()
                        Toggle("", isOn: Binding(get: { settings.visibleTabs.contains(tab) }, set: { new in
                            var current = settings.visibleTabs
                            if new {
                                if !current.contains(tab) { current.append(tab) }
                            } else {
                                current.removeAll { $0 == tab }
                            }
                            settings.visibleTabs = current
                            settings.save()
                        }))
                        .labelsHidden()
                    }
                }
                .onMove(perform: move)
            }
            .frame(height: 280)

            HStack {
                Button("Restore Defaults") {
                    settings.visibleTabs = [.dashboard, .calendar, .planner, .assignments, .courses, .grades]
                    settings.tabOrder = settings.visibleTabs
                }
                Spacer()
            }
        }
        .onAppear { list = RootTab.allCases }
    }

    private func move(from: IndexSet, to: Int) {
        var order = settings.tabOrder
        order.move(fromOffsets: from, toOffset: to)
        settings.tabOrder = order
    }
}
