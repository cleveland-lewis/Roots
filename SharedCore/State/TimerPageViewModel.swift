import Foundation
import Combine
import CoreData
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
    @Published var longBreakDuration: TimeInterval = 15 * 60
    @Published var timerDuration: TimeInterval = 30 * 60
    @Published var isOnBreak: Bool = false
    @Published var pomodoroCompletedCycles: Int = 0
    @Published var pomodoroMaxCycles: Int = 4

    private var timerCancellable: AnyCancellable?
    private var clockCancellable: AnyCancellable?
    private var hasRequestedNotificationPermission = false
    var alarmScheduler: TimerAlarmScheduling?
    private let persistenceQueue = DispatchQueue(label: "timer.persistence.queue", qos: .utility)
    private let persistence = PersistenceController.shared

    // Mode binding - assume a shared selector writes to this or inject externally
    var modeCancellable: AnyCancellable?

    init() {
        loadPersistedSessions()
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
            if isOnBreak {
                // Determine if this is a long break or short break
                let isLongBreak = pomodoroCompletedCycles >= pomodoroMaxCycles
                planned = isLongBreak ? longBreakDuration : breakDuration
            } else {
                planned = focusDuration
            }
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
        
        // Play timer start feedback (audio + haptic)
        Task { @MainActor in
            AudioFeedbackService.shared.playTimerStart()
            Feedback.shared.timerStart()
        }
        
        scheduleCompletionNotification()
        persistState()
    }

    func pauseSession() {
        guard var s = currentSession, s.state == .running else { return }
        s.state = .paused
        currentSession = s
        LOG_UI(.info, "Timer", "Paused session \(s.id)")
        
        // Play pause feedback (audio + haptic)
        Task { @MainActor in
            AudioFeedbackService.shared.playTimerPause()
            Feedback.shared.timerStop()
        }
        
        cancelCompletionNotification()
        persistState()
    }

    func resumeSession() {
        guard var s = currentSession, s.state == .paused else { return }
        requestNotificationPermissionIfNeeded()
        s.state = .running
        currentSession = s
        LOG_UI(.info, "Timer", "Resumed session \(s.id)")
        
        // Play resume feedback (same as start)
        Task { @MainActor in
            AudioFeedbackService.shared.playTimerStart()
            Feedback.shared.timerStart()
        }
        
        scheduleCompletionNotification()
        persistState()
    }

    func endSession(completed: Bool) {
        guard var s = currentSession else { return }
        s.state = completed ? .completed : .cancelled
        s.endedAt = Date()
        s.actualDuration = sessionElapsed
        insertPastSession(s)
        upsertSessionInStore(s)
        currentSession = nil
        sessionElapsed = 0
        sessionRemaining = 0
        if s.mode == .pomodoro && completed {
            if !isOnBreak {
                // Completed a focus session, increment cycle count
                pomodoroCompletedCycles += 1
                // Check if we should reset after long break
                if pomodoroCompletedCycles > pomodoroMaxCycles {
                    pomodoroCompletedCycles = 0
                }
            } else {
                // Completed a break session, check if it was a long break to reset cycles
                if pomodoroCompletedCycles >= pomodoroMaxCycles {
                    pomodoroCompletedCycles = 0
                }
            }
            isOnBreak.toggle()
        }
        
        // Track study hours if completed and setting enabled (Phase D)
        if completed, let actualDuration = s.actualDuration {
            let durationMinutes = Int(actualDuration / 60)
            Task { @MainActor in
                StudyHoursTracker.shared.recordCompletedSession(
                    sessionId: s.id,
                    durationMinutes: durationMinutes
                )
            }
        }
        
        // Play end feedback (audio + haptic)
        Task { @MainActor in
            AudioFeedbackService.shared.playTimerEnd()
            if completed {
                Feedback.shared.timerStop()  // Success haptic
            } else {
                Feedback.shared.timerStop()  // Also stop feedback for cancelled
            }
        }
        LOG_UI(.info, "Timer", "Ended session \(s.id) completed=\(completed)")
        cancelCompletionNotification()
        persistState()
    }

#if DEBUG
    func debugAdvance(seconds: TimeInterval) {
        guard var session = currentSession else { return }
        sessionElapsed += seconds
        if let planned = session.plannedDuration {
            sessionRemaining = max(planned - sessionElapsed, 0)
            if sessionRemaining == 0 {
                endSession(completed: true)
                return
            }
        }
        currentSession = session
    }
#endif
    
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
    
    func addManualSession(_ session: FocusSession) {
        insertPastSession(session)
        upsertSessionInStore(session)
        LOG_UI(.info, "Timer", "Manually added session \(session.id) for activity=\(String(describing: session.activityID))")
        persistState()
    }
    
    func deleteSessions(ids: [UUID]) {
        pastSessions.removeAll { ids.contains($0.id) }
        LOG_UI(.info, "Timer", "Deleted \(ids.count) session(s)")
        deleteSessionsFromStore(ids: ids)
        persistState()
    }

    func updateSession(_ session: FocusSession) {
        if let index = pastSessions.firstIndex(where: { $0.id == session.id }) {
            pastSessions[index] = session
            sortPastSessions()
        }
        upsertSessionInStore(session)
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
        var pastSessions: [FocusSession]?
        var selectedCollectionID: UUID?
        var currentActivityID: UUID?
        var currentMode: TimerMode
        var isOnBreak: Bool
        var focusDuration: TimeInterval
        var breakDuration: TimeInterval
        var longBreakDuration: TimeInterval?
        var timerDuration: TimeInterval
        var pomodoroCompletedCycles: Int?
        var pomodoroMaxCycles: Int?
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
            let sessionsToMigrate = decoded.pastSessions ?? []
            DispatchQueue.main.async {
                self.activities = decoded.activities
                self.collections = decoded.collections
                self.selectedCollectionID = decoded.selectedCollectionID
                self.currentActivityID = decoded.currentActivityID
                self.currentMode = decoded.currentMode
                self.isOnBreak = decoded.isOnBreak
                self.focusDuration = decoded.focusDuration
                self.breakDuration = decoded.breakDuration
                self.longBreakDuration = decoded.longBreakDuration ?? 15 * 60
                self.timerDuration = decoded.timerDuration
                self.pomodoroCompletedCycles = decoded.pomodoroCompletedCycles ?? 0
                self.pomodoroMaxCycles = decoded.pomodoroMaxCycles ?? 4
                if !sessionsToMigrate.isEmpty {
                    self.migrateSessions(sessionsToMigrate)
                }
            }
        }
    }

    private func persistState() {
        let snapshot = TimerPersistedState(
            activities: activities,
            collections: collections,
            pastSessions: nil,
            selectedCollectionID: selectedCollectionID,
            currentActivityID: currentActivityID,
            currentMode: currentMode,
            isOnBreak: isOnBreak,
            focusDuration: focusDuration,
            breakDuration: breakDuration,
            longBreakDuration: longBreakDuration,
            timerDuration: timerDuration,
            pomodoroCompletedCycles: pomodoroCompletedCycles,
            pomodoroMaxCycles: pomodoroMaxCycles
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

    private func migrateSessions(_ sessions: [FocusSession]) {
        sessions.forEach { upsertSessionInStore($0) }
        loadPersistedSessions()
    }

    private func loadPersistedSessions() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "TimerSession")
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        do {
            let results = try persistence.viewContext.fetch(request)
            pastSessions = results.compactMap(mapSessionFromStore)
        } catch {
            LOG_DATA(.error, "Timer", "Failed to load timer sessions: \(error.localizedDescription)")
        }
    }

    private func mapSessionFromStore(_ object: NSManagedObject) -> FocusSession? {
        guard let id = object.value(forKey: "id") as? UUID else { return nil }
        let modeRaw = object.value(forKey: "mode") as? String ?? TimerMode.timer.rawValue
        let mode = TimerMode(rawValue: modeRaw) ?? .timer
        let startedAt = object.value(forKey: "startedAt") as? Date
        let endedAt = object.value(forKey: "endedAt") as? Date
        let durationSeconds = object.value(forKey: "durationSeconds") as? Double ?? 0
        let activityID = object.value(forKey: "activityID") as? UUID
        let plannedDuration: TimeInterval? = mode == .stopwatch ? nil : durationSeconds
        let actualDuration: TimeInterval? = durationSeconds > 0 ? durationSeconds : nil
        let state: FocusSession.State = endedAt == nil ? .cancelled : .completed
        return FocusSession(
            id: id,
            activityID: activityID,
            mode: mode,
            plannedDuration: plannedDuration,
            startedAt: startedAt,
            endedAt: endedAt,
            state: state,
            actualDuration: actualDuration
        )
    }

    private func upsertSessionInStore(_ session: FocusSession) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "TimerSession")
        request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        do {
            let existing = try persistence.viewContext.fetch(request).first
            let object = existing ?? NSManagedObject(entity: NSEntityDescription.entity(forEntityName: "TimerSession", in: persistence.viewContext)!, insertInto: persistence.viewContext)
            object.setValue(session.id, forKey: "id")
            object.setValue(session.startedAt ?? Date(), forKey: "startedAt")
            object.setValue(session.endedAt, forKey: "endedAt")
            object.setValue(session.mode.rawValue, forKey: "mode")
            object.setValue(session.activityID, forKey: "activityID")
            let duration = session.actualDuration
                ?? session.plannedDuration
                ?? (session.endedAt.flatMap { end in session.startedAt.map { end.timeIntervalSince($0) } } ?? 0)
            object.setValue(duration, forKey: "durationSeconds")
            persistence.save(context: persistence.viewContext)
        } catch {
            LOG_DATA(.error, "Timer", "Failed to save timer session: \(error.localizedDescription)")
        }
    }

    private func deleteSessionsFromStore(ids: [UUID]) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "TimerSession")
        request.predicate = NSPredicate(format: "id IN %@", ids)
        do {
            let results = try persistence.viewContext.fetch(request)
            results.forEach { persistence.viewContext.delete($0) }
            persistence.save(context: persistence.viewContext)
        } catch {
            LOG_DATA(.error, "Timer", "Failed to delete timer sessions: \(error.localizedDescription)")
        }
    }

    private func insertPastSession(_ session: FocusSession) {
        pastSessions.append(session)
        sortPastSessions()
    }

    private func sortPastSessions() {
        pastSessions.sort { (lhs, rhs) in
            (lhs.startedAt ?? .distantPast) > (rhs.startedAt ?? .distantPast)
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
        pastSessions.forEach { upsertSessionInStore($0) }
    }
}
