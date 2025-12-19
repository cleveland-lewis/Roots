import Foundation
import Combine
import UserNotifications
import _Concurrency

@MainActor
final class TimerPageViewModel: ObservableObject {
    // Activities & collections
    @Published var activities: [TimerActivity] = []
    @Published var collections: [ActivityCollection] = []
    @Published var selectedCollectionID: UUID?
    @Published var currentActivityID: UUID?

    // Time & mode
    @Published var currentMode: TimerMode = .pomodoro
    @Published var currentSession: FocusSession?
    @Published var pastSessions: [FocusSession] = []

    // Live clock
    @Published var now: Date = .init()

    // Timer internals
    @Published var sessionElapsed: TimeInterval = 0
    @Published var sessionRemaining: TimeInterval = 0
    @Published var focusDuration: TimeInterval = 25 * 60
    @Published var breakDuration: TimeInterval = 5 * 60
    @Published var timerDuration: TimeInterval = 30 * 60
    @Published var isOnBreak: Bool = false

    private var timerCancellable: AnyCancellable?
    private var clockCancellable: AnyCancellable?
    private var hasRequestedNotificationPermission = false
    var alarmScheduler: TimerAlarmScheduling?
    private let persistenceQueue = DispatchQueue(label: "timer.persistence.queue", qos: .utility)

    // Mode binding - assume a shared selector writes to this or inject externally
    var modeCancellable: AnyCancellable?

    init() {
        loadPersistedState()
        if activities.isEmpty && collections.isEmpty && pastSessions.isEmpty {
            loadPlaceholderData()
        }
        startClock()
        requestNotificationPermissionIfNeeded()
    }

    @MainActor
    deinit {
        // Cancel observables synchronously - no Task needed since these are already on MainActor
        stopClock()
        modeCancellable?.cancel()
    }

    // MARK: - Clock
    func startClock() {
        clockCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                now = date
                tickSession()
            }
    }

    func stopClock() {
        clockCancellable?.cancel()
        clockCancellable = nil
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - CRUD for activities
    func addActivity(_ activity: TimerActivity) {
        activities.append(activity)
        persistState()
    }

    func updateActivity(_ activity: TimerActivity) {
        if let idx = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[idx] = activity
            persistState()
        }
    }

    func deleteActivity(id: UUID) {
        activities.removeAll { $0.id == id }
        if currentActivityID == id { currentActivityID = nil }
        persistState()
    }

    func selectActivity(_ id: UUID?) {
        currentActivityID = id
        persistState()
    }

    var filteredActivities: [TimerActivity] {
        guard let coll = selectedCollectionID else { return activities }
        return activities.filter { $0.collectionID == coll }
    }

    // MARK: - Collections
    func addCollection(_ c: ActivityCollection) {
        collections.append(c)
        persistState()
    }

    func updateCollection(_ c: ActivityCollection) {
        if let idx = collections.firstIndex(where: { $0.id == c.id }) {
            collections[idx] = c
            persistState()
        }
    }

    func deleteCollection(id: UUID) {
        collections.removeAll { $0.id == id }
        if selectedCollectionID == id { selectedCollectionID = nil }
        persistState()
    }

    // MARK: - Sessions
    func startSession(plannedDuration: TimeInterval? = nil) {
        guard currentSession?.state != .running else { return }
        requestNotificationPermissionIfNeeded()
        let planned: TimeInterval?
        switch currentMode {
        case .pomodoro:
            planned = isOnBreak ? breakDuration : focusDuration
        case .timer:
            planned = plannedDuration ?? timerDuration
        case .stopwatch:
            planned = nil
        }

        let session = FocusSession(activityID: currentActivityID, mode: currentMode, plannedDuration: planned, startedAt: Date(), state: .running)
        currentSession = session
        sessionElapsed = 0
        sessionRemaining = planned ?? 0

        LOG_UI(.info, "Timer", "Started session \(session.id) for activity=\(String(describing: session.activityID)) mode=\(currentMode.rawValue)")
        scheduleCompletionNotification()
        persistState()
    }

    func pauseSession() {
        guard var s = currentSession, s.state == .running else { return }
        s.state = .paused
        currentSession = s
        LOG_UI(.info, "Timer", "Paused session \(s.id)")
        cancelCompletionNotification()
        persistState()
    }

    func resumeSession() {
        guard var s = currentSession, s.state == .paused else { return }
        requestNotificationPermissionIfNeeded()
        s.state = .running
        currentSession = s
        LOG_UI(.info, "Timer", "Resumed session \(s.id)")
        scheduleCompletionNotification()
        persistState()
    }

    func endSession(completed: Bool) {
        guard var s = currentSession else { return }
        s.state = completed ? .completed : .cancelled
        s.endedAt = Date()
        s.actualDuration = sessionElapsed
        pastSessions.append(s)
        currentSession = nil
        sessionElapsed = 0
        sessionRemaining = 0
        if s.mode == .pomodoro && completed {
            isOnBreak.toggle()
        }
        LOG_UI(.info, "Timer", "Ended session \(s.id) completed=\(completed)")
        cancelCompletionNotification()
        persistState()
    }
    
    /// Skip current Pomodoro segment and advance to the next one
    func skipSegment() {
        guard let session = currentSession, session.mode == .pomodoro else { return }
        guard session.state == .running else { return }
        
        LOG_UI(.info, "Timer", "Skipping Pomodoro segment - was on break: \(isOnBreak)")
        
        // End current segment without counting remaining time as study time
        // Mark as completed to trigger the break toggle
        endSession(completed: true)
        
        // Automatically start the next segment
        startSession()
    }

    func sessions(for activityID: UUID?) -> [FocusSession] {
        pastSessions.filter { $0.activityID == activityID }
    }

    // MARK: - Internals
    private func tickSession() {
        guard let session = currentSession, session.state == .running else { return }
        sessionElapsed += 1

        if let planned = session.plannedDuration {
            sessionRemaining = max(planned - sessionElapsed, 0)
            if sessionRemaining == 0 {
                endSession(completed: true)
                return
            }
        } else {
            sessionRemaining = 0
        }
        currentSession = session
    }

    // MARK: - Notifications
    private func requestNotificationPermissionIfNeeded() {
        guard !hasRequestedNotificationPermission else { return }
        hasRequestedNotificationPermission = true
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    LOG_UI(.info, "Timer", "Notification permission granted")
                } else if let error {
                    LOG_UI(.error, "Timer", "Notification permission error: \(error.localizedDescription)")
                } else {
                    LOG_UI(.info, "Timer", "Notification permission denied or dismissed")
                }
            }
        }
    }

    private func scheduleCompletionNotification() {
        guard let session = currentSession, session.state == .running else { return }
        guard session.mode != .stopwatch else { return }
        if session.mode == .timer && !AppSettingsModel.shared.timerAlertsEnabled { return }
        if session.mode == .pomodoro && !AppSettingsModel.shared.pomodoroAlertsEnabled { return }
        cancelCompletionNotification()

        let remaining = sessionRemaining > 0 ? sessionRemaining : (session.plannedDuration ?? 0) - sessionElapsed
        guard remaining > 0 else { return }

        let title = session.mode == .pomodoro ? "Pomodoro Complete" : "Timer Finished"
        let body = "Time to take a break or switch tasks!"
        if alarmScheduler?.isEnabled == true {
            alarmScheduler?.scheduleTimerEnd(id: "RootsTimerCompletion", fireIn: remaining, title: title, body: body)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        let request = UNNotificationRequest(identifier: "RootsTimerCompletion", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                LOG_UI(.error, "Timer", "Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    private func cancelCompletionNotification() {
        alarmScheduler?.cancelTimer(id: "RootsTimerCompletion")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["RootsTimerCompletion"])
    }

    // MARK: - Persistence
    private struct TimerPersistedState: Codable {
        var activities: [TimerActivity]
        var collections: [ActivityCollection]
        var pastSessions: [FocusSession]
        var selectedCollectionID: UUID?
        var currentActivityID: UUID?
        var currentMode: TimerMode
        var isOnBreak: Bool
        var focusDuration: TimeInterval
        var breakDuration: TimeInterval
        var timerDuration: TimeInterval
    }

    private var stateURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("TimerState.json")
    }

    private func loadPersistedState() {
        let url = stateURL
        persistenceQueue.async {
            guard let data = try? Data(contentsOf: url) else { return }
            guard let decoded = try? JSONDecoder().decode(TimerPersistedState.self, from: data) else { return }
            DispatchQueue.main.async {
                self.activities = decoded.activities
                self.collections = decoded.collections
                self.pastSessions = decoded.pastSessions
                self.selectedCollectionID = decoded.selectedCollectionID
                self.currentActivityID = decoded.currentActivityID
                self.currentMode = decoded.currentMode
                self.isOnBreak = decoded.isOnBreak
                self.focusDuration = decoded.focusDuration
                self.breakDuration = decoded.breakDuration
                self.timerDuration = decoded.timerDuration
            }
        }
    }

    private func persistState() {
        let snapshot = TimerPersistedState(
            activities: activities,
            collections: collections,
            pastSessions: pastSessions,
            selectedCollectionID: selectedCollectionID,
            currentActivityID: currentActivityID,
            currentMode: currentMode,
            isOnBreak: isOnBreak,
            focusDuration: focusDuration,
            breakDuration: breakDuration,
            timerDuration: timerDuration
        )
        let url = stateURL
        persistenceQueue.async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                LOG_UI(.error, "Timer", "Failed to persist timer state: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Placeholder data
    private func loadPlaceholderData() {
        let deepWork = ActivityCollection(name: "Deep Work", description: "Long focus blocks")
        let math = ActivityCollection(name: "Math", description: "Problem solving")
        collections = [deepWork, math]

        activities = [
            TimerActivity(name: "Reading — Biology", note: "Chapters 4-6", studyCategory: .reading, collectionID: deepWork.id, emoji: "📚"),
            TimerActivity(name: "Problem Set — Calculus", studyCategory: .problemSolving, collectionID: math.id, emoji: "✏️"),
            TimerActivity(name: "Review Notes", studyCategory: .reviewing, collectionID: deepWork.id, emoji: "📝"),
            TimerActivity(name: "Essay Draft", studyCategory: .writing, collectionID: nil, emoji: "🖋️")
        ]
        currentActivityID = activities.first?.id

        pastSessions = [
            FocusSession(activityID: activities.first?.id, mode: .pomodoro, plannedDuration: focusDuration, startedAt: Date().addingTimeInterval(-3600), endedAt: Date().addingTimeInterval(-3300), state: .completed, actualDuration: 3000),
            FocusSession(activityID: activities[1].id, mode: .timer, plannedDuration: 1800, startedAt: Date().addingTimeInterval(-7200), endedAt: Date().addingTimeInterval(-7000), state: .completed, actualDuration: 2000)
        ]
    }
}
