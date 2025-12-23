import Foundation

/// Global feedback entry point wired to a platform adapter at app launch.
@MainActor
final class FeedbackCenter {
    static let shared = FeedbackCenter()

    var service: FeedbackService

    init(service: FeedbackService = NoopFeedbackService()) {
        self.service = service
    }

    func play(_ event: FeedbackEvent) {
        service.play(event)
    }
}

private struct NoopFeedbackService: FeedbackService {
    func play(_ event: FeedbackEvent) {}
}
