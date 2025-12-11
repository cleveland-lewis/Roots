import Foundation

// Study session model used by the planner
struct StudySession: Identifiable, Hashable, Codable {
    let id: UUID
    var assignmentId: UUID
    var title: String
    var dueDate: Date
    var estimatedMinutes: Int
    var isLockedToDueDate: Bool
    var category: AssignmentCategory
    var importance: AssignmentUrgency
    var difficulty: AssignmentUrgency
    
    init(id: UUID = UUID(), assignmentId: UUID, title: String, dueDate: Date, estimatedMinutes: Int = 60, isLockedToDueDate: Bool = false, category: AssignmentCategory = .homework, importance: AssignmentUrgency = .medium, difficulty: AssignmentUrgency = .medium) {
        self.id = id
        self.assignmentId = assignmentId
        self.title = title
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.isLockedToDueDate = isLockedToDueDate
        self.category = category
        self.importance = importance
        self.difficulty = difficulty
    }
}

// Scheduled session with time slot
struct ScheduledSession: Identifiable, Hashable, Codable {
    let id: UUID
    var session: StudySession
    var start: Date
    var end: Date
    
    init(id: UUID = UUID(), session: StudySession, start: Date, end: Date) {
        self.id = id
        self.session = session
        self.start = start
        self.end = end
    }
}

// Schedule result containing scheduled and overflow sessions
struct ScheduleResult {
    var scheduled: [ScheduledSession]
    var overflow: [StudySession]
}

// Energy profile for scheduling
struct EnergyProfile: Codable {
    var morningEnergy: Double = 0.7
    var afternoonEnergy: Double = 0.8
    var eveningEnergy: Double = 0.6
    
    func energy(at hour: Int) -> Double {
        switch hour {
        case 6..<12: return morningEnergy
        case 12..<17: return afternoonEnergy
        case 17..<23: return eveningEnergy
        default: return 0.5
        }
    }
}

/// Planner engine for generating and scheduling study sessions
enum PlannerEngine {
    
    /// Generate study sessions for an assignment based on its properties
    static func generateSessions(for assignment: Assignment, settings: StudyPlanSettings) -> [StudySession] {
        let totalMinutes = assignment.estimatedMinutes
        let sessionLength = min(settings.maxSessionLengthMinutes, max(settings.minSessionLengthMinutes, totalMinutes))
        let sessionCount = max(1, (totalMinutes + sessionLength - 1) / sessionLength)
        
        var sessions: [StudySession] = []
        var remainingMinutes = totalMinutes
        
        for i in 0..<sessionCount {
            let sessionMinutes = min(sessionLength, remainingMinutes)
            let session = StudySession(
                assignmentId: assignment.id,
                title: "\(assignment.title) (Session \(i + 1))",
                dueDate: assignment.dueDate,
                estimatedMinutes: sessionMinutes,
                isLockedToDueDate: assignment.isLockedToDueDate,
                category: assignment.category,
                importance: assignment.urgency,
                difficulty: assignment.urgency
            )
            sessions.append(session)
            remainingMinutes -= sessionMinutes
        }
        
        return sessions
    }
    
    /// Schedule sessions into time slots based on settings and energy profile
    static func scheduleSessions(_ sessions: [StudySession], settings: StudyPlanSettings, energyProfile: EnergyProfile) -> ScheduleResult {
        var scheduled: [ScheduledSession] = []
        var overflow: [StudySession] = []
        
        let calendar = Calendar.current
        let now = Date()
        var currentDay = calendar.startOfDay(for: now)
        
        // Sort sessions by due date and importance
        let sortedSessions = sessions.sorted { s1, s2 in
            if s1.dueDate != s2.dueDate {
                return s1.dueDate < s2.dueDate
            }
            return s1.importance.rawValue > s2.importance.rawValue
        }
        
        var dailyMinutesUsed: [Date: Int] = [:]
        
        for session in sortedSessions {
            // Find a suitable day to schedule this session
            var scheduled = false
            for dayOffset in 0..<14 { // Look up to 2 weeks ahead
                guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: currentDay) else { continue }
                
                // Don't schedule past the due date unless locked
                if !session.isLockedToDueDate && candidateDay > session.dueDate {
                    continue
                }
                
                let minutesUsed = dailyMinutesUsed[candidateDay] ?? 0
                if minutesUsed + session.estimatedMinutes <= settings.dailyGoalMinutes {
                    // Schedule this session
                    let startHour = settings.workdayStartHour + (minutesUsed / 60)
                    let startMinute = minutesUsed % 60
                    
                    if let startTime = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: candidateDay),
                       let endTime = calendar.date(byAdding: .minute, value: session.estimatedMinutes, to: startTime) {
                        let scheduledSession = ScheduledSession(
                            session: session,
                            start: startTime,
                            end: endTime
                        )
                        scheduled.append(scheduledSession)
                        dailyMinutesUsed[candidateDay] = minutesUsed + session.estimatedMinutes
                        scheduled = true
                        break
                    }
                }
            }
            
            if !scheduled {
                overflow.append(session)
            }
        }
        
        return ScheduleResult(scheduled: scheduled, overflow: overflow)
    }
}
