import Foundation
import Combine

@MainActor
final class TimerPageViewModel: ObservableObject {
    @Published var activities: [TimerActivity] = []
    @Published var collections: [ActivityCollection] = []
    @Published var selectedCollectionID: UUID? = nil
    @Published var currentActivityID: UUID? = nil
    @Published var currentMode: TimerMode = .omodoro
    @Published var currentSession: FocusSession? = nil
    @Published var pastSessions: [FocusSession] = []

    // Mode binding - assume a shared selector writes to this or inject externally
    var modeCancellable: AnyCancellable?

    init() {
        // Load placeholder data
        loadPlaceholderData()
    }

    deinit {
        modeCancellable?.cancel()
    }

    // MARK: - CRUD for activities
    func addActivity(_ activity: TimerActivity) {
        activities.append(activity)
    }

    func updateActivity(_ activity: TimerActivity) {
        if let idx = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[idx] = activity
        }
    }

    func deleteActivity(id: UUID) {
        activities.removeAll { $0.id == id }
    }

    func selectActivity(_ id: UUID?) {
        currentActivityID = id
    }

    var filteredActivities: [TimerActivity] {
        if let coll = selectedCollectionID {
            return activities.filter { $0.collectionID == coll }
        }
        return activities
    }

    // MARK: - Collections
    func addCollection(_ c: ActivityCollection) {
        collections.append(c)
    }

    func updateCollection(_ c: ActivityCollection) {
        if let idx = collections.firstIndex(where: { $0.id == c.id }) { collections[idx] = c }
    }

    func deleteCollection(id: UUID) {
        collections.removeAll { $0.id == id }
    }

    // MARK: - Sessions
    func startSession(mode: TimerMode, plannedDuration: TimeInterval? = nil) {
        if let s = currentSession, s.state == .running { return }
        let session = FocusSession(activityID: currentActivityID, mode: mode, plannedDuration: plannedDuration, startedAt: Date(), state: .running)
        currentSession = session
        LOG_UI(.info, "Timer", "Started session \(session.id) for activity=\(String(describing: session.activityID)) mode=\(mode.rawValue)")
    }

    func pauseSession() {
        guard var s = currentSession else { return }
        s.state = .paused
        currentSession = s
        LOG_UI(.info, "Timer", "Paused session \(s.id)")
    }

    func resumeSession() {
        guard var s = currentSession else { return }
        s.state = .running
        currentSession = s
        LOG_UI(.info, "Timer", "Resumed session \(s.id)")
    }

    func endSession(completed: Bool) {
        guard var s = currentSession else { return }
        s.state = completed ? .completed : .cancelled
        s.endedAt = Date()
        pastSessions.append(s)
        LOG_UI(.info, "Timer", "Ended session \(s.id) completed=\(completed)")
        currentSession = nil
    }

    // MARK: - Placeholder data
    private func loadPlaceholderData() {
        // Minimal placeholder activities and collections
        let coll = ActivityCollection(name: "Default")
        collections = [coll]

        activities = [
            TimerActivity(name: "Reading Math", studyCategory: .reading, collectionID: coll.id, emoji: "📘"),
            TimerActivity(name: "Problem Set", studyCategory: .problemSolving, collectionID: coll.id, emoji: "✏️"),
            TimerActivity(name: "Review Notes", studyCategory: .reviewing, collectionID: coll.id, emoji: "📝")
        ]
    }
}
