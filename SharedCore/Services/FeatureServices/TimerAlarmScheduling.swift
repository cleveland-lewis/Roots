import Foundation

protocol TimerAlarmScheduling {
    var isEnabled: Bool { get }
    func scheduleTimerEnd(id: String, fireIn seconds: TimeInterval, title: String, body: String)
    func cancelTimer(id: String)
}
