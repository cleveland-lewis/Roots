import Foundation
import SwiftUI

@Observable
class ScheduledTestsStore {
    var scheduledTests: [ScheduledPracticeTest] = []
    var attempts: [TestAttempt] = []
    var currentWeek: Date = Date()
    
    private let testsStorageKey = "scheduled_practice_tests_v1"
    private let attemptsStorageKey = "test_attempts_v1"
    
    init() {
        loadData()
    }
    
    // MARK: - Week Navigation
    
    func goToPreviousWeek() {
        currentWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeek) ?? currentWeek
    }
    
    func goToNextWeek() {
        currentWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeek) ?? currentWeek
    }
    
    func goToThisWeek() {
        currentWeek = Date()
    }
    
    var isCurrentWeek: Bool {
        let thisWeekStart = Calendar.current.startOfWeek(for: Date())
        let selectedWeekStart = Calendar.current.startOfWeek(for: currentWeek)
        return Calendar.current.isDate(thisWeekStart, equalTo: selectedWeekStart, toGranularity: .day)
    }
    
    // MARK: - Data Access
    
    func testsForCurrentWeek() -> [ScheduledPracticeTest] {
        let start = Calendar.current.startOfWeek(for: currentWeek)
        let end = Calendar.current.endOfWeek(for: currentWeek)
        
        return scheduledTests.filter { test in
            test.scheduledAt >= start && test.scheduledAt < end && test.status != .archived
        }
    }
    
    func testsForDay(_ date: Date) -> [ScheduledPracticeTest] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        return testsForCurrentWeek().filter { test in
            test.scheduledAt >= startOfDay && test.scheduledAt < endOfDay
        }.sorted { $0.scheduledAt < $1.scheduledAt }
    }
    
    func hasCompletedAttempt(for scheduledTestID: UUID) -> Bool {
        attempts.contains { attempt in
            attempt.scheduledTestID == scheduledTestID && attempt.isCompleted
        }
    }
    
    func computedStatus(for test: ScheduledPracticeTest) -> ScheduledTestStatus {
        test.computedStatus(hasCompletedAttempt: hasCompletedAttempt(for: test.id))
    }
    
    // MARK: - Mutations
    
    func addScheduledTest(_ test: ScheduledPracticeTest) {
        scheduledTests.append(test)
        saveData()
    }
    
    func updateScheduledTest(_ test: ScheduledPracticeTest) {
        if let index = scheduledTests.firstIndex(where: { $0.id == test.id }) {
            scheduledTests[index] = test
            saveData()
        }
    }
    
    func deleteScheduledTest(_ testID: UUID) {
        scheduledTests.removeAll { $0.id == testID }
        saveData()
    }
    
    func startTest(scheduledTest: ScheduledPracticeTest) -> TestAttempt {
        let attempt = TestAttempt(
            scheduledTestID: scheduledTest.id,
            startedAt: Date()
        )
        attempts.append(attempt)
        saveData()
        return attempt
    }
    
    func completeAttempt(_ attemptID: UUID, score: Double?, outputReference: String? = nil) {
        if let index = attempts.firstIndex(where: { $0.id == attemptID }) {
            attempts[index].completedAt = Date()
            attempts[index].score = score
            attempts[index].outputReference = outputReference
            saveData()
        }
    }
    
    // MARK: - Persistence
    
    private func loadData() {
        // Load scheduled tests
        if let testsData = UserDefaults.standard.data(forKey: testsStorageKey),
           let decoded = try? JSONDecoder().decode([ScheduledPracticeTest].self, from: testsData) {
            scheduledTests = decoded
        }
        
        // Load attempts
        if let attemptsData = UserDefaults.standard.data(forKey: attemptsStorageKey),
           let decoded = try? JSONDecoder().decode([TestAttempt].self, from: attemptsData) {
            attempts = decoded
        }
        
        // Add some sample data if empty (for demo purposes)
        if scheduledTests.isEmpty {
            addSampleData()
        }
    }
    
    private func saveData() {
        // Save scheduled tests
        if let encoded = try? JSONEncoder().encode(scheduledTests) {
            UserDefaults.standard.set(encoded, forKey: testsStorageKey)
        }
        
        // Save attempts
        if let encoded = try? JSONEncoder().encode(attempts) {
            UserDefaults.standard.set(encoded, forKey: attemptsStorageKey)
        }
    }
    
    // MARK: - Sample Data
    
    private func addSampleData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // This week's tests
        scheduledTests = [
            ScheduledPracticeTest(
                title: "Calculus Midterm Practice",
                subject: "Mathematics",
                unitName: "Derivatives & Integrals",
                scheduledAt: calendar.date(byAdding: .day, value: 1, to: today) ?? today,
                estimatedMinutes: 45,
                difficulty: 4
            ),
            ScheduledPracticeTest(
                title: "Biology Quiz",
                subject: "Biology",
                unitName: "Cell Structure",
                scheduledAt: calendar.date(byAdding: .day, value: 2, to: today) ?? today,
                estimatedMinutes: 30,
                difficulty: 3
            ),
            ScheduledPracticeTest(
                title: "Physics Problem Set",
                subject: "Physics",
                unitName: "Newton's Laws",
                scheduledAt: calendar.date(byAdding: .day, value: 3, to: today) ?? today,
                estimatedMinutes: 60,
                difficulty: 5
            ),
            ScheduledPracticeTest(
                title: "Chemistry Review",
                subject: "Chemistry",
                unitName: "Periodic Table",
                scheduledAt: calendar.date(byAdding: .day, value: -2, to: today) ?? today,
                estimatedMinutes: 40,
                difficulty: 2
            )
        ]
        saveData()
    }
}
