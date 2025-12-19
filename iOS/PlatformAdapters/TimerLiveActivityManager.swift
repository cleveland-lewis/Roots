//
//  TimerLiveActivityManager.swift
//  Roots (iOS)
//

#if os(iOS)
import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct TimerLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var mode: String
        var label: String
        var remainingSeconds: Int
        var elapsedSeconds: Int
        var isRunning: Bool
        var isOnBreak: Bool
    }

    var activityID: String
}

final class IOSTimerLiveActivityManager: ObservableObject {
    private var activity: Any?
    private var lastUpdate: Date?
    private let minUpdateInterval: TimeInterval = 1.0

    func sync(currentMode: TimerMode, session: FocusSession?, elapsed: TimeInterval, remaining: TimeInterval, isOnBreak: Bool) {
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Task { await end() }
            return
        }

        guard let session else {
            Task { await end() }
            return
        }

        if session.state == .completed || session.state == .cancelled {
            Task { await end() }
            return
        }

        let label: String
        if currentMode == .pomodoro {
            label = isOnBreak ? "Break" : "Work"
        } else {
            label = currentMode.displayName
        }

        let contentState = TimerLiveActivityAttributes.ContentState(
            mode: currentMode.displayName,
            label: label,
            remainingSeconds: max(Int(remaining.rounded()), 0),
            elapsedSeconds: max(Int(elapsed.rounded()), 0),
            isRunning: session.state == .running,
            isOnBreak: isOnBreak
        )

        if activity == nil {
            let attributes = TimerLiveActivityAttributes(activityID: session.id.uuidString)
            Task { await start(attributes: attributes, contentState: contentState) }
            return
        }

        Task { await update(contentState: contentState) }
    }

    @available(iOS 16.1, *)
    private func start(attributes: TimerLiveActivityAttributes, contentState: TimerLiveActivityAttributes.ContentState) async {
        do {
            activity = try Activity.request(attributes: attributes, contentState: contentState, pushType: nil)
            lastUpdate = Date()
        } catch {
            activity = nil
        }
    }

    @available(iOS 16.1, *)
    private func update(contentState: TimerLiveActivityAttributes.ContentState) async {
        let now = Date()
        if let last = lastUpdate, now.timeIntervalSince(last) < minUpdateInterval {
            return
        }
        lastUpdate = now
        (activity as? Activity<TimerLiveActivityAttributes>)?.update(using: contentState)
    }

    func end() async {
        guard #available(iOS 16.1, *) else { return }
        guard let live = activity as? Activity<TimerLiveActivityAttributes> else { return }
        await live.end(dismissalPolicy: .immediate)
        activity = nil
        lastUpdate = nil
    }
}
#else
final class IOSTimerLiveActivityManager: ObservableObject {
    func sync(currentMode: TimerMode, session: FocusSession?, elapsed: TimeInterval, remaining: TimeInterval, isOnBreak: Bool) {}
}
#endif
#endif
