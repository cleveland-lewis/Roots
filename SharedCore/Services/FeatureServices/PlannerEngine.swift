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

/// Describes the kind of planner session for proper rendering and behavior
enum PlannerSessionKind: String, Codable, Hashable {
    case study       // Regular study/work session
    case shortBreak  // 5-10 minute break
    case longBreak   // 15-30 minute break
}

struct PlannerSession: Identifiable, Hashable {
    let id: UUID
    let assignmentId: UUID  // For breaks, this is a sentinel UUID
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
    
    /// The kind of session (study vs break)
    let kind: PlannerSessionKind
    
    // MARK: - UI Helpers
    
    /// System icon name for consistent rendering across platforms
    var iconName: String {
        switch kind {
        case .study:
            return "book.fill"
        case .shortBreak:
            return "cup.and.saucer.fill"
        case .longBreak:
            return "moon.fill"
        }
    }
    
    /// Color key for theming (platform-specific colors should map from this)
    var accentColorKey: String {
        switch kind {
        case .study:
            return "primary"
        case .shortBreak:
            return "break"
        case .longBreak:
            return "breakLong"
        }
    }
    
    /// User-facing display title with context
    var displayTitle: String {
        switch kind {
        case .study:
            return title
        case .shortBreak:
            return NSLocalizedString("planner.break.short", value: "Short Break", comment: "Short break session title")
        case .longBreak:
            return NSLocalizedString("planner.break.long", value: "Long Break", comment: "Long break session title")
        }
    }
    
    /// Whether this session is a break (convenience)
    var isBreak: Bool {
        kind == .shortBreak || kind == .longBreak
    }
    
    // MARK: - Initializers
    
    /// Create a study session (standard initialization)
    init(id: UUID = UUID(), 
         assignmentId: UUID, 
         sessionIndex: Int, 
         sessionCount: Int, 
         title: String, 
         dueDate: Date, 
         category: AssignmentCategory, 
         importance: AssignmentUrgency, 
         difficulty: AssignmentUrgency, 
         estimatedMinutes: Int, 
         isLockedToDueDate: Bool, 
         scheduleIndex: Double = 0) {
        self.id = id
        self.assignmentId = assignmentId
        self.sessionIndex = sessionIndex
        self.sessionCount = sessionCount
        self.title = title
        self.dueDate = dueDate
        self.category = category
        self.importance = importance
        self.difficulty = difficulty
        self.estimatedMinutes = estimatedMinutes
        self.isLockedToDueDate = isLockedToDueDate
        self.scheduleIndex = scheduleIndex
        self.kind = .study
    }
    
    /// Create a break session
    static func breakSession(
        id: UUID = UUID(),
        kind: PlannerSessionKind,
        estimatedMinutes: Int,
        dueDate: Date
    ) -> PlannerSession {
        assert(kind == .shortBreak || kind == .longBreak, "Only break kinds allowed")
        
        // Use a sentinel UUID for breaks (not associated with any assignment)
        let breakSentinel = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        
        return PlannerSession(
            id: id,
            assignmentId: breakSentinel,
            sessionIndex: 0,
            sessionCount: 0,
            title: kind == .shortBreak ? "Short Break" : "Long Break",
            dueDate: dueDate,
            category: .review,  // Neutral category for breaks
            importance: .low,
            difficulty: .low,
            estimatedMinutes: estimatedMinutes,
            isLockedToDueDate: false,
            scheduleIndex: 0,
            kind: kind
        )
    }
    
    // MARK: - Private Init for Factory Methods
    
    private init(id: UUID,
                 assignmentId: UUID,
                 sessionIndex: Int,
                 sessionCount: Int,
                 title: String,
                 dueDate: Date,
                 category: AssignmentCategory,
                 importance: AssignmentUrgency,
                 difficulty: AssignmentUrgency,
                 estimatedMinutes: Int,
                 isLockedToDueDate: Bool,
                 scheduleIndex: Double,
                 kind: PlannerSessionKind) {
        self.id = id
        self.assignmentId = assignmentId
        self.sessionIndex = sessionIndex
        self.sessionCount = sessionCount
        self.title = title
        self.dueDate = dueDate
        self.category = category
        self.importance = importance
        self.difficulty = difficulty
        self.estimatedMinutes = estimatedMinutes
        self.isLockedToDueDate = isLockedToDueDate
        self.scheduleIndex = scheduleIndex
        self.kind = kind
    }
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
        @unknown default:
            makeSession(title: assignment.title, index: 1, count: 1, minutes: totalMinutes)
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
            @unknown default: return 0.6
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
                @unknown default:
                    return calendar.date(byAdding: .day, value: -2, to: end) ?? end
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
                let slotsForDay = slots(for: day)
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
    
    // MARK: - AI Scheduler Integration (Phase B)
    
    /// Main entry point for scheduling with AI support
    /// - Parameters:
    ///   - sessions: Sessions to schedule
    ///   - settings: Study plan settings
    ///   - energyProfile: Energy levels by hour
    ///   - useAI: Override for testing; if nil, reads from AppSettingsModel
    /// - Returns: Tuple of scheduled sessions and overflow
    static func scheduleSessionsWithStrategy(
        _ sessions: [PlannerSession],
        settings: StudyPlanSettings,
        energyProfile: [Int: Double],
        useAI: Bool? = nil
    ) -> (scheduled: [ScheduledSession], overflow: [PlannerSession]) {
        let shouldUseAI = useAI ?? AppSettingsModel.shared.enableAIPlanner
        
        var result: (scheduled: [ScheduledSession], overflow: [PlannerSession])
        
        if shouldUseAI {
            // Attempt AI scheduling
            result = scheduleWithAI(sessions, settings: settings, energyProfile: energyProfile)
            
            // Fallback to deterministic if AI returns empty/invalid
            if result.scheduled.isEmpty && !sessions.isEmpty {
                LOG_UI(.warning, "PlannerEngine", "AI scheduling returned empty, falling back to deterministic")
                result = scheduleSessions(sessions, settings: settings, energyProfile: energyProfile)
            }
        } else {
            // Use deterministic scheduling
            result = scheduleSessions(sessions, settings: settings, energyProfile: energyProfile)
        }
        
        // Apply break insertion if enabled (Phase C)
        if AppSettingsModel.shared.autoScheduleBreaks {
            result = insertBreaks(into: result, energyProfile: energyProfile)
        }
        
        return result
    }
    
    /// Schedule sessions using AI scheduler
    private static func scheduleWithAI(
        _ sessions: [PlannerSession],
        settings: StudyPlanSettings,
        energyProfile: [Int: Double]
    ) -> (scheduled: [ScheduledSession], overflow: [PlannerSession]) {
        // Convert PlannerSession to AIScheduler.Task
        let tasks = sessions.map { session -> AppTask in
            AppTask(
                id: session.id,
                title: session.title,
                courseId: nil,
                due: session.dueDate,
                estimatedMinutes: session.estimatedMinutes,
                minBlockMinutes: 15,
                maxBlockMinutes: session.estimatedMinutes,
                difficulty: urgencyToDouble(session.difficulty),
                importance: urgencyToDouble(session.importance),
                type: categoryToTaskType(session.category),
                locked: session.isLockedToDueDate,
                attachments: [],
                isCompleted: false
            )
        }
        
        // Build constraints
        let now = Date()
        let calendar = Calendar.current
        let horizonEnd = calendar.date(byAdding: .day, value: 14, to: now) ?? now
        
        let constraints = Constraints(
            horizonStart: now,
            horizonEnd: horizonEnd,
            dayStartHour: 9,
            dayEndHour: 21,
            maxStudyMinutesPerDay: 480,
            maxStudyMinutesPerBlock: 120,
            minGapBetweenBlocksMinutes: 5,
            doNotScheduleWindows: [],
            energyProfile: energyProfile
        )
        
        // Call AI scheduler
        let aiResult = AIScheduler.generateSchedule(
            tasks: tasks,
            fixedEvents: [],
            constraints: constraints
        )
        
        // Convert back to ScheduledSession
        var scheduled: [ScheduledSession] = []
        var sessionMap = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        
        for block in aiResult.blocks {
            guard let session = sessionMap[block.taskId] else { continue }
            scheduled.append(ScheduledSession(
                id: block.id,
                session: session,
                start: block.start,
                end: block.end
            ))
            sessionMap.removeValue(forKey: block.taskId)
        }
        
        let overflow = Array(sessionMap.values)
        
        return (scheduled, overflow)
    }
    
    // MARK: - Break Insertion (Phase C)
    
    private static let shortBreakMinutes = 10
    private static let longBreakMinutes = 20
    private static let longBreakInterval = 4  // Every 4 study sessions
    
    /// Insert breaks between study sessions
    private static func insertBreaks(
        into result: (scheduled: [ScheduledSession], overflow: [PlannerSession]),
        energyProfile: [Int: Double]
    ) -> (scheduled: [ScheduledSession], overflow: [PlannerSession]) {
        let calendar = Calendar.current
        var scheduledWithBreaks: [ScheduledSession] = []
        let sortedSessions = result.scheduled.sorted { $0.start < $1.start }
        
        var studySessionCount = 0
        
        for (index, session) in sortedSessions.enumerated() {
            // Add the study session
            scheduledWithBreaks.append(session)
            
            // Only count study sessions (not existing breaks)
            if !session.session.isBreak {
                studySessionCount += 1
            }
            
            // Check if we should add a break
            guard index < sortedSessions.count - 1 else { continue }  // Don't add break after last session
            
            let nextSession = sortedSessions[index + 1]
            let gapMinutes = Int(nextSession.start.timeIntervalSince(session.end) / 60)
            
            // Determine break type
            let isLongBreak = (studySessionCount % longBreakInterval == 0)
            let breakMinutes = isLongBreak ? longBreakMinutes : shortBreakMinutes
            
            // Check if we have enough space for the break
            guard gapMinutes >= breakMinutes else { continue }
            
            // Don't add break if next session is on a different day
            let sessionDay = calendar.startOfDay(for: session.end)
            let nextSessionDay = calendar.startOfDay(for: nextSession.start)
            guard sessionDay == nextSessionDay else { continue }
            
            // Don't add break if we're near end of day (after 8 PM)
            let endHour = calendar.component(.hour, from: session.end)
            guard endHour < 20 else { continue }
            
            // Create break session
            let breakKind: PlannerSessionKind = isLongBreak ? .longBreak : .shortBreak
            let breakSession = PlannerSession.breakSession(
                kind: breakKind,
                estimatedMinutes: breakMinutes,
                dueDate: session.end  // Use session end as reference
            )
            
            let breakStart = session.end
            let breakEnd = breakStart.addingTimeInterval(Double(breakMinutes) * 60)
            
            // Only add if it doesn't overlap with next session
            guard breakEnd <= nextSession.start else { continue }
            
            scheduledWithBreaks.append(ScheduledSession(
                id: UUID(),
                session: breakSession,
                start: breakStart,
                end: breakEnd
            ))
        }
        
        return (scheduledWithBreaks, result.overflow)
    }
    
    // MARK: - Helper Converters
    
    private static func urgencyToDouble(_ urgency: AssignmentUrgency) -> Double {
        switch urgency {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.9
        case .critical: return 1.0
        }
    }
    
    private static func categoryToTaskType(_ category: AssignmentCategory) -> TaskType {
        switch category {
        case .exam: return .exam
        case .quiz: return .quiz
        case .practiceHomework: return .practiceHomework
        case .reading: return .reading
        case .review: return .review
        case .project: return .project
        @unknown default: return .practiceHomework
        }
    }
}
