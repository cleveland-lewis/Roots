import Foundation
import SwiftUI
import Combine

// MARK: - Tab Configuration Model (Platform-Agnostic)

/// Defines a single tab's metadata and behavior
/// Required for all tabs to ensure consistency across platforms
public struct TabDefinition: Identifiable, Hashable {
    public let id: RootTab
    public let icon: String
    public let title: String
    public let defaultEnabled: Bool
    public let isSystemRequired: Bool // Cannot be disabled by user
    
    public init(
        id: RootTab,
        icon: String,
        title: String,
        defaultEnabled: Bool = true,
        isSystemRequired: Bool = false
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.defaultEnabled = defaultEnabled
        self.isSystemRequired = isSystemRequired
        
        #if DEBUG
        // Fail loudly in debug if required fields are missing
        assert(!icon.isEmpty, "Tab \(id.rawValue) missing icon")
        assert(!title.isEmpty, "Tab \(id.rawValue) missing title")
        #endif
    }
}

// MARK: - Tab Registry (Single Source of Truth)

/// Central registry of all available tabs
/// Shared between iOS and iPadOS - only presentation differs
public struct TabRegistry {
    
    /// All available tabs with their metadata
    /// Order determines default display order
    public static let allTabs: [TabDefinition] = [
        TabDefinition(id: .dashboard, icon: "square.grid.2x2", title: "Dashboard", defaultEnabled: true),
        TabDefinition(id: .timer, icon: "timer", title: "Timer", defaultEnabled: true),
        TabDefinition(id: .planner, icon: "pencil.and.list.clipboard", title: "Planner", defaultEnabled: false),
        TabDefinition(id: .assignments, icon: "slider.horizontal.3", title: "Assignments", defaultEnabled: false),
        TabDefinition(id: .courses, icon: "book.closed", title: "Courses", defaultEnabled: false),
        TabDefinition(id: .grades, icon: "number.circle", title: "Grades", defaultEnabled: false),
        TabDefinition(id: .calendar, icon: "calendar", title: "Calendar", defaultEnabled: false),
        TabDefinition(id: .flashcards, icon: "rectangle.stack", title: "Flashcards", defaultEnabled: false),
        TabDefinition(id: .practice, icon: "list.clipboard", title: "Practice", defaultEnabled: false),
        // CRITICAL: Settings must always be last and system-required
        TabDefinition(id: .settings, icon: "gearshape", title: "Settings", defaultEnabled: true, isSystemRequired: true)
    ]
    
    /// Quick lookup by tab ID
    private static let tabLookup: [RootTab: TabDefinition] = Dictionary(
        uniqueKeysWithValues: allTabs.map { ($0.id, $0) }
    )
    
    /// Get definition for a specific tab
    public static func definition(for tab: RootTab) -> TabDefinition? {
        return tabLookup[tab]
    }
    
    /// Default tabs for new users (platform-agnostic)
    public static let defaultEnabledTabs: [RootTab] = allTabs
        .filter { $0.defaultEnabled }
        .map { $0.id }
    
    /// Tabs that cannot be disabled (always visible)
    public static let systemRequiredTabs: [RootTab] = allTabs
        .filter { $0.isSystemRequired }
        .map { $0.id }
    
    /// Safe fallback tab if current selection becomes invalid
    public static let fallbackTab: RootTab = .dashboard
}

// MARK: - Tab Bar Preferences (User Customization)

/// Manages user's tab bar customization preferences
/// Platform-agnostic state that works for both iOS and iPadOS
@MainActor
public final class TabBarPreferencesStore: ObservableObject {
    
    @Published public var selectedTab: RootTab
    
    private let settings: AppSettingsModel
    
    internal init(settings: AppSettingsModel) {
        self.settings = settings
        self.selectedTab = TabRegistry.fallbackTab
    }
    
    // MARK: - Tab Visibility (with Guards)
    
    /// Get user's visible tabs with system-required tabs enforced
    public func visibleTabs() -> [RootTab] {
        var tabs = settings.effectiveVisibleTabs
        
        // GUARD: Always include system-required tabs (Settings)
        for requiredTab in TabRegistry.systemRequiredTabs {
            if !tabs.contains(requiredTab) {
                tabs.append(requiredTab)
                
                #if DEBUG
                assertionFailure("⚠️ System-required tab .\(requiredTab.rawValue) was missing from visible tabs. Auto-corrected.")
                #endif
            }
        }
        
        return tabs
    }
    
    /// Get tabs in user's preferred order
    public func orderedTabs() -> [RootTab] {
        var tabs = settings.tabOrder
        
        // GUARD: Ensure Settings is always included
        for requiredTab in TabRegistry.systemRequiredTabs {
            if !tabs.contains(requiredTab) {
                tabs.append(requiredTab)
                
                #if DEBUG
                assertionFailure("⚠️ System-required tab .\(requiredTab.rawValue) was missing from tab order. Auto-corrected.")
                #endif
            }
        }
        
        return tabs
    }
    
    /// Get effective tabs (visible + ordered, filtered by registry)
    public func effectiveTabsInOrder() -> [RootTab] {
        let visible = Set(visibleTabs())
        let ordered = orderedTabs()
        
        // Filter ordered tabs to only include visible ones
        var result = ordered.filter { visible.contains($0) && TabRegistry.definition(for: $0) != nil }
        
        // GUARD: Ensure we have at least the fallback tab
        if result.isEmpty {
            result = [TabRegistry.fallbackTab]
            
            #if DEBUG
            assertionFailure("⚠️ No valid tabs found. Falling back to \(TabRegistry.fallbackTab.rawValue).")
            #endif
        }
        
        // GUARD: Ensure Settings is always present
        for requiredTab in TabRegistry.systemRequiredTabs {
            if !result.contains(requiredTab) {
                result.append(requiredTab)
            }
        }
        
        return result
    }
    
    // MARK: - Tab Modification (with Guards)
    
    /// Set tab visibility (enforces system-required tabs)
    public func setTabVisibility(_ tab: RootTab, visible: Bool) {
        // GUARD: Prevent disabling system-required tabs
        guard let definition = TabRegistry.definition(for: tab) else {
            #if DEBUG
            assertionFailure("⚠️ Attempted to modify unknown tab: \(tab.rawValue)")
            #endif
            return
        }
        
        if definition.isSystemRequired && !visible {
            #if DEBUG
            assertionFailure("⚠️ Attempted to disable system-required tab: \(tab.rawValue). Ignoring.")
            print("⚠️ GUARD: Cannot disable \(tab.rawValue) - it is system-required.")
            #endif
            // Silently ignore - do not modify visibility
            return
        }
        
        // Apply change
        var currentTabs = settings.visibleTabs
        if visible {
            if !currentTabs.contains(tab) {
                currentTabs.append(tab)
            }
        } else {
            currentTabs.removeAll { $0 == tab }
        }
        settings.visibleTabs = currentTabs
        settings.save()
    }
    
    /// Update tab order
    public func setTabOrder(_ tabs: [RootTab]) {
        var order = tabs
        
        // GUARD: Ensure system-required tabs are included
        for requiredTab in TabRegistry.systemRequiredTabs {
            if !order.contains(requiredTab) {
                order.append(requiredTab)
                
                #if DEBUG
                assertionFailure("⚠️ System-required tab .\(requiredTab.rawValue) was missing from new order. Auto-added.")
                #endif
            }
        }
        
        settings.tabOrder = order
        settings.save()
    }
    
    /// Reset to defaults
    public func resetToDefaults() {
        settings.visibleTabs = TabRegistry.defaultEnabledTabs
        settings.tabOrder = TabRegistry.allTabs.map { $0.id }
        settings.save()
    }
    
    // MARK: - Selection (with Safety)
    
    /// Safely select a tab (validates it exists and is visible)
    public func selectTab(_ tab: RootTab) {
        let validTabs = effectiveTabsInOrder()
        
        if validTabs.contains(tab) {
            selectedTab = tab
        } else {
            // Tab not available, fall back to safe default
            selectedTab = TabRegistry.fallbackTab
            
            #if DEBUG
            assertionFailure("⚠️ Attempted to select unavailable tab: \(tab.rawValue). Falling back to \(TabRegistry.fallbackTab.rawValue).")
            #endif
        }
    }
    
    /// Ensure current selection is valid (call after tab changes)
    public func validateSelection() {
        let validTabs = effectiveTabsInOrder()
        
        if !validTabs.contains(selectedTab) {
            selectedTab = validTabs.first ?? TabRegistry.fallbackTab
            
            #if DEBUG
            print("ℹ️ Current selection invalid. Reset to \(selectedTab.rawValue).")
            #endif
        }
    }
}
