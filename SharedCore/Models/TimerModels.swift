import Foundation

// MARK: - Models

/// High level timer mode controlled by the shared selector.
enum TimerMode: String, CaseIterable, Identifiable, Codable {
    case pomodoro
    case timer
    case stopwatch

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pomodoro: return "Pomodoro"
        case .timer: return "Timer"
        case .stopwatch: return "Stopwatch"
        }
    }

    var systemImage: String {
        switch self {
        case .pomodoro: return "hourglass"
        case .timer: return "timer"
        case .stopwatch: return "stopwatch"
        }
    }
}

enum TimerDisplayStyle: String, CaseIterable, Identifiable, Codable {
    case digital
    case analog

    var id: String { rawValue }

    var label: String {
        switch self {
        case .digital:
            return NSLocalizedString("timer.display.digital", comment: "")
        case .analog:
            return NSLocalizedString("timer.display.analog", comment: "")
        }
    }
}

/// Represents an activity the user can time (e.g., study task, assignment, course work)
struct TimerActivity: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var note: String?
    var courseID: UUID?
    var assignmentID: UUID?
    var studyCategory: StudyCategory?
    var collectionID: UUID?
    var colorHex: String?
    var emoji: String?
    var isPinned: Bool

    init(id: UUID = UUID(), name: String, note: String? = nil, courseID: UUID? = nil, assignmentID: UUID? = nil, studyCategory: StudyCategory? = nil, collectionID: UUID? = nil, colorHex: String? = nil, emoji: String? = nil, isPinned: Bool = false) {
        self.id = id
        self.name = name
        self.note = note
        self.courseID = courseID
        self.assignmentID = assignmentID
        self.studyCategory = studyCategory
        self.collectionID = collectionID
        self.colorHex = colorHex
        self.emoji = emoji
        self.isPinned = isPinned
    }
}

enum StudyCategory: String, CaseIterable, Identifiable, Codable {
    case reading
    case problemSolving
    case reviewing
    case writing
    case admin

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

/// Collection of activities
struct ActivityCollection: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var description: String?

    init(id: UUID = UUID(), name: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

/// Represents a run/session
struct FocusSession: Identifiable, Hashable, Codable {
    enum State: String, Codable {
        case idle
        case running
        case paused
        case completed
        case cancelled
    }

    let id: UUID
    let activityID: UUID?
    let mode: TimerMode
    let plannedDuration: TimeInterval?
    var startedAt: Date?
    var endedAt: Date?
    var state: State
    var actualDuration: TimeInterval?
    var interruptions: Int = 0

    init(id: UUID = UUID(), activityID: UUID? = nil, mode: TimerMode = .pomodoro, plannedDuration: TimeInterval? = nil, startedAt: Date? = nil, endedAt: Date? = nil, state: State = .idle, actualDuration: TimeInterval? = nil, interruptions: Int = 0) {
        self.id = id
        self.activityID = activityID
        self.mode = mode
        self.plannedDuration = plannedDuration
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.state = state
        self.actualDuration = actualDuration
        self.interruptions = interruptions
    }
}
