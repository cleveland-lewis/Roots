import Foundation

// MARK: - Scheduled Practice Test Models

/// Status of a scheduled practice test
enum ScheduledTestStatus: String, Codable, CaseIterable {
    case scheduled = "Scheduled"
    case completed = "Completed"
    case missed = "Missed"
    case archived = "Archived"
    
    var displayText: String {
        rawValue
    }
}

/// A scheduled practice test with timing and metadata
struct ScheduledPracticeTest: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var subject: String
    var unitName: String?
    var scheduledAt: Date
    var estimatedMinutes: Int?
    var difficulty: Int // 1-5
    var status: ScheduledTestStatus
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        subject: String,
        unitName: String? = nil,
        scheduledAt: Date,
        estimatedMinutes: Int? = nil,
        difficulty: Int = 3,
        status: ScheduledTestStatus = .scheduled,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subject = subject
        self.unitName = unitName
        self.scheduledAt = scheduledAt
        self.estimatedMinutes = estimatedMinutes
        self.difficulty = max(1, min(5, difficulty))
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Returns computed status based on current time
    func computedStatus(hasCompletedAttempt: Bool) -> ScheduledTestStatus {
        if status == .archived {
            return .archived
        }
        if hasCompletedAttempt {
            return .completed
        }
        if scheduledAt < Date() && !hasCompletedAttempt {
            return .missed
        }
        return .scheduled
    }
}

/// A test attempt record
struct TestAttempt: Identifiable, Codable, Hashable {
    var id: UUID
    var scheduledTestID: UUID?
    var startedAt: Date
    var completedAt: Date?
    var score: Double?
    var outputReference: String? // JSON storage or file reference
    
    init(
        id: UUID = UUID(),
        scheduledTestID: UUID? = nil,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        score: Double? = nil,
        outputReference: String? = nil
    ) {
        self.id = id
        self.scheduledTestID = scheduledTestID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.score = score
        self.outputReference = outputReference
    }
    
    var isCompleted: Bool {
        completedAt != nil
    }
}

// MARK: - Week Range Helper

extension Calendar {
    /// Returns the start of the week (Monday) for a given date
    func startOfWeek(for date: Date) -> Date {
        var calendar = self
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Returns the end of the week (exclusive - start of next Monday)
    func endOfWeek(for date: Date) -> Date {
        let start = startOfWeek(for: date)
        return calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
    }
    
    /// Returns an array of dates for each day of the week (Mon-Sun)
    func daysOfWeek(for date: Date) -> [Date] {
        let start = startOfWeek(for: date)
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: start)
        }
    }
}

private var calendar: Calendar {
    Calendar.current
}
