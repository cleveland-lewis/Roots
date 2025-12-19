//
//  RootsUITests.swift
//  RootsUITests
//
//  Created by Cleveland Lewis III on 11/30/25.
//

import XCTest

final class RootsUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    /// Opens each top-level tab and asserts the UI transitions within a short timeout.
    /// If the app freezes/hangs on a tab switch, this will fail by timing out.
    @MainActor
    func testSwitchingAllTabsDoesNotHang() throws {
        let app = XCUIApplication()
        app.launch()

        // Give the initial render a moment to settle.
        XCTAssertTrue(app.otherElements["Page.dashboard"].waitForExistence(timeout: 5.0))

        let tabs: [String] = [
            "dashboard",
            "calendar",
            "planner",
            "assignments",
            "courses",
            "grades",
            "timer",
            "decks",
            "practice",
        ]

        for tab in tabs {
            let tabButton = app.buttons["TabBar.\(tab)"]
            XCTAssertTrue(tabButton.waitForExistence(timeout: 5.0), "Missing tab button TabBar.\(tab)")
            tabButton.click()

            let page = app.otherElements["Page.\(tab)"]
            XCTAssertTrue(page.waitForExistence(timeout: 5.0), "Page did not appear for tab \(tab)")
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

#if os(iOS)
    @MainActor
    func testTimerSmokeFlow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITestTimerDebug")
        app.launch()

        let timerTab = app.tabBars.buttons["Timer"]
        if timerTab.exists {
            timerTab.tap()
        }

        let status = app.staticTexts["Timer.Status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5.0))

        let startButton = app.buttons["Timer.Start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5.0))
        startButton.tap()

        XCTAssertTrue(status.label == "Running" || status.label == "Paused")

        let stopButton = app.buttons["Timer.Stop"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5.0))
        stopButton.tap()

        XCTAssertTrue(status.label == "Stopped" || status.label == "Ready")
    }

    @MainActor
    func testTimerCompletionAndLiveActivityLifecycle() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITestTimerDebug")
        app.launch()

        let startButton = app.buttons["Timer.Start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5.0))
        startButton.tap()

        let liveActivity = app.staticTexts["Timer.LiveActivityState"]
        XCTAssertTrue(liveActivity.waitForExistence(timeout: 5.0))
        XCTAssertTrue(["Active", "Unavailable"].contains(liveActivity.label))

        XCUIDevice.shared.press(.home)
        app.activate()

        let advanceButton = app.buttons["Timer.DebugAdvance"]
        XCTAssertTrue(advanceButton.waitForExistence(timeout: 5.0))
        advanceButton.tap()

        let sessionState = app.staticTexts["Timer.SessionState"]
        XCTAssertTrue(sessionState.waitForExistence(timeout: 5.0))
        let stateValue = sessionState.label.replacingOccurrences(of: "Session: ", with: "")
        XCTAssertTrue(["completed", "idle"].contains(stateValue))

        XCTAssertTrue(["Inactive", "Unavailable"].contains(liveActivity.label))
    }
#endif
}
