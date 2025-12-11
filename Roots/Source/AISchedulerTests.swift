#if canImport(XCTest)
import XCTest
@testable import Roots

final class AISchedulerTests: XCTestCase {
    func date(_ y:Int,_ m:Int,_ d:Int,_ h:Int,_ min:Int) -> Date {
        var dc = DateComponents(); dc.year = y; dc.month = m; dc.day = d; dc.hour = h; dc.minute = min
        return Calendar.current.date(from: dc)!
    }

    func testBasicSchedulingProducesBlock() {
        let task = AIScheduler.Task(id: UUID(), title: "T1", courseId: nil, due: nil, estimatedMinutes: 60, minBlockMinutes: 25, maxBlockMinutes: 90, difficulty: 0.5, importance: 0.5, type: .reading, locked: false)
        let fixed: [AIScheduler.FixedEvent] = []
        let constraints = AIScheduler.Constraints(horizonStart: date(2025,12,1,0,0), horizonEnd: date(2025,12,2,0,0), dayStartHour: 8, dayEndHour: 20, maxStudyMinutesPerDay: 600, maxStudyMinutesPerBlock: 180, minGapBetweenBlocksMinutes: 10, doNotScheduleWindows: [], energyProfile: (0..<24).reduce(into: [:]) { $0[$1] = 0.5 })
        let res = AIScheduler.generateSchedule(tasks: [task], fixedEvents: fixed, constraints: constraints)
        XCTAssertTrue(res.blocks.count >= 1)
    }

    func testDeadlineRespect() {
        let now = date(2025,12,1,9,0)
        let dueSoon = date(2025,12,1,12,0)
        let dueLater = date(2025,12,2,12,0)
        let t1 = AIScheduler.Task(id: UUID(), title: "Soon", courseId: nil, due: dueSoon, estimatedMinutes: 30, minBlockMinutes: 15, maxBlockMinutes: 60, difficulty: 0.5, importance: 0.7, type: .reading, locked: false)
        let t2 = AIScheduler.Task(id: UUID(), title: "Later", courseId: nil, due: dueLater, estimatedMinutes: 30, minBlockMinutes: 15, maxBlockMinutes: 60, difficulty: 0.5, importance: 0.7, type: .reading, locked: false)
        let constraints = AIScheduler.Constraints(horizonStart: now, horizonEnd: date(2025,12,3,0,0), dayStartHour: 8, dayEndHour: 20, maxStudyMinutesPerDay: 600, maxStudyMinutesPerBlock: 180, minGapBetweenBlocksMinutes: 10, doNotScheduleWindows: [], energyProfile: (0..<24).reduce(into: [:]) { $0[$1] = 0.5 })
        let res = AIScheduler.generateSchedule(tasks: [t2,t1], fixedEvents: [], constraints: constraints)
        // ensure no block for t1 after its due
        for b in res.blocks where b.taskId == t1.id {
            XCTAssertLessThanOrEqual(b.end, t1.due!)
        }
    }

    func testDailyLimitRespected() {
        let t = AIScheduler.Task(id: UUID(), title: "Long", courseId: nil, due: date(2025,12,3,0,0), estimatedMinutes: 500, minBlockMinutes: 25, maxBlockMinutes: 300, difficulty: 0.5, importance: 0.5, type: .project, locked: false)
        let constraints = AIScheduler.Constraints(horizonStart: date(2025,12,1,0,0), horizonEnd: date(2025,12,5,0,0), dayStartHour: 8, dayEndHour: 20, maxStudyMinutesPerDay: 120, maxStudyMinutesPerBlock: 120, minGapBetweenBlocksMinutes: 10, doNotScheduleWindows: [], energyProfile: (0..<24).reduce(into: [:]) { $0[$1] = 0.5 })
        let res = AIScheduler.generateSchedule(tasks: [t], fixedEvents: [], constraints: constraints, options: AIScheduler.SchedulerOptions())
        // compute per-day minutes
        var minsByDay: [Date: Int] = [:]
        for b in res.blocks {
            let day = Calendar.current.startOfDay(for: b.start)
            minsByDay[day, default: 0] += Int(b.end.timeIntervalSince(b.start)/60)
        }
        for (_, v) in minsByDay { XCTAssertLessThanOrEqual(v, 120) }
    }

    func testDoNotScheduleWindowsRespected() {
        let t = AIScheduler.Task(id: UUID(), title: "X", courseId: nil, due: date(2025,12,2,0,0), estimatedMinutes: 60, minBlockMinutes: 25, maxBlockMinutes: 60, difficulty: 0.5, importance: 0.5, type: .reading, locked: false)
        let blockWindow = date(2025,12,1,10,0)...date(2025,12,1,12,0)
        let constraints = AIScheduler.Constraints(horizonStart: date(2025,12,1,0,0), horizonEnd: date(2025,12,2,0,0), dayStartHour: 8, dayEndHour: 20, maxStudyMinutesPerDay: 600, maxStudyMinutesPerBlock: 180, minGapBetweenBlocksMinutes: 10, doNotScheduleWindows: [blockWindow], energyProfile: (0..<24).reduce(into: [:]) { $0[$1] = 0.5 })
        let res = AIScheduler.generateSchedule(tasks: [t], fixedEvents: [], constraints: constraints, options: AIScheduler.SchedulerOptions())
        for b in res.blocks {
            XCTAssertFalse(b.start < blockWindow.upperBound && b.end > blockWindow.lowerBound)
        }
    }

    func testEnergyProfileInfluence() {
        // Create two candidates, morning favored
        let t = AIScheduler.Task(id: UUID(), title: "Y", courseId: nil, due: date(2025,12,2,0,0), estimatedMinutes: 60, minBlockMinutes: 25, maxBlockMinutes: 60, difficulty: 0.5, importance: 0.5, type: .reading, locked: false)
        // Energy profile favors 9am
        var profile = (0..<24).reduce(into: [:]) { $0[$1] = 0.1 }
        profile[9] = 1.0
        profile[18] = 0.2
        let constraints = AIScheduler.Constraints(horizonStart: date(2025,12,1,0,0), horizonEnd: date(2025,12,2,23,59), dayStartHour: 8, dayEndHour: 20, maxStudyMinutesPerDay: 600, maxStudyMinutesPerBlock: 180, minGapBetweenBlocksMinutes: 10, doNotScheduleWindows: [], energyProfile: profile)
        let res = AIScheduler.generateSchedule(tasks: [t], fixedEvents: [], constraints: constraints, options: AIScheduler.SchedulerOptions())
        // ensure at least one block falls into 9am hour if possible
        let found = res.blocks.contains { Calendar.current.component(.hour, from: $0.start) == 9 }
        XCTAssertTrue(found)
    }
}

#endif
