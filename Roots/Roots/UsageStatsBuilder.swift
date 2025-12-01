import Foundation

protocol HistoryStore {
    var scheduledBlocks: [ScheduledBlock] { get }
    var feedback: [BlockFeedback] { get }
}

enum StatsWindow {
    case days(Int)
}

enum UsageStatsBuilder {
    static func build(
        from history: HistoryStore,
        window: StatsWindow,
        now: Date = .init()
    ) -> UsageStats {
        let days: Int
        switch window {
        case .days(let d): days = d
        }

        let calendar = Calendar.current
        let endDate = now
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return UsageStats(
                startDate: now,
                endDate: now,
                totalScheduledMinutes: 0,
                totalCompletedMinutes: 0,
                totalSkippedMinutes: 0,
                hourly: [],
                byTaskType: [],
                byDay: []
            )
        }

        // Filter blocks in window
        let windowBlocks = history.scheduledBlocks.filter { block in
            block.start >= startDate && block.start <= endDate
        }

        // Build quick maps
        let feedbackByBlockId = Dictionary(
            grouping: history.feedback,
            by: { $0.blockId }
        )

        func minutes(_ start: Date, _ end: Date) -> Int {
            max(0, Int(end.timeIntervalSince(start) / 60.0))
        }

        var totalScheduled = 0
        var totalCompleted = 0
        var totalSkipped = 0

        var hourlyMap: [Int: (scheduled: Int, completed: Int)] = [:]
        var dayMap: [Date: (scheduled: Int, completed: Int)] = [:]
        var typeMap: [TaskType: (scheduled: Int, completed: Int, plannedBlocks: [Int], actualBlocks: [Int])] = [:]

        for block in windowBlocks {
            let duration = minutes(block.start, block.end)
            totalScheduled += duration

            let hour = calendar.component(.hour, from: block.start)
            let day = calendar.startOfDay(for: block.start)

            let fb = feedbackByBlockId[block.id]?.last
            let completionFraction = fb?.completion ?? 0.0
            let completedMinutes = Int(Double(duration) * completionFraction)
            let skippedMinutes = duration - completedMinutes

            totalCompleted += completedMinutes
            totalSkipped += max(0, skippedMinutes)

            // Hourly
            var hourlyEntry = hourlyMap[hour] ?? (0, 0)
            hourlyEntry.scheduled += duration
            hourlyEntry.completed += completedMinutes
            hourlyMap[hour] = hourlyEntry

            // Daily
            var dayEntry = dayMap[day] ?? (0, 0)
            dayEntry.scheduled += duration
            dayEntry.completed += completedMinutes
            dayMap[day] = dayEntry

            // TaskType stats – try to get type from feedback, else from task store
            var taskType: TaskType = .other
            if let fbType = fb?.type {
                taskType = fbType
            } else if let task = AssignmentsStore.shared.tasks.first(where: { $0.id == block.taskId }) {
                taskType = task.type
            }

            var typeEntry = typeMap[taskType] ?? (0, 0, [], [])
            typeEntry.scheduled += duration
            typeEntry.completed += completedMinutes
            typeEntry.plannedBlocks.append(duration)
            typeEntry.actualBlocks.append(completedMinutes)
            typeMap[taskType] = typeEntry
        }

        let hourlyStats: [UsageStats.HourlyPerformance] = hourlyMap
            .sorted(by: { $0.key < $1.key })
            .map { hour, entry in
                UsageStats.HourlyPerformance(
                    hour: hour,
                    scheduledMinutes: entry.scheduled,
                    completedMinutes: entry.completed
                )
            }

        let dayStats: [UsageStats.DayStats] = dayMap
            .sorted(by: { $0.key < $1.key })
            .map { day, entry in
                UsageStats.DayStats(
                    date: day,
                    scheduledMinutes: entry.scheduled,
                    completedMinutes: entry.completed
                )
            }

        let typeStats: [UsageStats.TaskTypeStats] = typeMap.map { (type, entry) in
            let avgPlanned = entry.plannedBlocks.isEmpty ? 0.0 :
                Double(entry.plannedBlocks.reduce(0,+)) / Double(entry.plannedBlocks.count)
            let avgActual = entry.actualBlocks.isEmpty ? 0.0 :
                Double(entry.actualBlocks.reduce(0,+)) / Double(entry.actualBlocks.count)

            return UsageStats.TaskTypeStats(
                type: type,
                scheduledMinutes: entry.scheduled,
                completedMinutes: entry.completed,
                avgPlannedBlockMinutes: avgPlanned,
                avgActualBlockMinutes: avgActual
            )
        }

        return UsageStats(
            startDate: startDate,
            endDate: endDate,
            totalScheduledMinutes: totalScheduled,
            totalCompletedMinutes: totalCompleted,
            totalSkippedMinutes: totalSkipped,
            hourly: hourlyStats,
            byTaskType: typeStats,
            byDay: dayStats
        )
    }
}
