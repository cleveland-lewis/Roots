import Foundation

enum InsightSeverity {
    case info
    case warning
    case critical
}

enum InsightCategory {
    case timeOfDay
    case loadBalance
    case estimation
    case taskType
    case adherence
}

struct Insight: Identifiable {
    let id = UUID()
    let category: InsightCategory
    let severity: InsightSeverity
    let title: String
    let message: String
}
