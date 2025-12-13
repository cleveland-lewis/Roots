import Foundation
import Combine

@MainActor
final class FocusManager: ObservableObject {
    @Published var mode: LocalTimerMode = .pomodoro
    @Published var activities: [LocalTimerActivity] = []
    @Published var selectedActivityID: UUID? = nil

    @Published var isRunning: Bool = false
    @Published var remainingSeconds: TimeInterval = 25 * 60
    @Published var elapsedSeconds: TimeInterval = 0
    @Published var pomodoroSessions: Int = 4
    @Published var completedPomodoroSessions: Int = 0
    @Published var isPomodorBreak: Bool = false
    @Published var activeSession: LocalTimerSession? = nil
    @Published var sessions: [LocalTimerSession] = []
    
    private var timerCancellable: AnyCancellable?
    @Published var settings: AppSettingsModel = AppSettingsModel.shared
    
    init() {
        pomodoroSessions = settings.pomodoroIterations
    }

    func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        if activeSession == nil, let activity = activities.first(where: { $0.id == selectedActivityID }) {
            activeSession = LocalTimerSession(id: UUID(), activityID: activity.id, mode: mode, startDate: Date(), endDate: nil, duration: 0)
        }
    }

    func pauseTimer() {
        isRunning = false
    }

    func resetTimer() {
        isRunning = false
        elapsedSeconds = 0
        remainingSeconds = 25 * 60
        completedPomodoroSessions = 0
        isPomodorBreak = false
    }
    
    func endTimerSession() {
        pauseTimer()
        if var session = activeSession {
            session.endDate = Date()
            let elapsed = Date().timeIntervalSince(session.startDate)
            session.duration = elapsed
            logSession(session)
            sessions.append(session)
            activeSession = nil
        }
        resetTimer()
    }

    func tick() {
        guard isRunning else { return }

        switch mode {
        case .pomodoro, .countdown:
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                completeCurrentBlock()
            }
        case .stopwatch:
            elapsedSeconds += 1
        }
    }

    func completeCurrentBlock() {
        isRunning = false
        let duration: TimeInterval
        switch mode {
        case .stopwatch:
            duration = elapsedSeconds
            elapsedSeconds = 0
        case .pomodoro:
            duration = 25 * 60 - remainingSeconds
            
            if isPomodorBreak {
                completedPomodoroSessions += 1
                isPomodorBreak = false
                remainingSeconds = 25 * 60
            } else {
                isPomodorBreak = true
                
                let longBreakCadence = settings.longBreakCadence
                let isLongBreak = (completedPomodoroSessions + 1) % longBreakCadence == 0
                
                if isLongBreak {
                    remainingSeconds = TimeInterval(settings.pomodoroLongBreakMinutes * 60)
                } else {
                    remainingSeconds = TimeInterval(settings.pomodoroShortBreakMinutes * 60)
                }
            }
        case .countdown:
            duration = 25 * 60 - remainingSeconds
            remainingSeconds = 25 * 60
        }

        if var session = activeSession {
            session.endDate = Date()
            session.duration = duration
            logSession(session)
            sessions.append(session)
        }
        activeSession = nil
    }

    private func logSession(_ session: LocalTimerSession) {
        guard let idx = activities.firstIndex(where: { $0.id == session.activityID }) else { return }
        activities[idx].todayTrackedSeconds += session.duration
        activities[idx].totalTrackedSeconds += session.duration
    }
}
