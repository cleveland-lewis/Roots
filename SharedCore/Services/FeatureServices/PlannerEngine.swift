import Foundation

// MARK: - Study Plan Settings

struct StudyPlanSettings {
    var examDefaultTotalMinutes: Int = 240
    var examDefaultSessionMinutes: Int = 60
    var examStartDaysBeforeDue: Int = 5

    var quizDefaultTotalMinutes: Int = 90
    var quizDefaultSessionMinutes: Int = 60
    var quizStartDaysBeforeDue: Int = 3

    var homeworkSingleSessionThreshold: Int = 60
    var readingSingleSessionThreshold: Int = 60
    var longHomeworkSplitSessionMinutes: Int = 45
    var longReadingSplitSessionMinutes: Int = 30

    var projectSessionMinutes: Int = 75
    var projectMinSessions: Int = 3
}

// MARK: - Planner Session Model

struct PlannerSession: Identifiable, Hashable {
    let id: UUID
    let assignmentId: UUID
    let sessionIndex: Int
    let sessionCount: Int
    let title: String
    let dueDate: Date
    let category: AssignmentCategory
    let importance: AssignmentUrgency
    let difficulty: AssignmentUrgency
    let estimatedMinutes: Int
    let isLockedToDueDate: Bool
    var scheduleIndex: Double = 0
}

struct ScheduledSession: Identifiable, Hashable {
    let id: UUID
    let session: PlannerSession
    let start: Date
    let end: Date
}

// MARK: - Planner Engine

enum PlannerEngine {
    static func generateSessions(for assignment: Assignment, settings: StudyPlanSettings) -> [PlannerSession] {
        var sessions: [PlannerSession] = []
        let totalMinutes = max(15, assignment.estimatedMinutes)
        let dueDate = assignment.dueDate
        let baseId = assignment.id

        func makeSession(title: String, index: Int, count: Int, minutes: Int) {
            let s = PlannerSession(
                id: UUID(),
                assignmentId: baseId,
                sessionIndex: index,
                sessionCount: count,
                title: title,
                dueDate: dueDate,
                category: assignment.category,
                importance: assignment.urgency,
                difficulty: assignment.urgency, // reuse urgency as difficulty proxy
                estimatedMinutes: minutes,
                isLockedToDueDate: assignment.isLockedToDueDate,
                scheduleIndex: 0
            )
            sessions.append(s)
        }

        switch assignment.category {
        case .exam:
            let perSession = settings.examDefaultSessionMinutes
            let rawCount = Int(ceil(Double(totalMinutes) / Double(perSession)))
            let sessionCount = max(3, min(4, rawCount))
            for i in 1...sessionCount {
                let mins = (i < sessionCount) ? perSession : max(15, totalMinutes - perSession * (sessionCount - 1))
                makeSession(title: "\(assignment.title) – Study Session \(i)/\(sessionCount)", index: i, count: sessionCount, minutes: mins)
            }
        case .quiz:
            let perSession = settings.quizDefaultSessionMinutes
            let rawCount = Int(ceil(Double(totalMinutes) / Double(perSession)))
            let sessionCount = max(1, min(2, rawCount))
            for i in 1...sessionCount {
                let mins = (i < sessionCount) ? perSession : max(15, totalMinutes - perSession * (sessionCount - 1))
                makeSession(title: "\(assignment.title) – Study Session \(i)/\(sessionCount)", index: i, count: sessionCount, minutes: mins)
            }
        case .practiceHomework:
            if totalMinutes <= settings.homeworkSingleSessionThreshold {
                makeSession(title: assignment.title, index: 1, count: 1, minutes: totalMinutes)
            } else {
                let perSession = settings.longHomeworkSplitSessionMinutes
                let sessionCount = Int(ceil(Double(totalMinutes) / Double(perSession)))
                for i in 1...sessionCount {
                    let mins = (i < sessionCount) ? perSession : max(15, totalMinutes - perSession * (sessionCount - 1))
                    makeSession(title: "\(assignment.title) – Part \(i)/\(sessionCount)", index: i, count: sessionCount, minutes: mins)
                }
            }
        case .reading:
            if totalMinutes <= settings.readingSingleSessionThreshold {
                makeSession(title: assignment.title, index: 1, count: 1, minutes: totalMinutes)
            } else {
                let perSession = settings.longReadingSplitSessionMinutes
                let sessionCount = Int(ceil(Double(totalMinutes) / Double(perSession)))
                for i in 1...sessionCount {
                    let mins = (i < sessionCount) ? perSession : max(15, totalMinutes - perSession * (sessionCount - 1))
                    makeSession(title: "\(assignment.title) – Part \(i)/\(sessionCount)", index: i, count: sessionCount, minutes: mins)
                }
            }
        case .review:
            let perSession = settings.longReadingSplitSessionMinutes
            let sessionCount = max(1, Int(ceil(Double(totalMinutes) / Double(perSession))))
            for i in 1...sessionCount {
                let mins = (i < sessionCount) ? perSession : max(15, totalMinutes - perSession * (sessionCount - 1))
                makeSession(title: "\(assignment.title) – Review \(i)/\(sessionCount)", index: i, count: sessionCount, minutes: mins)
            }
        case .project:
            if !assignment.plan.isEmpty {
                let totalCount = assignment.plan.count
                for (i, step) in assignment.plan.enumerated() {
                    let idx = i + 1
                    makeSession(title: "\(assignment.title) – \(step.title)", index: idx, count: totalCount, minutes: max(15, step.expectedMinutes))
                }
            } else {
                let sessionCount = max(settings.projectMinSessions, Int(ceil(Double(totalMinutes) / Double(settings.projectSessionMinutes))))
                let perSession = Int(ceil(Double(totalMinutes) / Double(sessionCount)))
                for i in 1...sessionCount {
                    let mins = (i < sessionCount) ? perSession : max(15, totalMinutes - perSession * (sessionCount - 1))
                    makeSession(title: "\(assignment.title) – Work Session \(i)/\(sessionCount)", index: i, count: sessionCount, minutes: mins)
                }
            }
        }

        return sessions
    }

    static func computeScheduleIndex(for session: PlannerSession, today: Date = Date()) -> Double {
        // priority factor from urgency
        let priorityFactor: Double = {
            switch session.importance {
            case .low: return 0.4
            case .medium: return 0.7
            case .high: return 1.0
            case .critical: return 1.0
            }
        }()
        let horizonDays: Double = 14
        let daysUntil = max(0, Calendar.current.dateComponents([.day], from: today, to: session.dueDate).day ?? 0)
        let dueRaw = 1 - (Double(daysUntil) / horizonDays)
        let dueFactor = min(max(dueRaw, 0), 1)
        let categoryFactor: Double = {
            switch session.category {
            case .exam: return 1.0
            case .project: return 0.9
            case .quiz: return 0.8
            case .practiceHomework: return 0.7
            case .reading: return 0.6
            case .review: return 0.65
            }
        }()
        var base = 0.5 * priorityFactor + 0.4 * dueFactor + 0.1 * categoryFactor
        if session.category == .exam || session.category == .quiz {
            base = min(1.0, base + 0.05)
        }
        return min(max(base, 0), 1)
    }

    static func scheduleSessions(_ sessions: [PlannerSession], settings: StudyPlanSettings, energyProfile: [Int: Double]) -> (scheduled: [ScheduledSession], overflow: [PlannerSession]) {
        var scheduled: [ScheduledSession] = []
        var overflow: [PlannerSession] = []

        // sort by schedule index
        let today = Date()
        let scored = sessions.map { session -> PlannerSession in
            var s = session
            s.scheduleIndex = computeScheduleIndex(for: session, today: today)
            return s
        }.sorted { lhs, rhs in
            if lhs.scheduleIndex == rhs.scheduleIndex {
                if lhs.dueDate == rhs.dueDate {
                    return lhs.assignmentId.uuidString < rhs.assignmentId.uuidString
                }
                return lhs.dueDate < rhs.dueDate
            }
            return lhs.scheduleIndex > rhs.scheduleIndex
        }

        // build per-day slot maps
        var daySlots: [Date: [Bool]] = [:] // false = free, true = occupied
        let calendar = Calendar.current

        func slots(for day: Date) -> [Bool] {
            if let existing = daySlots[day] { return existing }
            let arr = Array(repeating: false, count: 24) // 09:00-21:00 -> 24 slots of 30m
            daySlots[day] = arr
            return arr
        }

        func dateRange(start: Date, end: Date) -> [Date] {
            var dates: [Date] = []
            var current = calendar.startOfDay(for: start)
            let endDay = calendar.startOfDay(for: end)
            while current <= endDay {
                dates.append(current)
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
            return dates
        }

        func computeWindow(for session: PlannerSession) -> (Date, Date) {
            let end = session.dueDate
            let start: Date = {
                switch session.category {
                case .exam:
                    return calendar.date(byAdding: .day, value: -settings.examStartDaysBeforeDue, to: end) ?? end
                case .quiz:
                    return calendar.date(byAdding: .day, value: -settings.quizStartDaysBeforeDue, to: end) ?? end
                case .practiceHomework:
                    let delta = session.importance == .high ? -3 : (session.importance == .medium ? -2 : -1)
                    return calendar.date(byAdding: .day, value: delta, to: end) ?? end
                case .reading:
                    let delta = session.importance == .high ? -3 : -2
                    return calendar.date(byAdding: .day, value: delta, to: end) ?? end
                case .review:
                    let delta = session.importance == .high ? -3 : -2
                    return calendar.date(byAdding: .day, value: delta, to: end) ?? end
                case .project:
                    return calendar.date(byAdding: .day, value: -7, to: end) ?? end
                }
            }()
            let minStart = max(calendar.startOfDay(for: today), calendar.startOfDay(for: start))
            return (minStart, end)
        }

        for session in scored {
            let slotsNeeded = max(1, Int(ceil(Double(session.estimatedMinutes) / 30.0)))
            let window = computeWindow(for: session)
            if window.1 < window.0 {
                assertionFailure("Invalid scheduling window for session \(session.id)")
                overflow.append(session)
                continue
            }
            let days = dateRange(start: window.0, end: window.1)

            var bestPlacement: (day: Date, slot: Int, score: Double)?

            for day in days {
                var slotsForDay = slots(for: day)
                let lastStart = max(0, slotsForDay.count - slotsNeeded)
                for startIdx in 0...lastStart {
                    let endIdx = startIdx + slotsNeeded
                    let slice = slotsForDay[startIdx..<endIdx]
                    if slice.contains(true) { continue }

                    let slotHour = 9 + startIdx / 2
                    let slotEnergy = energyProfile[slotHour] ?? 0.5
                    let difficultyReq: Double = {
                        switch session.difficulty {
                        case .low: return 0.0
                        case .medium: return 0.5
                        case .high, .critical: return 1.0
                        }
                    }()
                    let energyMatch = 1 - abs(difficultyReq - slotEnergy)
                    let placementScore = 0.8 * session.scheduleIndex + 0.2 * energyMatch
                    if let current = bestPlacement {
                        if placementScore > current.score {
                            bestPlacement = (day, startIdx, placementScore)
                        }
                    } else {
                        bestPlacement = (day, startIdx, placementScore)
                    }
                }
            }

            guard let placement = bestPlacement else {
                overflow.append(session)
                continue
            }

            var daySlotsArr = slots(for: placement.day)
            for idx in placement.slot..<(placement.slot + slotsNeeded) {
                daySlotsArr[idx] = true
            }
            daySlots[placement.day] = daySlotsArr

            let startComponents = DateComponents(hour: 9, minute: 0)
            let dayStart = calendar.date(bySettingHour: startComponents.hour!, minute: startComponents.minute!, second: 0, of: placement.day) ?? placement.day
            let startDate = dayStart.addingTimeInterval(Double(placement.slot) * 30 * 60)
            let endDate = startDate.addingTimeInterval(Double(session.estimatedMinutes) * 60)

            let scheduledSession = ScheduledSession(id: session.id, session: session, start: startDate, end: endDate)
            scheduled.append(scheduledSession)
        }

        return (scheduled, overflow)
    }
}
