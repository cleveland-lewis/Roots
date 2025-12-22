import XCTest
@testable import Roots

#if os(iOS)
final class TabBarPreferencesStoreTests: XCTestCase {
    var store: TabBarPreferencesStore!
    
    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        let enabledKey = "roots.ios.tabbar.enabled"
        let selectedKey = "roots.ios.tabbar.selected"
        UserDefaults.standard.removeObject(forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: selectedKey)
        store = TabBarPreferencesStore()
    }
    
    override func tearDown() {
        store = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialStateHasDefaultTabs() {
        // Timer, Dashboard, and Settings should be enabled by default
        XCTAssertTrue(store.isEnabled(.timer))
        XCTAssertTrue(store.isEnabled(.dashboard))
        XCTAssertTrue(store.isEnabled(.settings))
        XCTAssertFalse(store.isEnabled(.planner))
        XCTAssertFalse(store.isEnabled(.assignments))
    }
    
    func testInitialSelectedTabIsValid() {
        let tabs = store.effectiveTabsInOrder()
        XCTAssertTrue(tabs.contains(store.selectedTab))
    }
    
    // MARK: - Ordering Tests
    
    func testEffectiveTabsInOrderReturnsCanonicalOrder() {
        store.setEnabled(true, for: .planner)
        store.setEnabled(true, for: .assignments)
        
        let tabs = store.effectiveTabsInOrder()
        
        // Should follow canonical order: timer, dashboard, planner, assignments, courses, practice, settings
        var timerIndex: Int?
        var dashboardIndex: Int?
        var plannerIndex: Int?
        var assignmentsIndex: Int?
        var settingsIndex: Int?
        
        for (idx, tab) in tabs.enumerated() {
            switch tab {
            case .timer: timerIndex = idx
            case .dashboard: dashboardIndex = idx
            case .planner: plannerIndex = idx
            case .assignments: assignmentsIndex = idx
            case .settings: settingsIndex = idx
            default: break
            }
        }
        
        XCTAssertNotNil(timerIndex)
        XCTAssertNotNil(dashboardIndex)
        XCTAssertNotNil(plannerIndex)
        XCTAssertNotNil(assignmentsIndex)
        XCTAssertNotNil(settingsIndex)
        
        XCTAssertLessThan(timerIndex!, dashboardIndex!)
        XCTAssertLessThan(dashboardIndex!, plannerIndex!)
        XCTAssertLessThan(plannerIndex!, assignmentsIndex!)
        XCTAssertLessThan(assignmentsIndex!, settingsIndex!)
    }
    
    func testEffectiveTabsFiltersByEnabled() {
        store.setEnabled(false, for: .timer)
        
        let tabs = store.effectiveTabsInOrder()
        XCTAssertFalse(tabs.contains(.timer))
        XCTAssertTrue(tabs.contains(.dashboard))
        XCTAssertTrue(tabs.contains(.settings))
    }
    
    // MARK: - Enable/Disable Tests
    
    func testSetEnabledAddsTab() {
        XCTAssertFalse(store.isEnabled(.planner))
        
        store.setEnabled(true, for: .planner)
        
        XCTAssertTrue(store.isEnabled(.planner))
        XCTAssertTrue(store.effectiveTabsInOrder().contains(.planner))
    }
    
    func testSetDisabledRemovesTab() {
        XCTAssertTrue(store.isEnabled(.timer))
        
        store.setEnabled(false, for: .timer)
        
        XCTAssertFalse(store.isEnabled(.timer))
        XCTAssertFalse(store.effectiveTabsInOrder().contains(.timer))
    }
    
    func testCannotDisableAllTabs() {
        // Start with only Dashboard enabled
        store.setEnabled(false, for: .timer)
        store.setEnabled(false, for: .settings)
        
        let tabsBeforeAttempt = store.effectiveTabsInOrder()
        XCTAssertEqual(tabsBeforeAttempt.count, 1)
        XCTAssertTrue(store.isEnabled(.dashboard))
        
        // Attempt to disable the last remaining tab
        store.setEnabled(false, for: .dashboard)
        
        // Should still be enabled (minimum-one-enabled enforcement)
        XCTAssertTrue(store.isEnabled(.dashboard))
        XCTAssertEqual(store.effectiveTabsInOrder().count, 1)
    }
    
    // MARK: - Selection Fallback Tests
    
    func testDisablingSelectedTabTriggersValidFallback() {
        // Select timer
        store.selectedTab = .timer
        XCTAssertEqual(store.selectedTab, .timer)
        
        // Disable timer
        store.setEnabled(false, for: .timer)
        
        // Should fallback to another enabled tab in canonical order
        let enabledTabs = store.effectiveTabsInOrder()
        XCTAssertTrue(enabledTabs.contains(store.selectedTab))
        XCTAssertNotEqual(store.selectedTab, .timer)
    }
    
    func testFallbackSelectsFirstInCanonicalOrder() {
        // Enable only Dashboard and Settings
        store.setEnabled(false, for: .timer)
        store.selectedTab = .dashboard
        
        // Disable Dashboard
        store.setEnabled(false, for: .dashboard)
        
        // Should fallback to Settings (next in canonical order that's enabled)
        XCTAssertEqual(store.selectedTab, .settings)
    }
    
    // MARK: - Restore Defaults Tests
    
    func testRestoreDefaultsResetsAllTabs() {
        // Change some states
        store.setEnabled(true, for: .planner)
        store.setEnabled(true, for: .assignments)
        store.setEnabled(false, for: .timer)
        store.selectedTab = .planner
        
        // Restore defaults
        store.restoreDefaults()
        
        // Check defaults are restored
        XCTAssertTrue(store.isEnabled(.timer))
        XCTAssertTrue(store.isEnabled(.dashboard))
        XCTAssertTrue(store.isEnabled(.settings))
        XCTAssertFalse(store.isEnabled(.planner))
        XCTAssertFalse(store.isEnabled(.assignments))
        XCTAssertFalse(store.isEnabled(.courses))
        XCTAssertFalse(store.isEnabled(.practice))
        XCTAssertEqual(store.selectedTab, .dashboard)
    }
    
    // MARK: - Persistence Tests
    
    func testPersistenceAcrossInstances() {
        // Enable a tab
        store.setEnabled(true, for: .planner)
        store.selectedTab = .planner
        
        // Create a new instance (simulating app restart)
        let newStore = TabBarPreferencesStore()
        
        // Check state was persisted
        XCTAssertTrue(newStore.isEnabled(.planner))
        XCTAssertEqual(newStore.selectedTab, .planner)
    }
    
    func testPersistenceRestoresDefaults() {
        // Start fresh with no stored data
        let enabledKey = "roots.ios.tabbar.enabled"
        let selectedKey = "roots.ios.tabbar.selected"
        UserDefaults.standard.removeObject(forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: selectedKey)
        
        let newStore = TabBarPreferencesStore()
        
        // Should have defaults
        XCTAssertTrue(newStore.isEnabled(.timer))
        XCTAssertTrue(newStore.isEnabled(.dashboard))
        XCTAssertTrue(newStore.isEnabled(.settings))
    }
    
    func testPersistenceHandlesInvalidSelectedTab() {
        // Manually set an invalid selected tab in storage
        UserDefaults.standard.set("planner", forKey: "roots.ios.tabbar.selected")
        UserDefaults.standard.set("timer,dashboard,settings", forKey: "roots.ios.tabbar.enabled")
        
        // Create store - should fallback to valid tab since planner is not enabled
        let newStore = TabBarPreferencesStore()
        
        let enabledTabs = newStore.effectiveTabsInOrder()
        XCTAssertTrue(enabledTabs.contains(newStore.selectedTab))
        XCTAssertNotEqual(newStore.selectedTab, .planner)
    }
    
    // MARK: - Edge Case Tests
    
    func testMultipleTogglesStable() {
        // Toggle the same tab multiple times
        for _ in 0..<5 {
            store.setEnabled(true, for: .planner)
            store.setEnabled(false, for: .planner)
        }
        
        XCTAssertFalse(store.isEnabled(.planner))
        
        store.setEnabled(true, for: .planner)
        XCTAssertTrue(store.isEnabled(.planner))
    }
    
    func testEnablingAlreadyEnabledTabIsIdempotent() {
        XCTAssertTrue(store.isEnabled(.dashboard))
        
        store.setEnabled(true, for: .dashboard)
        
        XCTAssertTrue(store.isEnabled(.dashboard))
        XCTAssertEqual(store.effectiveTabsInOrder().filter { $0 == .dashboard }.count, 1)
    }
    
    func testDisablingAlreadyDisabledTabIsIdempotent() {
        XCTAssertFalse(store.isEnabled(.planner))
        
        store.setEnabled(false, for: .planner)
        
        XCTAssertFalse(store.isEnabled(.planner))
    }
}
#endif
