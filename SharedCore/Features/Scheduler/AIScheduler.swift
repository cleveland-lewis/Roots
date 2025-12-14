import Foundation

// Simple scheduling types and algorithm for Roots

enum EventSource {
    case calendar, `class`, exam, external
}

enum TaskType: String, Hashable, CaseIterable, Codable {
    case project
    case exam
    case quiz
    case practiceHomework
    case reading
    case review

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "homework", "problemSet": self = .practiceHomework
        case "examPrep": self = .exam
        case "meeting": self = .project
        default:
            if let val = TaskType(rawValue: raw) {
                self = val
            } else {
                self = .practiceHomework
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct FixedEvent: Equatable {
    let id: UUID
    let title: String
    let start: Date
    let end: Date
    let isLocked: Bool
    let source: EventSource
}

struct AppTask: Codable, Equatable, Hashable {
    let id: UUID
    let title: String
    let courseId: UUID?
    let due: Date?
    let estimatedMinutes: Int
    let minBlockMinutes: Int
    let maxBlockMinutes: Int
    let difficulty: Double     // 0…1
    let importance: Double     // 0…1
    let type: TaskType
    let category: TaskType     // First-class category field (aliased to type for now)
    let locked: Bool
    let attachments: [Attachment]
    var isCompleted: Bool
    var gradeWeightPercent: Double?
    var gradePossiblePoints: Double?
    var gradeEarnedPoints: Double?

    init(id: UUID, title: String, courseId: UUID?, due: Date?, estimatedMinutes: Int, minBlockMinutes: Int, maxBlockMinutes: Int, difficulty: Double, importance: Double, type: TaskType, locked: Bool, attachments: [Attachment] = [], isCompleted: Bool = false, gradeWeightPercent: Double? = nil, gradePossiblePoints: Double? = nil, gradeEarnedPoints: Double? = nil, category: TaskType? = nil) {
        self.id = id
        self.title = title
        self.courseId = courseId
        self.due = due
        self.estimatedMinutes = estimatedMinutes
        self.minBlockMinutes = minBlockMinutes
        self.maxBlockMinutes = maxBlockMinutes
        self.difficulty = difficulty
        self.importance = importance
        self.type = type
        self.category = category ?? type  // Use provided category or default to type
        self.locked = locked
        self.attachments = attachments
        self.isCompleted = isCompleted
        self.gradeWeightPercent = gradeWeightPercent
        self.gradePossiblePoints = gradePossiblePoints
        self.gradeEarnedPoints = gradeEarnedPoints
    }
}

struct Constraints {
    let horizonStart: Date
    let horizonEnd: Date
    let dayStartHour: Int
    let dayEndHour: Int
    let maxStudyMinutesPerDay: Int
    let maxStudyMinutesPerBlock: Int
    let minGapBetweenBlocksMinutes: Int
    let doNotScheduleWindows: [ClosedRange<Date>]
    let energyProfile: [Int: Double] // hourOfDay → 0…1
}

struct ScheduledBlock: Equatable {
    let id: UUID
    let taskId: UUID
    let start: Date
    let end: Date
}

struct ScheduleResult {
    let blocks: [ScheduledBlock]
    let unscheduledTasks: [AppTask]
    var log: [String]
}

// Helpers
private struct FreeInterval: Equatable {
    var start: Date
    var end: Date
    var durationMinutes: Int { Int(end.timeIntervalSince(start) / 60.0) }
}

private struct CandidateBlock: Equatable {
    var start: Date
    var end: Date
    var energyScore: Double
    var dayStart: Date
    var durationMinutes: Int { Int(end.timeIntervalSince(start) / 60.0) }
}


struct AIScheduler {
    private static let calendar = Calendar.current
    // Expose Task alias for tests that reference AIScheduler.Task
    typealias Task = AppTask

    // Public entry
    static func generateSchedule(
        tasks inputTasks: [Task],
        fixedEvents: [FixedEvent],
        constraints: Constraints,
        preferences: SchedulerPreferences = SchedulerPreferences.default()
    ) -> ScheduleResult {
        LOG_SCHEDULER(.info, "ScheduleGeneration", "Starting schedule generation", metadata: ["tasks": "\(inputTasks.count)", "fixedEvents": "\(fixedEvents.count)"])
        var log: [String] = []

        // 1. Build free intervals per day
        let dayIntervals = buildFreeIntervalsPerDay(fixedEvents: fixedEvents, constraints: constraints)
        LOG_SCHEDULER(.debug, "ScheduleGeneration", "Built free intervals", metadata: ["days": "\(dayIntervals.count)"])

        // 2. Compute task priorities
        var tasks = inputTasks // include locked tasks; they can be forced to due date
        let horizonDays = daysBetween(start: constraints.horizonStart, end: constraints.horizonEnd)
        var priorityMap: [UUID: Double] = [:]
        for task in tasks {
            priorityMap[task.id] = computePriority(for: task, horizonDays: max(1, horizonDays), preferences: preferences)
        }

        // 3. Generate candidate blocks
        var candidates = generateCandidates(from: dayIntervals, constraints: constraints)

        // 4. Assign tasks greedily
        // Sort tasks by priority desc, due asc
        tasks.sort { (a, b) -> Bool in
            let pa = priorityMap[a.id] ?? 0
            let pb = priorityMap[b.id] ?? 0
            if pa == pb {
                return (a.due ?? Date.distantFuture) < (b.due ?? Date.distantFuture)
            }
            return pa > pb
        }

        var scheduledBlocks: [ScheduledBlock] = []
        var unscheduled: [Task] = []

        // Track per-day scheduled minutes
        var minutesScheduledForDay: [Date: Int] = [:] // key = startOfDay

        // candidate availability is represented by the candidates array; when partially used, we update it

        for task in tasks {
            var remaining = task.estimatedMinutes
            let taskPriority = priorityMap[task.id] ?? 0
            let dueDate = task.due

            // Filter candidates for this task each iteration (dynamic)
            var attempts = 0
            while remaining > 0 {
                attempts += 1
                // Avoid infinite loop
                if attempts > 5000 { break }

                // Build feasible candidate list
                let feasibleIndices = candidates.indices.filter { idx in
                    let c = candidates[idx]
                    // candidate must be at least minBlock
                    if c.durationMinutes < task.minBlockMinutes { return false }
                    // candidate must not exceed per-block max for scheduler and task
                    if c.durationMinutes <= 0 { return false }
                    if c.durationMinutes < task.minBlockMinutes { return false }
                    if c.durationMinutes > constraints.maxStudyMinutesPerBlock && constraints.maxStudyMinutesPerBlock > 0 { return false }
                    // due date constraint
                    if let due = dueDate, c.end > due { return false }
                    // per-day cap
                    let dayKey = startOfDay(c.start)
                    let already = minutesScheduledForDay[dayKey] ?? 0
                    if already >= constraints.maxStudyMinutesPerDay { return false }
                    return true
                }

                if feasibleIndices.isEmpty { break }

                // Score candidates
                var bestIdx: Int? = nil
                var bestScore: Double = -Double.infinity
                for idx in feasibleIndices {
                    let c = candidates[idx]
                    let energy = c.energyScore
                    // lateness penalty: if due exists, penalize distance to due (closer to due -> higher penalty), prefer earlier -> negative penalty
                    var latenessPenalty = 0.0
                    if let due = dueDate {
                        let secondsUntilDue = due.timeIntervalSince(c.start)
                        // if candidate is after due, already filtered
                        let daysUntilDue = max(0.0, secondsUntilDue / 86400.0)
                        // closer to due -> higher penalty. Normalize by horizon days
                        latenessPenalty = (1.0 / (1.0 + daysUntilDue)) // in (0,1]
                    }

                    // Composite score
                    // deterministic weights
                    let alpha = 1.0 // task priority weight
                    let beta = 0.5  // energy weight
                    let gamma = 0.5 // lateness penalty weight (lower is better)

                    let score = alpha * taskPriority + beta * energy - gamma * latenessPenalty

                    if score > bestScore {
                        bestScore = score
                        bestIdx = idx
                    }
                }

                guard let chosenIdx = bestIdx else { break }
                let chosen = candidates[chosenIdx]

                // Determine duration to schedule in this candidate
                let chosenDuration = min(task.maxBlockMinutes, chosen.durationMinutes, remaining)
                // Respect scheduler global per-block cap
                let finalDuration = min(chosenDuration, constraints.maxStudyMinutesPerBlock > 0 ? constraints.maxStudyMinutesPerBlock : chosenDuration)

                // Create scheduled block
                let blockStart = chosen.start
                let blockEnd = calendar.date(byAdding: .minute, value: finalDuration, to: blockStart)!
                let sb = ScheduledBlock(id: UUID(), taskId: task.id, start: blockStart, end: blockEnd)
                scheduledBlocks.append(sb)

                // Update remaining and candidate
                remaining -= finalDuration

                // Update per-day counters
                let dayKey = startOfDay(blockStart)
                minutesScheduledForDay[dayKey] = (minutesScheduledForDay[dayKey] ?? 0) + finalDuration

                // Update chosen candidate: remove the used portion from its start
                if blockEnd >= chosen.end {
                    // used entire candidate
                    candidates.remove(at: chosenIdx)
                } else {
                    // shrink candidate start forward
                    candidates[chosenIdx].start = blockEnd
                }

                // If candidate leftover is shorter than minBlock, discard it
                if chosenIdx < candidates.count {
                    if candidates[chosenIdx].durationMinutes < task.minBlockMinutes {
                        candidates.remove(at: chosenIdx)
                    }
                }

                // also enforce min gap between blocks by trimming nearby candidates (optional)
                if constraints.minGapBetweenBlocksMinutes > 0 {
                    let gap = constraints.minGapBetweenBlocksMinutes
                    // remove or trim candidates that start within gap of blockEnd
                    candidates = candidates.flatMap { c -> [CandidateBlock] in
                        if c.start < blockEnd.addingTimeInterval(TimeInterval(gap * 60)) && c.end > blockEnd {
                            // trim start
                            var trimmed = c
                            trimmed.start = blockEnd.addingTimeInterval(TimeInterval(gap * 60))
                            if trimmed.durationMinutes >= task.minBlockMinutes {
                                return [trimmed]
                            } else {
                                return []
                            }
                        }
                        return [c]
                    }
                }
            }

            if remaining > 0 {
                unscheduled.append(task)
                log.append("Task \(task.title): scheduled \(task.estimatedMinutes - remaining)/\(task.estimatedMinutes) minutes; could not fully schedule within horizon.")
            } else {
                log.append("Task \(task.title): fully scheduled.")
            }
        }

        // 5. Local improvement pass: merge adjacent blocks for same task on the same day
        scheduledBlocks.sort { $0.start < $1.start }
        scheduledBlocks = mergeAdjacentBlocks(blocks: scheduledBlocks, maxBlockMinutes: constraints.maxStudyMinutesPerBlock, minGap: constraints.minGapBetweenBlocksMinutes)

        LOG_SCHEDULER(.info, "ScheduleGeneration", "Schedule generation complete", metadata: ["scheduled": "\(scheduledBlocks.count)", "unscheduled": "\(unscheduled.count)"])
        if !unscheduled.isEmpty {
            LOG_SCHEDULER(.warn, "ScheduleGeneration", "Some tasks could not be scheduled", metadata: ["count": "\(unscheduled.count)"])
        }
        return ScheduleResult(blocks: scheduledBlocks, unscheduledTasks: unscheduled, log: log)
    }

    // MARK: - Free interval generation
    private static func buildFreeIntervalsPerDay(fixedEvents: [FixedEvent], constraints: Constraints) -> [Date: [FreeInterval]] {
        var result: [Date: [FreeInterval]] = [:]
        let start = startOfDay(constraints.horizonStart)
        let end = startOfDay(constraints.horizonEnd)

        var current = start
        while current <= end {
            let dayStart = calendar.date(bySettingHour: constraints.dayStartHour, minute: 0, second: 0, of: current)!
            let dayEnd = calendar.date(bySettingHour: constraints.dayEndHour, minute: 0, second: 0, of: current)!

            var free: [FreeInterval] = [FreeInterval(start: dayStart, end: dayEnd)]

            // gather blockers for this day: fixed events and doNotScheduleWindows that intersect
            let blockers: [ClosedRange<Date>] = {
                var b: [ClosedRange<Date>] = []
                for fe in fixedEvents {
                    // consider events that overlap this day window
                    if fe.end <= dayStart || fe.start >= dayEnd { continue }
                    // treat any locked events as blockers; unlocked fixed events could be considered flexible but here we block
                    if fe.isLocked {
                        let rStart = max(fe.start, dayStart)
                        let rEnd = min(fe.end, dayEnd)
                        b.append(rStart...rEnd)
                    }
                }
                for w in constraints.doNotScheduleWindows {
                    if w.upperBound <= dayStart || w.lowerBound >= dayEnd { continue }
                    let rStart = max(w.lowerBound, dayStart)
                    let rEnd = min(w.upperBound, dayEnd)
                    b.append(rStart...rEnd)
                }
                // sort blockers by start
                b.sort { $0.lowerBound < $1.lowerBound }
                return b
            }()

            // subtract blockers from free intervals
            for blocker in blockers {
                free = subtractIntervalList(free, blockerLower: blocker.lowerBound, blockerUpper: blocker.upperBound)
            }

            // discard fragments smaller than smallest feasible block (use 20 minutes as safe minimum or min from constraints if present)
            let minFeasible = 20
            free = free.filter { $0.durationMinutes >= minFeasible }

            result[startOfDay(current)] = free

            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return result
    }

    private static func subtractIntervalList(_ free: [FreeInterval], blockerLower: Date, blockerUpper: Date) -> [FreeInterval] {
        var out: [FreeInterval] = []
        for interval in free {
            // no overlap
            if blockerUpper <= interval.start || blockerLower >= interval.end {
                out.append(interval)
                continue
            }

            // overlap exists
            if blockerLower <= interval.start && blockerUpper >= interval.end {
                // blocker covers whole interval -> remove
                continue
            }

            if blockerLower <= interval.start {
                // trim left side
                let newStart = blockerUpper
                if newStart < interval.end {
                    out.append(FreeInterval(start: newStart, end: interval.end))
                }
            } else if blockerUpper >= interval.end {
                // trim right side
                let newEnd = blockerLower
                if newEnd > interval.start {
                    out.append(FreeInterval(start: interval.start, end: newEnd))
                }
            } else {
                // blocker in middle -> split
                out.append(FreeInterval(start: interval.start, end: blockerLower))
                out.append(FreeInterval(start: blockerUpper, end: interval.end))
            }
        }
        // sort by start
        out.sort { $0.start < $1.start }
        return out
    }

    // MARK: - Priority
    private static func computePriority(for task: Task, horizonDays: Int, preferences: SchedulerPreferences) -> Double {
        // urgency
        let now = Date()
        var urgency: Double = 0
        if let due = task.due {
            let timeToDue = max(0.0, due.timeIntervalSince(now))
            let days = timeToDue / 86400.0
            urgency = 1.0 - clamp(days / Double(horizonDays), 0, 1)
        }

        let importance = clamp(task.importance, 0, 1)
        let difficulty = clamp(task.difficulty, 0, 1)
        // size factor relative to 180 minutes reference
        let sizeFactor = clamp(Double(task.estimatedMinutes) / 180.0, 0, 1)

        let wUrgency = preferences.wUrgency
        let wImportance = preferences.wImportance
        let wDifficulty = preferences.wDifficulty
        let wSize = preferences.wSize

        // course bias
        var bias = 0.0
        if let cid = task.courseId {
            bias = preferences.courseBias[cid] ?? 0.0
        }

        let score = wUrgency * urgency + wImportance * importance + wDifficulty * difficulty + wSize * sizeFactor + bias
        return score
    }

    // MARK: - Candidate generation
    private static func generateCandidates(from dayIntervals: [Date: [FreeInterval]], constraints: Constraints) -> [CandidateBlock] {
        var candidates: [CandidateBlock] = []
        let sortedDays = dayIntervals.keys.sorted()

        for day in sortedDays {
            guard let intervals = dayIntervals[day] else { continue }
            for interval in intervals {
                var remaining = interval.durationMinutes
                var cursor = interval.start

                // If the interval is short but >= minBlock, create one candidate
                if remaining <= constraints.maxStudyMinutesPerBlock || constraints.maxStudyMinutesPerBlock <= 0 {
                    if remaining >= 20 {
                        let energy = energyForDate(cursor, profile: constraints.energyProfile)
                        candidates.append(CandidateBlock(start: cursor, end: interval.end, energyScore: energy, dayStart: day))
                    }
                    continue
                }

                // Otherwise, break into chunks of up to maxStudyMinutesPerBlock deterministically
                let chunk = max(20, min(constraints.maxStudyMinutesPerBlock > 0 ? constraints.maxStudyMinutesPerBlock : remaining, remaining))
                while remaining >= 20 {
                    let dur = min(chunk, remaining)
                    let end = calendar.date(byAdding: .minute, value: dur, to: cursor)!
                    let energy = energyForDate(cursor, profile: constraints.energyProfile)
                    candidates.append(CandidateBlock(start: cursor, end: end, energyScore: energy, dayStart: day))
                    remaining -= dur
                    cursor = end
                }
            }
        }

        return candidates
    }

    // MARK: - Merge adjacent
    private static func mergeAdjacentBlocks(blocks: [ScheduledBlock], maxBlockMinutes: Int, minGap: Int) -> [ScheduledBlock] {
        guard !blocks.isEmpty else { return [] }
        var out: [ScheduledBlock] = []
        var current = blocks[0]
        for i in 1..<blocks.count {
            let next = blocks[i]
            if next.taskId == current.taskId {
                let gap = Int(next.start.timeIntervalSince(current.end) / 60.0)
                let combinedMinutes = Int(next.end.timeIntervalSince(current.start) / 60.0)
                if gap <= minGap && (maxBlockMinutes <= 0 || combinedMinutes <= maxBlockMinutes) {
                    // merge
                    current = ScheduledBlock(id: current.id, taskId: current.taskId, start: current.start, end: next.end)
                    continue
                }
            }
            out.append(current)
            current = next
        }
        out.append(current)
        return out
    }

    // MARK: - Utilities
    private static func energyForDate(_ date: Date, profile: [Int: Double]) -> Double {
        let hour = calendar.component(.hour, from: date)
        return profile[hour] ?? 0.5
    }

    private static func startOfDay(_ d: Date) -> Date {
        return calendar.startOfDay(for: d)
    }

    private static func daysBetween(start: Date, end: Date) -> Int {
        let s = calendar.startOfDay(for: start)
        let e = calendar.startOfDay(for: end)
        let comps = calendar.dateComponents([.day], from: s, to: e)
        return max(1, comps.day ?? 1)
    }

    private static func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T {
        return min(max(v, lo), hi)
    }
}
