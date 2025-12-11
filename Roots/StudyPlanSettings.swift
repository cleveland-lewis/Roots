import SwiftUI
import Combine

@MainActor
final class StudyPlanSettings: ObservableObject {
    static let shared = StudyPlanSettings()
    
    @Published var dailyGoalMinutes: Int = 240  // 4 hours default
    @Published var notificationsEnabled: Bool = true
    @Published var theme: String = "default"
    
    // Workday window
    @Published var workdayStartHour: Int = 8
    @Published var workdayStartMinute: Int = 0
    @Published var workdayEndHour: Int = 22
    @Published var workdayEndMinute: Int = 0
    
    // Break preferences
    @Published var autoScheduleBreaks: Bool = true
    @Published var breakDurationMinutes: Int = 15
    @Published var hoursBeforeBreak: Double = 2.0
    
    // Study preferences
    @Published var preferMorningSessions: Bool = false
    @Published var preferEveningSessions: Bool = false
    @Published var maxSessionLengthMinutes: Int = 120
    @Published var minSessionLengthMinutes: Int = 30
    
    private init() {
        load()
    }
    
    func reset() {
        dailyGoalMinutes = 240
        notificationsEnabled = true
        theme = "default"
        workdayStartHour = 8
        workdayStartMinute = 0
        workdayEndHour = 22
        workdayEndMinute = 0
        autoScheduleBreaks = true
        breakDurationMinutes = 15
        hoursBeforeBreak = 2.0
        preferMorningSessions = false
        preferEveningSessions = false
        maxSessionLengthMinutes = 120
        minSessionLengthMinutes = 30
        save()
    }
    
    // MARK: - Computed properties
    
    var workdayStart: DateComponents {
        DateComponents(hour: workdayStartHour, minute: workdayStartMinute)
    }
    
    var workdayEnd: DateComponents {
        DateComponents(hour: workdayEndHour, minute: workdayEndMinute)
    }
    
    // MARK: - Persistence
    
    private func save() {
        UserDefaults.standard.set(dailyGoalMinutes, forKey: "studyplan.dailyGoalMinutes")
        UserDefaults.standard.set(notificationsEnabled, forKey: "studyplan.notificationsEnabled")
        UserDefaults.standard.set(theme, forKey: "studyplan.theme")
        UserDefaults.standard.set(workdayStartHour, forKey: "studyplan.workdayStartHour")
        UserDefaults.standard.set(workdayStartMinute, forKey: "studyplan.workdayStartMinute")
        UserDefaults.standard.set(workdayEndHour, forKey: "studyplan.workdayEndHour")
        UserDefaults.standard.set(workdayEndMinute, forKey: "studyplan.workdayEndMinute")
        UserDefaults.standard.set(autoScheduleBreaks, forKey: "studyplan.autoScheduleBreaks")
        UserDefaults.standard.set(breakDurationMinutes, forKey: "studyplan.breakDurationMinutes")
        UserDefaults.standard.set(hoursBeforeBreak, forKey: "studyplan.hoursBeforeBreak")
        UserDefaults.standard.set(preferMorningSessions, forKey: "studyplan.preferMorningSessions")
        UserDefaults.standard.set(preferEveningSessions, forKey: "studyplan.preferEveningSessions")
        UserDefaults.standard.set(maxSessionLengthMinutes, forKey: "studyplan.maxSessionLengthMinutes")
        UserDefaults.standard.set(minSessionLengthMinutes, forKey: "studyplan.minSessionLengthMinutes")
    }
    
    private func load() {
        if UserDefaults.standard.object(forKey: "studyplan.dailyGoalMinutes") != nil {
            dailyGoalMinutes = UserDefaults.standard.integer(forKey: "studyplan.dailyGoalMinutes")
        }
        if UserDefaults.standard.object(forKey: "studyplan.notificationsEnabled") != nil {
            notificationsEnabled = UserDefaults.standard.bool(forKey: "studyplan.notificationsEnabled")
        }
        if let savedTheme = UserDefaults.standard.string(forKey: "studyplan.theme") {
            theme = savedTheme
        }
        if UserDefaults.standard.object(forKey: "studyplan.workdayStartHour") != nil {
            workdayStartHour = UserDefaults.standard.integer(forKey: "studyplan.workdayStartHour")
        }
        if UserDefaults.standard.object(forKey: "studyplan.workdayStartMinute") != nil {
            workdayStartMinute = UserDefaults.standard.integer(forKey: "studyplan.workdayStartMinute")
        }
        if UserDefaults.standard.object(forKey: "studyplan.workdayEndHour") != nil {
            workdayEndHour = UserDefaults.standard.integer(forKey: "studyplan.workdayEndHour")
        }
        if UserDefaults.standard.object(forKey: "studyplan.workdayEndMinute") != nil {
            workdayEndMinute = UserDefaults.standard.integer(forKey: "studyplan.workdayEndMinute")
        }
        if UserDefaults.standard.object(forKey: "studyplan.autoScheduleBreaks") != nil {
            autoScheduleBreaks = UserDefaults.standard.bool(forKey: "studyplan.autoScheduleBreaks")
        }
        if UserDefaults.standard.object(forKey: "studyplan.breakDurationMinutes") != nil {
            breakDurationMinutes = UserDefaults.standard.integer(forKey: "studyplan.breakDurationMinutes")
        }
        if UserDefaults.standard.object(forKey: "studyplan.hoursBeforeBreak") != nil {
            hoursBeforeBreak = UserDefaults.standard.double(forKey: "studyplan.hoursBeforeBreak")
        }
        if UserDefaults.standard.object(forKey: "studyplan.preferMorningSessions") != nil {
            preferMorningSessions = UserDefaults.standard.bool(forKey: "studyplan.preferMorningSessions")
        }
        if UserDefaults.standard.object(forKey: "studyplan.preferEveningSessions") != nil {
            preferEveningSessions = UserDefaults.standard.bool(forKey: "studyplan.preferEveningSessions")
        }
        if UserDefaults.standard.object(forKey: "studyplan.maxSessionLengthMinutes") != nil {
            maxSessionLengthMinutes = UserDefaults.standard.integer(forKey: "studyplan.maxSessionLengthMinutes")
        }
        if UserDefaults.standard.object(forKey: "studyplan.minSessionLengthMinutes") != nil {
            minSessionLengthMinutes = UserDefaults.standard.integer(forKey: "studyplan.minSessionLengthMinutes")
        }
    }
}
