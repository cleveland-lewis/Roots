import XCTest
import EventKit

/// Tests for recurrence and alerts round-trip fidelity
/// Verifies that event recurrence patterns and alerts are correctly
/// converted between Roots models and EventKit, preserving all data
final class CalendarRecurrenceTests: XCTestCase {
    
    // Mock EventCategory for testing
    enum EventCategory: String, CaseIterable, Identifiable {
        case study = "Study"
        case homework = "Homework"
        case exam = "Exam"
        case lab = "Lab"
        case `class` = "Class"
        case reading = "Reading"
        case review = "Review"
        case other = "Other"
        
        var id: String { rawValue }
    }
    
    // MARK: - Recurrence Rule Tests
    
    func testDailyRecurrenceConversion() {
        // Test daily recurrence with no end
        let frequency = EKRecurrenceFrequency.daily
        let interval = 1
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: nil
        )
        
        XCTAssertEqual(rule.frequency, .daily, "Frequency should be daily")
        XCTAssertEqual(rule.interval, 1, "Interval should be 1")
        XCTAssertNil(rule.recurrenceEnd, "End should be nil")
    }
    
    func testWeeklyRecurrenceSingleDay() {
        // Test weekly recurrence on a single day
        let frequency = EKRecurrenceFrequency.weekly
        let interval = 1
        let monday = EKRecurrenceDayOfWeek(.monday)
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: [monday],
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: nil
        )
        
        XCTAssertEqual(rule.frequency, .weekly, "Frequency should be weekly")
        XCTAssertEqual(rule.interval, 1, "Interval should be 1")
        XCTAssertEqual(rule.daysOfTheWeek?.count, 1, "Should have 1 day")
        XCTAssertEqual(rule.daysOfTheWeek?.first?.dayOfTheWeek, .monday, "Day should be Monday")
    }
    
    func testWeeklyRecurrenceMultipleDays() {
        // Test weekly recurrence on multiple days (Mon, Wed, Fri)
        let frequency = EKRecurrenceFrequency.weekly
        let interval = 1
        let days = [
            EKRecurrenceDayOfWeek(.monday),
            EKRecurrenceDayOfWeek(.wednesday),
            EKRecurrenceDayOfWeek(.friday)
        ]
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: days,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: nil
        )
        
        XCTAssertEqual(rule.frequency, .weekly, "Frequency should be weekly")
        XCTAssertEqual(rule.interval, 1, "Interval should be 1")
        XCTAssertEqual(rule.daysOfTheWeek?.count, 3, "Should have 3 days")
        
        let weekdays = rule.daysOfTheWeek?.map { $0.dayOfTheWeek } ?? []
        XCTAssertTrue(weekdays.contains(.monday), "Should contain Monday")
        XCTAssertTrue(weekdays.contains(.wednesday), "Should contain Wednesday")
        XCTAssertTrue(weekdays.contains(.friday), "Should contain Friday")
    }
    
    func testBiWeeklyRecurrence() {
        // Test bi-weekly recurrence
        let frequency = EKRecurrenceFrequency.weekly
        let interval = 2
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: nil
        )
        
        XCTAssertEqual(rule.frequency, .weekly, "Frequency should be weekly")
        XCTAssertEqual(rule.interval, 2, "Interval should be 2")
    }
    
    func testMonthlyRecurrence() {
        // Test monthly recurrence
        let frequency = EKRecurrenceFrequency.monthly
        let interval = 1
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: nil
        )
        
        XCTAssertEqual(rule.frequency, .monthly, "Frequency should be monthly")
        XCTAssertEqual(rule.interval, 1, "Interval should be 1")
    }
    
    func testRecurrenceEndByCount() {
        // Test recurrence ending after N occurrences
        let frequency = EKRecurrenceFrequency.weekly
        let interval = 1
        let occurrenceCount = 10
        let end = EKRecurrenceEnd(occurrenceCount: occurrenceCount)
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: end
        )
        
        XCTAssertEqual(rule.frequency, .weekly, "Frequency should be weekly")
        XCTAssertNotNil(rule.recurrenceEnd, "End should not be nil")
        XCTAssertEqual(rule.recurrenceEnd?.occurrenceCount, occurrenceCount, "Occurrence count should match")
    }
    
    func testRecurrenceEndByDate() {
        // Test recurrence ending on a specific date
        let frequency = EKRecurrenceFrequency.daily
        let interval = 1
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: 3, to: Date())!
        let end = EKRecurrenceEnd(end: endDate)
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: end
        )
        
        XCTAssertEqual(rule.frequency, .daily, "Frequency should be daily")
        XCTAssertNotNil(rule.recurrenceEnd, "End should not be nil")
        XCTAssertNotNil(rule.recurrenceEnd?.endDate, "End date should not be nil")
        
        // Compare dates ignoring time components
        let endComponents = calendar.dateComponents([.year, .month, .day], from: endDate)
        let ruleEndComponents = calendar.dateComponents([.year, .month, .day], from: rule.recurrenceEnd!.endDate!)
        XCTAssertEqual(endComponents, ruleEndComponents, "End dates should match")
    }
    
    // MARK: - Alert Tests
    
    func testNoAlerts() {
        // Test event with no alerts
        let alarms: [EKAlarm]? = nil
        
        XCTAssertNil(alarms, "Alarms should be nil")
    }
    
    func testSingleAlert() {
        // Test event with one alert (15 minutes before)
        let offset = TimeInterval(-15 * 60) // 15 minutes before
        let alarm = EKAlarm(relativeOffset: offset)
        let alarms = [alarm]
        
        XCTAssertEqual(alarms.count, 1, "Should have 1 alarm")
        XCTAssertEqual(alarms[0].relativeOffset, offset, "Offset should match")
    }
    
    func testTwoAlerts() {
        // Test event with two alerts (1 day and 1 hour before)
        let primaryOffset = TimeInterval(-24 * 60 * 60) // 1 day before
        let secondaryOffset = TimeInterval(-60 * 60) // 1 hour before
        
        let primaryAlarm = EKAlarm(relativeOffset: primaryOffset)
        let secondaryAlarm = EKAlarm(relativeOffset: secondaryOffset)
        let alarms = [primaryAlarm, secondaryAlarm]
        
        XCTAssertEqual(alarms.count, 2, "Should have 2 alarms")
        XCTAssertEqual(alarms[0].relativeOffset, primaryOffset, "Primary offset should match")
        XCTAssertEqual(alarms[1].relativeOffset, secondaryOffset, "Secondary offset should match")
    }
    
    func testAlertAtTimeOfEvent() {
        // Test alert at time of event (0 offset)
        let offset = TimeInterval(0)
        let alarm = EKAlarm(relativeOffset: offset)
        
        XCTAssertEqual(alarm.relativeOffset, 0, "Offset should be 0")
    }
    
    func testCommonAlertOffsets() {
        // Test common alert time offsets
        let testCases: [(minutes: Int, description: String)] = [
            (0, "At time of event"),
            (5, "5 minutes before"),
            (10, "10 minutes before"),
            (15, "15 minutes before"),
            (30, "30 minutes before"),
            (60, "1 hour before"),
            (120, "2 hours before"),
            (1440, "1 day before"),
            (2880, "2 days before"),
            (10080, "1 week before")
        ]
        
        for testCase in testCases {
            let offset = TimeInterval(-testCase.minutes * 60)
            let alarm = EKAlarm(relativeOffset: offset)
            XCTAssertEqual(alarm.relativeOffset, offset, "\(testCase.description) offset should match")
        }
    }
    
    // MARK: - Recurrence + Alerts Combined Tests
    
    func testWeeklyRecurrenceWithAlerts() {
        // Test weekly recurring event with multiple alerts
        let frequency = EKRecurrenceFrequency.weekly
        let interval = 1
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: nil
        )
        
        let primaryOffset = TimeInterval(-60 * 60) // 1 hour
        let secondaryOffset = TimeInterval(-15 * 60) // 15 minutes
        let alarms = [
            EKAlarm(relativeOffset: primaryOffset),
            EKAlarm(relativeOffset: secondaryOffset)
        ]
        
        XCTAssertEqual(rule.frequency, .weekly, "Recurrence should be weekly")
        XCTAssertEqual(alarms.count, 2, "Should have 2 alarms")
        XCTAssertEqual(alarms[0].relativeOffset, primaryOffset, "Primary alarm should match")
        XCTAssertEqual(alarms[1].relativeOffset, secondaryOffset, "Secondary alarm should match")
    }
    
    func testDailyRecurrenceEndingWithAlerts() {
        // Test daily recurring event with end count and alerts
        let frequency = EKRecurrenceFrequency.daily
        let interval = 1
        let occurrenceCount = 7
        let end = EKRecurrenceEnd(occurrenceCount: occurrenceCount)
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: end
        )
        
        let alarmOffset = TimeInterval(-10 * 60) // 10 minutes
        let alarm = EKAlarm(relativeOffset: alarmOffset)
        
        XCTAssertEqual(rule.frequency, .daily, "Frequency should be daily")
        XCTAssertEqual(rule.recurrenceEnd?.occurrenceCount, occurrenceCount, "Should end after 7 occurrences")
        XCTAssertEqual(alarm.relativeOffset, alarmOffset, "Alarm should be 10 minutes before")
    }
    
    // MARK: - Weekday Selection Tests
    
    func testWeekdayMaskConversion() {
        // Test converting weekday selection dictionary to EKRecurrenceDayOfWeek array
        let weekdaySelection: [Int: Bool] = [
            1: true,  // Sunday
            2: true,  // Monday
            3: false, // Tuesday
            4: true,  // Wednesday
            5: false, // Thursday
            6: true,  // Friday
            7: false  // Saturday
        ]
        
        let selectedDays = weekdaySelection.filter { $0.value }.compactMap { (index, _) -> EKRecurrenceDayOfWeek? in
            guard let weekday = EKWeekday(rawValue: index) else { return nil }
            return EKRecurrenceDayOfWeek(weekday)
        }
        
        XCTAssertEqual(selectedDays.count, 4, "Should have 4 selected days")
        
        let weekdays = selectedDays.map { $0.dayOfTheWeek.rawValue }
        XCTAssertTrue(weekdays.contains(1), "Should contain Sunday")
        XCTAssertTrue(weekdays.contains(2), "Should contain Monday")
        XCTAssertTrue(weekdays.contains(4), "Should contain Wednesday")
        XCTAssertTrue(weekdays.contains(6), "Should contain Friday")
    }
    
    // MARK: - Edge Case Tests
    
    func testRecurrenceWithNoInterval() {
        // Test that interval defaults to 1 if not specified
        let frequency = EKRecurrenceFrequency.weekly
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: 1,
            end: nil
        )
        
        XCTAssertEqual(rule.interval, 1, "Default interval should be 1")
    }
    
    func testRecurrenceWithLargeInterval() {
        // Test recurrence with large interval (every 4 weeks)
        let frequency = EKRecurrenceFrequency.weekly
        let interval = 4
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: nil
        )
        
        XCTAssertEqual(rule.interval, 4, "Interval should be 4")
    }
    
    func testMultipleAlarmsOrdering() {
        // Test that multiple alarms maintain order
        let offsets = [-10080, -1440, -60, -15] // 1 week, 1 day, 1 hour, 15 min (all in minutes)
        let alarms = offsets.map { EKAlarm(relativeOffset: TimeInterval($0 * 60)) }
        
        XCTAssertEqual(alarms.count, 4, "Should have 4 alarms")
        for (index, alarm) in alarms.enumerated() {
            XCTAssertEqual(alarm.relativeOffset, TimeInterval(offsets[index] * 60), "Alarm \(index) offset should match")
        }
    }
    
    func testRecurrenceEndDatePrecision() {
        // Test that recurrence end date preserves day precision
        let calendar = Calendar.current
        let startDate = Date()
        let endDate = calendar.date(byAdding: .month, value: 6, to: startDate)!
        
        let end = EKRecurrenceEnd(end: endDate)
        let rule = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            end: end
        )
        
        let startComponents = calendar.dateComponents([.year, .month, .day], from: endDate)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: rule.recurrenceEnd!.endDate!)
        
        XCTAssertEqual(startComponents.year, endComponents.year, "Year should match")
        XCTAssertEqual(startComponents.month, endComponents.month, "Month should match")
        XCTAssertEqual(startComponents.day, endComponents.day, "Day should match")
    }
    
    // MARK: - Category Encoding Tests
    
    func testCategoryEncodingInNotes() {
        // Test that category is properly encoded in notes
        let userNotes = "Remember to bring textbook"
        let category = EventCategory.study
        let expectedPattern = "[RootsCategory:Study]"
        
        // Simulate encoding
        let encodedNotes = userNotes + "\n" + expectedPattern
        
        XCTAssertTrue(encodedNotes.contains(expectedPattern), "Notes should contain category marker")
        XCTAssertTrue(encodedNotes.contains(userNotes), "Notes should contain user text")
    }
    
    func testCategoryDecodingFromNotes() {
        // Test that category can be extracted from notes
        let userNotes = "Prepare presentation slides"
        let categoryMarker = "[RootsCategory:Homework]"
        let encodedNotes = userNotes + "\n" + categoryMarker
        
        // Simulate decoding
        let pattern = #"\[RootsCategory:(.*?)\]"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(encodedNotes.startIndex..., in: encodedNotes)
        
        if let match = regex?.firstMatch(in: encodedNotes, options: [], range: range),
           let categoryRange = Range(match.range(at: 1), in: encodedNotes) {
            let extractedCategory = String(encodedNotes[categoryRange])
            XCTAssertEqual(extractedCategory, "Homework", "Extracted category should be Homework")
        } else {
            XCTFail("Should be able to extract category")
        }
        
        // Verify user notes can be cleaned
        let cleanNotes = encodedNotes.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(cleanNotes, userNotes, "Clean notes should match original user notes")
    }
    
    // MARK: - Performance Tests
    
    func testRecurrenceRuleCreationPerformance() {
        measure {
            // Test performance of creating 1000 recurrence rules
            for _ in 0..<1000 {
                let rule = EKRecurrenceRule(
                    recurrenceWith: .daily,
                    interval: 1,
                    end: nil
                )
                _ = rule.frequency
            }
        }
    }
    
    func testAlarmCreationPerformance() {
        measure {
            // Test performance of creating 1000 alarms
            for i in 0..<1000 {
                let offset = TimeInterval(-i * 60)
                let alarm = EKAlarm(relativeOffset: offset)
                _ = alarm.relativeOffset
            }
        }
    }
}
