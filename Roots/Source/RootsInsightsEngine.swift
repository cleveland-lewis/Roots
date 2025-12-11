import Foundation
import Combine

/// Lightweight snapshot of an assignment at the time an event was emitted.
struct AssignmentSnapshot: Identifiable, Hashable {
    let id: UUID
    let courseId: UUID?
    let title: String
    let dueDate: Date
    let estimatedMinutes: Int?
    let weightPercent: Double?
    let category: AssignmentCategory?
}

/// Snapshot of a completed study or focus session (usually from Timer/Omodoro).
struct StudySessionSnapshot: Identifiable, Hashable {
    let id: UUID
    let activityId: UUID
    let courseId: UUID?
    let assignmentId: UUID?
    let mode: String
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }
}

/// Snapshot of a grade event (course- or assignment-level).
struct GradeSnapshot: Identifiable, Hashable {
    let id: UUID
    let courseId: UUID
    let assignmentId: UUID?
    let percentage: Double
    let recordedAt: Date
}

/// Snapshot of resource usage (e.g., opening a PDF or note).
struct ResourceUsageSnapshot: Identifiable, Hashable {
    let id: UUID
    let courseId: UUID?
    let assignmentId: UUID?
    let startedAt: Date
    let endedAt: Date?
}

/// Unified event stream the insights engine consumes.
enum InsightsEvent {
    case assignmentCreated(AssignmentSnapshot)
    case assignmentUpdated(AssignmentSnapshot)
    case assignmentCompleted(AssignmentSnapshot, completedAt: Date)

    case studySessionCompleted(StudySessionSnapshot)
    case gradeRecorded(GradeSnapshot)
    case resourceUsage(ResourceUsageSnapshot)
}

/// Minimal view of an assignment's historical metrics.
struct AssignmentMetrics: Hashable {
    var snapshot: AssignmentSnapshot
    var actualTime: TimeInterval = 0
    var predictedTotalTime: TimeInterval = 0
    var sessions: [StudySessionSummary] = []

    var predictedRemaining: TimeInterval {
        max(predictedTotalTime - actualTime, 0)
    }
}

struct StudySessionSummary: Hashable {
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let mode: String
    let activityId: UUID
}

struct CourseMetrics: Hashable {
    var courseId: UUID
    var weeklyStudy: [StudyWeek: TimeInterval] = [:]
    var gradeEntries: [GradeSnapshot] = []
}

struct GlobalStudyMetrics: Hashable {
    var typicalDailyCapacityHours: Double = 2.5
}

struct StudyWeek: Hashable, Comparable {
    let year: Int
    let weekOfYear: Int

    static func < (lhs: StudyWeek, rhs: StudyWeek) -> Bool {
        if lhs.year == rhs.year { return lhs.weekOfYear < rhs.weekOfYear }
        return lhs.year < rhs.year
    }
}

struct SuggestedBlock: Hashable {
    let start: Date
    let end: Date
    let locationHint: String?
}

struct TaskPlanningInsight: Identifiable, Hashable {
    let id: UUID
    let assignmentId: UUID
    let courseId: UUID
    let predictedRemainingTime: TimeInterval
    let dueDate: Date
    let riskScore: Double // 0...1
    let suggestedBlocks: [SuggestedBlock]
    let reasoning: String
}

struct CourseEffortSummary {
    let weeklyStudyTime: [StudyWeek: TimeInterval]
    let gradeTrend: [Double: TimeInterval]
    let recommendedWeeklyHours: TimeInterval?
}

/// Simple, explainable estimation model that adjusts by recent bias.
struct TimeEstimationModel {
    func predictedTotalTime(for assignment: AssignmentSnapshot, history: [AssignmentMetrics]) -> TimeInterval {
        let baseMinutes: Double
        if let est = assignment.estimatedMinutes { baseMinutes = Double(est) }
        else {
            // light defaults by category enum when available
            if let cat = assignment.category {
                switch cat {
                case .reading:
                    baseMinutes = 90
                case .exam:
                    baseMinutes = 180
                default:
                    baseMinutes = 120
                }
            } else {
                baseMinutes = 120
            }
        }

        let comparable = history.filter { $0.snapshot.courseId == assignment.courseId && $0.snapshot.category == assignment.category }
        let ratios: [Double] = comparable.compactMap { metrics in
            guard let est = metrics.snapshot.estimatedMinutes, est > 0 else { return nil }
            return (metrics.actualTime / 60.0) / Double(est)
        }
        let bias: Double
        if ratios.isEmpty {
            bias = 0
        } else {
            let sorted = ratios.sorted()
            let median = sorted[sorted.count / 2]
            bias = clamp(value: median - 1.0, lower: -0.5, upper: 1.0)
        }
        let predictedMinutes = baseMinutes * (1 + bias)
        return max(predictedMinutes * 60, baseMinutes * 30) // guardrail minimum
    }

    private func clamp(value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

/// Central analytics + planning engine. Consumes events, maintains rolling metrics, and offers planning insights.
@MainActor
final class RootsInsightsEngine: ObservableObject {
    static let shared = RootsInsightsEngine()

    private(set) var recentEvents: [InsightsEvent] = []
    private(set) var assignmentMetrics: [UUID: AssignmentMetrics] = [:]
    private(set) var courseMetrics: [UUID: CourseMetrics] = [:]
    private(set) var globalMetrics = GlobalStudyMetrics()

    private let estimationModel = TimeEstimationModel()
    private let maxEvents = 500

    private init() {}

    func record(_ event: InsightsEvent) {
        recentEvents.append(event)
        if recentEvents.count > maxEvents {
            recentEvents.removeFirst()
        }
        updateAggregates(for: event)
    }

    func currentPlanningInsights(for date: Date = Date()) -> [TaskPlanningInsight] {
        let today = Calendar.current.startOfDay(for: date)
        var insights: [TaskPlanningInsight] = []

        for metrics in assignmentMetrics.values {
            let due = metrics.snapshot.dueDate
            guard due >= today else { continue }
            let remaining = metrics.predictedRemaining
            guard remaining > 0 else { continue }

            let risk = riskScore(for: metrics, today: today)
            let blocks = suggestBlocks(required: remaining, dueDate: due)
            let reasoning = "Remaining \(Int(remaining/60)) min with \(daysBetween(today, due)) day(s) left."

            insights.append(TaskPlanningInsight(
                id: UUID(),
                assignmentId: metrics.snapshot.id,
                courseId: metrics.snapshot.courseId ?? UUID(),
                predictedRemainingTime: remaining,
                dueDate: due,
                riskScore: risk,
                suggestedBlocks: blocks,
                reasoning: reasoning
            ))
        }

        return insights.sorted { $0.riskScore > $1.riskScore }
    }

    func courseEffortSummary(courseId: UUID) -> CourseEffortSummary {
        let metrics = courseMetrics[courseId] ?? CourseMetrics(courseId: courseId)
        let weekly = metrics.weeklyStudy

        // Very simple “best band”: pick median weekly hours as a recommendation.
        let hours = weekly.values.map { $0 / 3600 }
        let recommended = hours.sorted().middleValue()
        return CourseEffortSummary(
            weeklyStudyTime: weekly,
            gradeTrend: [:],
            recommendedWeeklyHours: recommended
        )
    }

    // MARK: - Aggregation

    private func updateAggregates(for event: InsightsEvent) {
        switch event {
        case .assignmentCreated(let snap), .assignmentUpdated(let snap):
            upsertAssignmentSnapshot(snap)
        case .assignmentCompleted(let snap, let completedAt):
            upsertAssignmentSnapshot(snap)
            // Mark completion by closing remaining predicted time
            if var metrics = assignmentMetrics[snap.id] {
                metrics.actualTime = max(metrics.actualTime, metrics.predictedTotalTime)
                assignmentMetrics[snap.id] = metrics
            }
            // Log minimal completion into course weekly bucket
            if let courseId = snap.courseId {
                addStudyTime(courseId: courseId, duration: 0, at: completedAt)
            }
        case .studySessionCompleted(let session):
            apply(session: session)
        case .gradeRecorded(let grade):
            var course = courseMetrics[grade.courseId] ?? CourseMetrics(courseId: grade.courseId)
            course.gradeEntries.append(grade)
            courseMetrics[grade.courseId] = course
        case .resourceUsage:
            break
        }
    }

    private func upsertAssignmentSnapshot(_ snap: AssignmentSnapshot) {
        var metrics = assignmentMetrics[snap.id] ?? AssignmentMetrics(snapshot: snap)
        metrics.snapshot = snap
        metrics.predictedTotalTime = estimationModel.predictedTotalTime(for: snap, history: Array(assignmentMetrics.values))
        assignmentMetrics[snap.id] = metrics
    }

    private func apply(session: StudySessionSnapshot) {
        if let assignmentId = session.assignmentId, var metrics = assignmentMetrics[assignmentId] {
            metrics.actualTime += session.duration
            metrics.sessions.append(StudySessionSummary(startDate: session.startDate, endDate: session.endDate, duration: session.duration, mode: session.mode, activityId: session.activityId))
            assignmentMetrics[metrics.snapshot.id] = metrics
        }
        if let courseId = session.courseId {
            addStudyTime(courseId: courseId, duration: session.duration, at: session.endDate)
        }
    }

    private func addStudyTime(courseId: UUID, duration: TimeInterval, at date: Date) {
        let week = StudyWeek.from(date: date)
        var metrics = courseMetrics[courseId] ?? CourseMetrics(courseId: courseId)
        metrics.weeklyStudy[week, default: 0] += duration
        courseMetrics[courseId] = metrics
    }

    // MARK: - Risk & Suggestions

    private func riskScore(for metrics: AssignmentMetrics, today: Date) -> Double {
        let daysLeft = max(daysBetween(today, metrics.snapshot.dueDate), 0.5)
        let freeHours = globalMetrics.typicalDailyCapacityHours * daysLeft
        let remainingHours = metrics.predictedRemaining / 3600
        let raw = remainingHours / max(freeHours, 0.25)
        return min(max(raw, 0), 2).normalizedRisk()
    }

    private func suggestBlocks(required: TimeInterval, dueDate: Date) -> [SuggestedBlock] {
        // Simple placeholder: suggest two evening blocks before due date.
        var blocks: [SuggestedBlock] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let daysLeft = max(0, calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0)
        let chunk = min(required / Double(max(daysLeft, 1)), 90 * 60)
        for i in 0..<min(daysLeft + 1, 3) {
            if let start = calendar.date(byAdding: .day, value: i, to: today)?.addingTimeInterval(18 * 3600) {
                let end = start.addingTimeInterval(chunk)
                blocks.append(SuggestedBlock(start: start, end: end, locationHint: "Evening"))
            }
        }
        return blocks
    }
}

// MARK: - Helpers

private func daysBetween(_ start: Date, _ end: Date) -> Double {
    let comps = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: end))
    return Double(comps.day ?? 0)
}

private extension Array where Element == Double {
    func middleValue() -> Double? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        return sorted[count / 2]
    }
}

private extension Double {
    /// Map >1 ratios into capped 0...1 risk band with a soft curve.
    func normalizedRisk() -> Double {
        if self <= 1 { return max(self, 0) }
        // anything above 1 compress into 0.7...1 range
        return min(1, 0.7 + (self - 1) * 0.3)
    }
}

private extension StudyWeek {
    static func from(date: Date) -> StudyWeek {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return StudyWeek(year: comps.yearForWeekOfYear ?? 0, weekOfYear: comps.weekOfYear ?? 0)
    }
}

// MARK: - Snapshot factories (non-invasive helpers for existing models)

extension Assignment {
    func makeSnapshot() -> AssignmentSnapshot {
        AssignmentSnapshot(
            id: id,
            courseId: courseId,
            title: title,
            dueDate: dueDate,
            estimatedMinutes: estimatedMinutes,
            weightPercent: weightPercent,
            category: category
        )
    }
}

extension LocalTimerSession {
    func makeStudySnapshot(activity: LocalTimerActivity?, courseId: UUID?, assignmentId: UUID?) -> StudySessionSnapshot {
        StudySessionSnapshot(
            id: id,
            activityId: activity?.id ?? activityID,
            courseId: courseId,
            assignmentId: assignmentId,
            mode: mode.rawValue,
            startDate: startDate,
            endDate: endDate ?? startDate
        )
    }
}
