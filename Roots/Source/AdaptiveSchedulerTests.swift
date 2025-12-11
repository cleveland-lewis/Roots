#if canImport(XCTest)
import XCTest
@testable import Roots

final class AdaptiveSchedulerTests: XCTestCase {
    func date(_ y:Int,_ m:Int,_ d:Int,_ h:Int,_ min:Int) -> Date {
        var dc = DateComponents(); dc.year = y; dc.month = m; dc.day = d; dc.hour = h; dc.minute = min
        return Calendar.current.date(from: dc)!
    }

    func testEnergyProfilePreferenceAffectsScheduling() {
        let task = AIScheduler.Task(id: UUID(), title: "A", courseId: nil, due: nil, estimatedMinutes: 60, minBlockMinutes: 25, maxBlockMinutes: 90, difficulty: 0.5, importance: 0.5, type: .reading, locked: false)
        let constraints = AIScheduler.Constraints(horizonStart: date(2025,12,1,0,0), horizonEnd: date(2025,12,2,23,59), dayStartHour: 8, dayEndHour: 23, maxStudyMinutesPerDay: 600, maxStudyMinutesPerBlock: 180, minGapBetweenBlocksMinutes: 10, doNotScheduleWindows: [], energyProfile: (0..<24).reduce(into: [:]) { $0[$1] = 0.5 })

        var prefsMorning = SchedulerPreferences.default()
        for h in 0..<24 { prefsMorning.learnedEnergyProfile[h] = 0.1 }
        prefsMorning.learnedEnergyProfile[9] = 1.0

        var prefsNight = SchedulerPreferences.default()
        for h in 0..<24 { prefsNight.learnedEnergyProfile[h] = 0.1 }
        prefsNight.learnedEnergyProfile[21] = 1.0

        let resMorning = AIScheduler.generateSchedule(tasks: [task], fixedEvents: [], constraints: constraints, preferences: prefsMorning)
        let resNight = AIScheduler.generateSchedule(tasks: [task], fixedEvents: [], constraints: constraints, preferences: prefsNight)

        let morningFound = resMorning.blocks.contains { Calendar.current.component(.hour, from: $0.start) == 9 }
        let nightFound = resNight.blocks.contains { Calendar.current.component(.hour, from: $0.start) == 21 }

        XCTAssertTrue(morningFound)
        XCTAssertTrue(nightFound)
    }

    func testPreferredBlockLengthByType() {
        let task = AIScheduler.Task(id: UUID(), title: "Read", courseId: nil, due: nil, estimatedMinutes: 60, minBlockMinutes: 15, maxBlockMinutes: 120, difficulty: 0.5, importance: 0.5, type: .reading, locked: false)
        let constraints = AIScheduler.Constraints(horizonStart: date(2025,12,1,0,0), horizonEnd: date(2025,12,2,23,59), dayStartHour: 8, dayEndHour: 23, maxStudyMinutesPerDay: 600, maxStudyMinutesPerBlock: 180, minGapBetweenBlocksMinutes: 10, doNotScheduleWindows: [], energyProfile: (0..<24).reduce(into: [:]) { $0[$1] = 0.5 })

        var prefs = SchedulerPreferences.default()
        prefs.preferredBlockLengthByType[TaskType.reading.rawValue] = 30

        let res = AIScheduler.generateSchedule(tasks: [task], fixedEvents: [], constraints: constraints, preferences: prefs)
        XCTAssertFalse(res.blocks.isEmpty)
        for b in res.blocks where b.taskId == task.id {
            let dur = Int(b.end.timeIntervalSince(b.start)/60)
            XCTAssertTrue(abs(dur - 30) <= 10)
        }
    }

    func testFeedbackUpdatesPreferences() {
        var prefs = SchedulerPreferences.default()
        // create synthetic feedback: 9am kept, 21pm deleted
        let fb1 = BlockFeedback(blockId: UUID(), taskId: UUID(), courseId: nil, type: .reading, start: date(2025,12,1,9,0), end: date(2025,12,1,9,30), completion: 1.0, action: .kept)
        let fb2 = BlockFeedback(blockId: UUID(), taskId: UUID(), courseId: nil, type: .reading, start: date(2025,12,1,21,0), end: date(2025,12,1,21,30), completion: 0.0, action: .deleted)
        let feedback = [fb1, fb2]
        SchedulerLearner.updatePreferences(from: feedback, preferences: &prefs)
        let e9 = prefs.learnedEnergyProfile[9] ?? 0.0
        let e21 = prefs.learnedEnergyProfile[21] ?? 0.0
        XCTAssertTrue(e9 > e21)
    }
}

#endif
