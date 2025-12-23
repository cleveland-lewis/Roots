import Foundation

/// Canonical feedback events shared across platforms.
enum FeedbackEvent: String, CaseIterable {
    case taskCompleted
    case timerStart
    case timerStop
    case success
    case warning
    case error
}
