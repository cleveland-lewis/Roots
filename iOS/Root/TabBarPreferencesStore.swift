#if os(iOS)
import SwiftUI
import Combine

/// Defines all available iOS tabs with their metadata
struct TabDefinition {
    let id: RootTab
    let title: String
    let systemImage: String
    let defaultEnabled: Bool
    
    static let allTabs: [TabDefinition] = [
        TabDefinition(id: .timer, title: "Timer", systemImage: "timer", defaultEnabled: true),
        TabDefinition(id: .dashboard, title: "Dashboard", systemImage: "square.grid.2x2", defaultEnabled: true),
        TabDefinition(id: .planner, title: "Planner", systemImage: "pencil.and.list.clipboard", defaultEnabled: false),
        TabDefinition(id: .assignments, title: "Assignments", systemImage: "slider.horizontal.3", defaultEnabled: false),
        TabDefinition(id: .courses, title: "Courses", systemImage: "book.closed", defaultEnabled: false),
        TabDefinition(id: .practice, title: "Practice", systemImage: "list.clipboard", defaultEnabled: false),
        TabDefinition(id: .settings, title: "Settings", systemImage: "gearshape", defaultEnabled: true)
    ]
    
    static let canonicalOrder: [RootTab] = [
        .timer, .dashboard, .planner, .assignments, .courses, .practice, .settings
    ]
}

/// Manages tab bar customization state with persistence and validation
final class TabBarPreferencesStore: ObservableObject {
    private let enabledTabsKey = "roots.ios.tabbar.enabled"
    private let selectedTabKey = "roots.ios.tabbar.selected"
    
    @Published private(set) var enabledTabs: Set<RootTab>
    @Published var selectedTab: RootTab
    
    init() {
        // Load enabled tabs from storage
        let loadedEnabledTabs: Set<RootTab>
        if let raw = UserDefaults.standard.string(forKey: enabledTabsKey) {
            let loaded = Set(raw.split(separator: ",").compactMap { RootTab(rawValue: String($0)) })
            loadedEnabledTabs = loaded.isEmpty ? Self.defaultEnabledTabs() : loaded
        } else {
            loadedEnabledTabs = Self.defaultEnabledTabs()
        }
        
        // Ensure at least one tab is enabled
        let finalEnabledTabs = loadedEnabledTabs.isEmpty ? Self.defaultEnabledTabs() : loadedEnabledTabs
        self.enabledTabs = finalEnabledTabs
        
        // Compute first enabled tab
        let firstTab = TabDefinition.canonicalOrder.first(where: { finalEnabledTabs.contains($0) }) ?? .dashboard
        
        // Load selected tab from storage
        if let raw = UserDefaults.standard.string(forKey: selectedTabKey),
           let tab = RootTab(rawValue: raw),
           finalEnabledTabs.contains(tab) {
            self.selectedTab = tab
        } else {
            self.selectedTab = firstTab
        }
    }
    
    /// Returns the list of enabled tabs in canonical order
    func effectiveTabsInOrder() -> [RootTab] {
        TabDefinition.canonicalOrder.filter { enabledTabs.contains($0) }
    }
    
    /// Sets the enabled state for a specific tab
    func setEnabled(_ enabled: Bool, for tab: RootTab) {
        var newEnabled = enabledTabs
        
        if enabled {
            newEnabled.insert(tab)
        } else {
            newEnabled.remove(tab)
            
            // Enforce minimum-one-enabled rule
            if newEnabled.isEmpty {
                return
            }
            
            // If disabling the currently selected tab, switch to a safe fallback
            if tab == selectedTab {
                selectedTab = firstEnabledTab(excluding: tab) ?? .dashboard
                persist()
            }
        }
        
        enabledTabs = newEnabled
        persist()
    }
    
    /// Restores all tabs to their default states
    func restoreDefaults() {
        enabledTabs = Self.defaultEnabledTabs()
        selectedTab = .dashboard
        persist()
    }
    
    /// Checks if a specific tab is enabled
    func isEnabled(_ tab: RootTab) -> Bool {
        enabledTabs.contains(tab)
    }
    
    // MARK: - Private helpers
    
    private static func defaultEnabledTabs() -> Set<RootTab> {
        Set(TabDefinition.allTabs.filter { $0.defaultEnabled }.map { $0.id })
    }
    
    private func firstEnabledTab(excluding: RootTab? = nil) -> RootTab? {
        TabDefinition.canonicalOrder.first { tab in
            enabledTabs.contains(tab) && tab != excluding
        }
    }
    
    private func persist() {
        let raw = enabledTabs.map { $0.rawValue }.joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: enabledTabsKey)
        UserDefaults.standard.set(selectedTab.rawValue, forKey: selectedTabKey)
    }
}
#endif
