//
//  TimerAlarmScheduler.swift
//  Roots (iOS)
//

#if os(iOS)
import Foundation

#if canImport(AlarmKit)
import AlarmKit
#endif

final class IOSTimerAlarmScheduler: TimerAlarmScheduling {
    private let settings = AppSettingsModel.shared

    var isEnabled: Bool {
        guard settings.alarmKitTimersEnabled else { return false }
        return alarmKitAvailable
    }

    func scheduleTimerEnd(id: String, fireIn seconds: TimeInterval, title: String, body: String) {
        guard isEnabled else { return }
        // TODO: Replace with AlarmKit scheduling once the API is finalized in this codebase.
    }

    func cancelTimer(id: String) {
        guard isEnabled else { return }
        // TODO: Replace with AlarmKit cancellation once the API is finalized in this codebase.
    }

    private var alarmKitAvailable: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 17.0, *) {
            return true
        }
        return false
        #else
        return false
        #endif
    }
}
#endif
