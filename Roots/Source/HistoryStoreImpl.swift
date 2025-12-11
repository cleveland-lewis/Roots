import Foundation

// Concrete history store backed by SchedulerFeedbackStore.
// Since scheduled blocks are not persisted in this app, derive historical scheduled blocks from feedback entries.
final class HistoryStoreImpl: HistoryStore {
    static let shared = HistoryStoreImpl()
    private init() {}

    var scheduledBlocks: [ScheduledBlock] {
        // derive from feedback entries
        SchedulerFeedbackStore.shared.feedback.map { fb in
            ScheduledBlock(id: fb.blockId, taskId: fb.taskId, start: fb.start, end: fb.end)
        }
    }

    var feedback: [BlockFeedback] {
        SchedulerFeedbackStore.shared.feedback
    }
}
