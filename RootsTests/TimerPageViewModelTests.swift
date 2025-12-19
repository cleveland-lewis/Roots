import XCTest
@testable import Roots

@MainActor
final class TimerPageViewModelTests: XCTestCase {
    func testTimerModeUsesPlannedDuration() {
        let viewModel = TimerPageViewModel()
        AppSettingsModel.shared.timerAlertsEnabled = false

        viewModel.currentMode = .timer
        viewModel.timerDuration = 90
        viewModel.startSession()

        XCTAssertEqual(viewModel.sessionRemaining, 90, "Timer mode should use timerDuration as remaining time.")
        XCTAssertEqual(viewModel.currentSession?.mode, .timer)
    }

    func testSkipSegmentTogglesBreakState() {
        let viewModel = TimerPageViewModel()
        AppSettingsModel.shared.pomodoroAlertsEnabled = false

        viewModel.currentMode = .pomodoro
        viewModel.isOnBreak = false
        viewModel.startSession()

        viewModel.skipSegment()

        XCTAssertTrue(viewModel.isOnBreak, "Skip should toggle into break state.")
        XCTAssertEqual(viewModel.currentSession?.state, .running)
        XCTAssertEqual(viewModel.currentSession?.mode, .pomodoro)
    }
}
