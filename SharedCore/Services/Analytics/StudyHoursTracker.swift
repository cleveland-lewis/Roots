//
//  StudyHoursTracker.swift
//  Roots
//
//  Tracks study hours based on completed timer sessions
//

import Foundation
import Combine

/// Service for tracking and aggregating study hours
@MainActor
public final class StudyHoursTracker: ObservableObject {
    public static let shared = StudyHoursTracker()
    
    @Published public private(set) var totals: StudyHoursTotals
    
    private let storageURL: URL
    private let completedSessionsURL: URL
    private var completedSessionIds: Set<UUID> = []
    
    private init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = dir.appendingPathComponent("RootsAnalytics", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        
        self.storageURL = folder.appendingPathComponent("study_hours.json")
        self.completedSessionsURL = folder.appendingPathComponent("completed_sessions.json")
        
        // Load persisted data
        self.totals = Self.loadTotals(from: storageURL)
        self.completedSessionIds = Self.loadCompletedSessionIds(from: completedSessionsURL)
        
        // Check for date rollover and reset if needed
        checkAndResetIfNeeded()
    }
    
    // MARK: - Public API
    
    /// Record a completed session (idempotent - won't double-count same session)
    public func recordCompletedSession(sessionId: UUID, durationMinutes: Int) {
        // Only track if setting is enabled
        guard AppSettingsModel.shared.trackStudyHours else { return }
        
        // Idempotency check
        guard !completedSessionIds.contains(sessionId) else {
            LOG_UI(.debug, "StudyHoursTracker", "Session \(sessionId) already recorded, skipping")
            return
        }
        
        // Check for date rollover
        checkAndResetIfNeeded()
        
        // Update totals
        totals.todayMinutes += durationMinutes
        totals.weekMinutes += durationMinutes
        totals.monthMinutes += durationMinutes
        
        // Mark session as recorded
        completedSessionIds.insert(sessionId)
        
        // Persist
        saveTotals()
        saveCompletedSessionIds()
        
        LOG_UI(.info, "StudyHoursTracker", "Recorded session: \(durationMinutes) minutes. Today: \(totals.todayMinutes)m, Week: \(totals.weekMinutes)m")
    }
    
    /// Reset all totals (for testing or user action)
    public func resetAllTotals() {
        totals = StudyHoursTotals()
        completedSessionIds.removeAll()
        saveTotals()
        saveCompletedSessionIds()
    }
    
    // MARK: - Date Rollover Logic
    
    private func checkAndResetIfNeeded() {
        let calendar = Calendar.current
        let now = Date()
        
        let lastResetDay = calendar.startOfDay(for: totals.lastResetDate)
        let today = calendar.startOfDay(for: now)
        
        guard lastResetDay < today else { return }
        
        // Day has changed - reset daily total
        totals.todayMinutes = 0
        
        // Check if week has changed
        if !calendar.isDate(totals.lastResetDate, equalTo: now, toGranularity: .weekOfYear) {
            totals.weekMinutes = 0
        }
        
        // Check if month has changed
        if !calendar.isDate(totals.lastResetDate, equalTo: now, toGranularity: .month) {
            totals.monthMinutes = 0
        }
        
        totals.lastResetDate = now
        saveTotals()
    }
    
    // MARK: - Persistence
    
    private func saveTotals() {
        do {
            let data = try JSONEncoder().encode(totals)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            LOG_UI(.error, "StudyHoursTracker", "Failed to save totals: \(error)")
        }
    }
    
    private static func loadTotals(from url: URL) -> StudyHoursTotals {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return StudyHoursTotals()
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(StudyHoursTotals.self, from: data)
        } catch {
            print("Failed to load study hours totals: \(error)")
            return StudyHoursTotals()
        }
    }
    
    private func saveCompletedSessionIds() {
        do {
            let array = Array(completedSessionIds)
            let data = try JSONEncoder().encode(array)
            try data.write(to: completedSessionsURL, options: [.atomic])
        } catch {
            LOG_UI(.error, "StudyHoursTracker", "Failed to save completed sessions: \(error)")
        }
    }
    
    private static func loadCompletedSessionIds(from url: URL) -> Set<UUID> {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let array = try JSONDecoder().decode([UUID].self, from: data)
            return Set(array)
        } catch {
            print("Failed to load completed session IDs: \(error)")
            return []
        }
    }
}
