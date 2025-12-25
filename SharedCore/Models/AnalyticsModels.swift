//
//  AnalyticsModels.swift
//  Roots
//
//  Study hours tracking models
//

import Foundation

/// Aggregated study time totals for display
public struct StudyHoursTotals: Codable, Equatable {
    public var todayMinutes: Int
    public var weekMinutes: Int
    public var monthMinutes: Int
    
    /// Last date when daily totals were reset (for detecting day rollover)
    public var lastResetDate: Date
    
    public init(todayMinutes: Int = 0, weekMinutes: Int = 0, monthMinutes: Int = 0, lastResetDate: Date = Date()) {
        self.todayMinutes = todayMinutes
        self.weekMinutes = weekMinutes
        self.monthMinutes = monthMinutes
        self.lastResetDate = lastResetDate
    }
    
    // MARK: - Formatting Helpers
    
    /// Format minutes as "Xh Ym" or "Xm" if less than an hour
    public static func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }
    
    /// Today's hours in decimal format
    public var todayHours: Double {
        Double(todayMinutes) / 60.0
    }
    
    /// This week's hours in decimal format
    public var weekHours: Double {
        Double(weekMinutes) / 60.0
    }
    
    /// This month's hours in decimal format
    public var monthHours: Double {
        Double(monthMinutes) / 60.0
    }
}

/// Completed session record for tracking (idempotency key)
struct CompletedSessionRecord: Codable {
    let sessionId: UUID
    let completedAt: Date
    let durationMinutes: Int
    
    init(sessionId: UUID, completedAt: Date, durationMinutes: Int) {
        self.sessionId = sessionId
        self.completedAt = completedAt
        self.durationMinutes = durationMinutes
    }
}
