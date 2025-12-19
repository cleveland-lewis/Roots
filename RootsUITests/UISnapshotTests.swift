//
//  UISnapshotTests.swift
//  RootsUITests
//

import XCTest

final class UISnapshotTests: XCTestCase {
    private let snapshotter = SnapshotAsserter()

    @MainActor
    func testCriticalScreensAndOverlays() throws {
        for config in SnapshotConfiguration.defaults {
            let app = XCUIApplication.snapshotApp(config: config)
            app.launch()

            XCTAssertTrue(waitForPage("dashboard", in: app), "Dashboard did not render")

            captureCalendar(in: app, config: config)
            capturePlanner(in: app, config: config)
            captureTimer(in: app, config: config)
            captureSettings(in: app, config: config)
            captureOverlays(in: app, config: config)

            app.terminate()
        }
    }

    // MARK: - Screen capture helpers

    private func captureCalendar(in app: XCUIApplication, config: SnapshotConfiguration) {
        switchToTab("calendar", in: app)
        selectCalendarMode("Month", in: app)
        snapshotter.assertSnapshot(app: app, name: "calendar-month", config: config)

        selectCalendarMode("Week", in: app)
        snapshotter.assertSnapshot(app: app, name: "calendar-week", config: config)

        selectCalendarMode("Year", in: app)
        snapshotter.assertSnapshot(app: app, name: "calendar-year", config: config)
    }

    private func capturePlanner(in app: XCUIApplication, config: SnapshotConfiguration) {
        switchToTab("planner", in: app)
        snapshotter.assertSnapshot(app: app, name: "planner", config: config)
    }

    private func captureTimer(in app: XCUIApplication, config: SnapshotConfiguration) {
        switchToTab("timer", in: app)
        snapshotter.assertSnapshot(app: app, name: "timer", config: config)
    }

    private func captureSettings(in app: XCUIApplication, config: SnapshotConfiguration) {
        openSettings(app)
        selectSettingsPane("General", in: app)
        snapshotter.assertSnapshot(app: app, name: "settings-general", config: config)

        // Calendar + Reminders act as integrations coverage.
        selectSettingsPane("Calendar", in: app)
        snapshotter.assertSnapshot(app: app, name: "settings-calendar", config: config)

        selectSettingsPane("Reminders", in: app)
        snapshotter.assertSnapshot(app: app, name: "settings-reminders", config: config)
    }

    private func captureOverlays(in app: XCUIApplication, config: SnapshotConfiguration) {
        // Confirmation sheet from Settings → Reset All Data.
        selectSettingsPane("General", in: app)
        let resetButton = app.buttons["Reset All Data"]
        if resetButton.waitForExistence(timeout: 3) {
            resetButton.click()
            if app.sheets.firstMatch.waitForExistence(timeout: 4) {
                snapshotter.assertSnapshot(app: app, name: "overlay-confirmation", config: config)
                app.buttons["Cancel"].firstMatch.clickIfExists()
            }
        }

        // Calendar modal overlay (new event)
        switchToTab("calendar", in: app)
        if let addButton = app.buttons.matching(identifier: "plus").firstMatchIfExists(timeout: 2) {
            addButton.click()
        } else {
            let addLabelButton = app.buttons["Add"]
            if addLabelButton.waitForExistence(timeout: 2) {
                addLabelButton.click()
            } else if app.buttons.firstMatch.waitForExistence(timeout: 2) {
                app.buttons.firstMatch.click()
            }
        }
        if app.sheets.firstMatch.waitForExistence(timeout: 4) || app.dialogs.firstMatch.waitForExistence(timeout: 4) {
            snapshotter.assertSnapshot(app: app, name: "overlay-modal", config: config)
            app.buttons["Cancel"].firstMatch.clickIfExists()
            app.buttons["Close"].firstMatch.clickIfExists()
        }
    }

    // MARK: - Interaction helpers

    private func waitForPage(_ tab: String, in app: XCUIApplication, timeout: TimeInterval = 6) -> Bool {
        let page = app.otherElements["Page.\(tab)"]
        return page.waitForExistence(timeout: timeout)
    }

    private func switchToTab(_ tab: String, in app: XCUIApplication) {
        let tabButton = app.buttons["TabBar.\(tab)"]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5.0), "Missing tab button TabBar.\(tab)")
        tabButton.click()
        XCTAssertTrue(waitForPage(tab, in: app), "Page did not load for tab \(tab)")
    }

    private func selectCalendarMode(_ label: String, in app: XCUIApplication) {
        let segmented = app.segmentedControls.firstMatch
        XCTAssertTrue(segmented.waitForExistence(timeout: 4), "Calendar mode control missing")
        let button = segmented.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 3), "Calendar mode \(label) not found")
        button.click()
        _ = segmented.waitForExistence(timeout: 0.5)
    }

    private func openSettings(_ app: XCUIApplication) {
        let settingsButton = app.buttons["Header.Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button missing")
        settingsButton.click()
        XCTAssertTrue(app.windows["Settings"].waitForExistence(timeout: 5), "Settings window did not open")
    }

    private func selectSettingsPane(_ name: String, in app: XCUIApplication) {
        let window = app.windows["Settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 3), "Settings window not found")
        let sidebar = window.outlines.firstMatch
        if sidebar.waitForExistence(timeout: 1) {
            let row = sidebar.staticTexts[name]
            if row.exists { row.click() }
        }

        let listRow = window.tables.staticTexts[name]
        if listRow.waitForExistence(timeout: 1) {
            listRow.click()
        }
        // Give SwiftUI a moment to swap content.
        _ = window.waitForExistence(timeout: 0.3)
    }
}

// MARK: - XCUIElement convenience

private extension XCUIElementQuery {
    func firstMatchIfExists(timeout: TimeInterval) -> XCUIElement? {
        let element = firstMatch
        return element.waitForExistence(timeout: timeout) ? element : nil
    }
}

private extension XCUIElement {
    func clickIfExists() {
        if exists { click() }
    }
}
