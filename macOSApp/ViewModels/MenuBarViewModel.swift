import Foundation
import Combine
import SwiftUI

class MenuBarViewModel: ObservableObject {
    @Published var mode: LocalTimerMode = .pomodoro
    @Published var isRunning: Bool = false
    @Published var remainingSeconds: TimeInterval = 0
    @Published var elapsedSeconds: TimeInterval = 0
    @Published var pomodoroSessions: Int = 0
    @Published var completedPomodoroSessions: Int = 0
    @Published var isPomodorBreak: Bool = false
    @Published var selectedActivityID: UUID? = nil
    @Published var activities: [LocalTimerActivity] = []
    @Published var sessions: [LocalTimerSession] = []
}
