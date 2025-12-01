import Foundation

struct UsageStats {
    let startDate: Date
    let endDate: Date

    let totalScheduledMinutes: Int
    let totalCompletedMinutes: Int
    let totalSkippedMinutes: Int

    struct HourlyPerformance {
        let hour: Int            // 0–23
        let scheduledMinutes: Int
        let completedMinutes: Int
    }
    let hourly: [HourlyPerformance]   // length 0–24

    struct TaskTypeStats {
        let type: TaskType
        let scheduledMinutes: Int
        let completedMinutes: Int
        let avgPlannedBlockMinutes: Double
        let avgActualBlockMinutes: Double
    }
    let byTaskType: [TaskTypeStats]

    struct DayStats {
        let date: Date
        let scheduledMinutes: Int
        let completedMinutes: Int
    }
    let byDay: [DayStats]
}
