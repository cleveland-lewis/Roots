import Foundation

/// Shared feedback service contract for platform adapters.
protocol FeedbackService {
    func play(_ event: FeedbackEvent)
}
