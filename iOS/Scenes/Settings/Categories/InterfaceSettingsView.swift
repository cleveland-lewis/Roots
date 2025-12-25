import SwiftUI
#if os(iOS)

struct InterfaceSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.layoutMetrics) private var layoutMetrics
    
    private var isPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        List {
            // Tab Bar Pages Section
            Section {
                ForEach(availableTabs, id: \.self) { tab in
                    let isStarred = settings.starredTabs.contains(tab)
                    let isRequired = TabRegistry.definition(for: tab)?.isSystemRequired ?? false
                    let canToggleOff = isStarred && !isRequired
                    let canToggleOn = !isStarred && settings.starredTabs.count < 5
                    
                    Toggle(isOn: Binding(
                        get: { isStarred },
                        set: { newValue in
                            toggleTab(tab, enabled: newValue)
                        }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 18))
                                .frame(width: 28)
                                .foregroundColor(isRequired ? .green : .primary)
                            Text(tab.title)
                            if isRequired {
                                Spacer()
                                Text("Required")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled((isStarred && isRequired) || (!isStarred && !canToggleOn))
                    .listRowInsets(EdgeInsets(
                        top: layoutMetrics.listRowVerticalPadding,
                        leading: 16,
                        bottom: layoutMetrics.listRowVerticalPadding,
                        trailing: 16
                    ))
                }
            } header: {
                Text("Tab Bar Pages")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select up to 5 pages to show in the tab bar. All pages remain accessible via the menu.")
                    if settings.starredTabs.count >= 5 {
                        Text("Maximum of 5 tabs reached. Disable a tab to enable another.")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Layout Section
            Section {
                if isPad {
                    Toggle(isOn: $settings.showSidebarByDefaultStorage) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Show Sidebar")
                            Text("Always display the navigation sidebar on iPad")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: settings.showSidebarByDefaultStorage) { _, _ in
                        settings.save()
                    }
                    .listRowInsets(EdgeInsets(
                        top: layoutMetrics.listRowVerticalPadding,
                        leading: 16,
                        bottom: layoutMetrics.listRowVerticalPadding,
                        trailing: 16
                    ))
                }
                
                Toggle(isOn: $settings.compactModeStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compact Mode")
                        Text("Use denser layout with less spacing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: settings.compactModeStorage) { _, _ in
                    settings.save()
                }
                .listRowInsets(EdgeInsets(
                    top: layoutMetrics.listRowVerticalPadding,
                    leading: 16,
                    bottom: layoutMetrics.listRowVerticalPadding,
                    trailing: 16
                ))
                
                Toggle(isOn: $settings.largeTapTargetsStorage) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Large Tap Targets")
                        Text("Increase button and control sizes for easier tapping")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: settings.largeTapTargetsStorage) { _, _ in
                    settings.save()
                }
                .listRowInsets(EdgeInsets(
                    top: layoutMetrics.listRowVerticalPadding,
                    leading: 16,
                    bottom: layoutMetrics.listRowVerticalPadding,
                    trailing: 16
                ))
            } header: {
                Text("Layout")
            } footer: {
                Text("Layout changes apply immediately to all screens.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Interface")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var availableTabs: [RootTab] {
        TabRegistry.allTabs.map { $0.id }
    }
    
    private func toggleTab(_ tab: RootTab, enabled: Bool) {
        guard let definition = TabRegistry.definition(for: tab) else { return }
        
        // Prevent disabling required tabs
        if definition.isSystemRequired && !enabled {
            return
        }
        
        var currentTabs = settings.starredTabs
        
        if enabled {
            // Add tab (if not at limit)
            if currentTabs.count < 5 && !currentTabs.contains(tab) {
                currentTabs.append(tab)
            }
        } else {
            // Remove tab (if not required)
            if !definition.isSystemRequired {
                currentTabs.removeAll { $0 == tab }
            }
        }
        
        settings.starredTabs = currentTabs
        settings.save()
    }
}

#Preview {
    NavigationStack {
        InterfaceSettingsView()
            .environmentObject(AppSettingsModel.shared)
    }
}
#endif
