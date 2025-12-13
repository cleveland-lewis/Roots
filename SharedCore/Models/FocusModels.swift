import Foundation
import SwiftUI

enum LocalTimerMode: String, CaseIterable, Identifiable, Codable {
    case pomodoro
    case countdown
    case stopwatch

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pomodoro: return "Pomodoro"
        case .countdown: return "Timer"
        case .stopwatch: return "Stopwatch"
        }
    }
}

struct LocalTimerActivity: Identifiable, Hashable {
    let id: UUID
    var name: String
    var category: String
    var courseCode: String?
    var assignmentTitle: String?
    var colorTag: ColorTag
    var isPinned: Bool
    var totalTrackedSeconds: TimeInterval
    var todayTrackedSeconds: TimeInterval
}

struct LocalTimerSession: Identifiable, Codable, Hashable {
    let id: UUID
    var activityID: UUID
    var mode: LocalTimerMode
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id, activityID, mode, startDate, endDate, duration
    }
}
