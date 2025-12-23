//
//  TimerAlarmScheduler.swift
//  Roots (iOS)
//
//  AlarmKit temporarily disabled for iOS 17 compatibility
//  Original file backed up as TimerAlarmScheduler.swift.ios26_backup
//  Can be restored when iOS 26 is publicly released
//

#if os(iOS)
import Foundation
import SwiftUI

// AlarmKit APIs require iOS 26 beta - temporarily disabled
#if false && canImport(AlarmKit)
import AlarmKit
#endif

/// Stub implementation for iOS 17+ compatibility
/// Alarm notifications temporarily disabled until iOS 26 is stable
final class IOSTimerAlarmScheduler: TimerAlarmScheduling {
    private let settings = AppSettingsModel.shared
    
    var isEnabled: Bool {
        // AlarmKit disabled - requires iOS 26 beta
        return false
    }
    
    func scheduleTimerEnd(id: String, fireIn seconds: TimeInterval, title: String, body: String) {
        // AlarmKit temporarily disabled
        // No-op for now
    }
    
    func cancelTimer(id: String) {
        // No-op
    }
    
    func requestAuthorizationIfNeeded() async -> Bool {
        // AlarmKit disabled - return false
        return false
    }
}

#endif
