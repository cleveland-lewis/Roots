import XCTest
@testable import Roots

final class DeepLinkRouterTests: XCTestCase {
    private var router: DeepLinkRouter!
    private var appModel: AppModel!
    private var planner: PlannerCoordinator!
    private var calendar: CalendarManager!
    private var settingsCoordinator: SettingsCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        router = DeepLinkRouter.shared
        appModel = AppModel()
        planner = PlannerCoordinator()
        calendar = CalendarManager()
        settingsCoordinator = SettingsCoordinator(appSettings: AppSettingsModel.shared, coursesStore: CoursesStore())
    }

    func testDashboardRoute() {
        let url = URL(string: "roots://dashboard")!
        XCTAssertTrue(router.handle(url: url, appModel: appModel, plannerCoordinator: planner, calendarManager: calendar, settingsCoordinator: settingsCoordinator))
        XCTAssertEqual(appModel.selectedPage, .dashboard)
    }

    func testCalendarRouteWithDate() {
        let url = URL(string: "roots://calendar?date=2024-12-25&view=month")!
        XCTAssertTrue(router.handle(url: url, appModel: appModel, plannerCoordinator: planner, calendarManager: calendar, settingsCoordinator: settingsCoordinator))
        XCTAssertEqual(appModel.selectedPage, .calendar)
        XCTAssertEqual(Calendar.current.component(.day, from: calendar.selectedDate ?? Date()), 25)
    }

    func testPlannerRoute() {
        let url = URL(string: "roots://planner")!
        XCTAssertTrue(router.handle(url: url, appModel: appModel, plannerCoordinator: planner, calendarManager: calendar, settingsCoordinator: settingsCoordinator))
        XCTAssertEqual(appModel.selectedPage, .planner)
    }

    func testAssignmentRoute() {
        let id = UUID()
        let url = URL(string: "roots://assignment/\(id.uuidString)")!
        XCTAssertTrue(router.handle(url: url, appModel: appModel, plannerCoordinator: planner, calendarManager: calendar, settingsCoordinator: settingsCoordinator))
        XCTAssertEqual(appModel.selectedPage, .assignments)
    }

    func testCourseRoute() {
        let id = UUID()
        let url = URL(string: "roots://course/\(id.uuidString)")!
        XCTAssertTrue(router.handle(url: url, appModel: appModel, plannerCoordinator: planner, calendarManager: calendar, settingsCoordinator: settingsCoordinator))
        XCTAssertEqual(appModel.selectedPage, .courses)
        XCTAssertEqual(planner.selectedCourseFilter, id)
    }

    func testFocusRoute() {
        let activityId = UUID()
        let url = URL(string: "roots://focus?mode=pomodoro&activityId=\(activityId.uuidString)")!
        XCTAssertTrue(router.handle(url: url, appModel: appModel, plannerCoordinator: planner, calendarManager: calendar, settingsCoordinator: settingsCoordinator))
        XCTAssertEqual(appModel.selectedPage, .timer)
        XCTAssertEqual(appModel.focusDeepLink?.mode, .pomodoro)
        XCTAssertEqual(appModel.focusDeepLink?.activityId, activityId)
    }

    func testSettingsRoute() {
        let url = URL(string: "roots://settings?section=developer")!
        XCTAssertTrue(router.handle(url: url, appModel: appModel, plannerCoordinator: planner, calendarManager: calendar, settingsCoordinator: settingsCoordinator))
    }

    func testInvalidScheme() {
        let url = URL(string: "http://calendar")!
        XCTAssertFalse(router.handle(url: url, appModel: appModel, plannerCoordinator: planner, calendarManager: calendar, settingsCoordinator: settingsCoordinator))
    }

    func testMissingAssignmentId() {
        let url = URL(string: "roots://assignment/")!
        XCTAssertFalse(router.handle(url: url, appModel: appModel, plannerCoordinator: planner, calendarManager: calendar, settingsCoordinator: settingsCoordinator))
    }

    func testUnknownRoute() {
        let url = URL(string: "roots://unknown")!
        XCTAssertFalse(router.handle(url: url, appModel: appModel, plannerCoordinator: planner, calendarManager: calendar, settingsCoordinator: settingsCoordinator))
    }
}
