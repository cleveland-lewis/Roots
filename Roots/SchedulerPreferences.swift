import Foundation

// Minimal SchedulerPreferences used by AIScheduler.computePriority
public struct SchedulerPreferences: Codable {
    public var wUrgency: Double
    public var wImportance: Double
    public var wDifficulty: Double
    public var wSize: Double
    public var courseBias: [UUID: Double]

    public init(wUrgency: Double = 1.0, wImportance: Double = 1.0, wDifficulty: Double = 0.5, wSize: Double = 0.2, courseBias: [UUID: Double] = [:]) {
        self.wUrgency = wUrgency
        self.wImportance = wImportance
        self.wDifficulty = wDifficulty
        self.wSize = wSize
        self.courseBias = courseBias
    }

    public static func `default`() -> SchedulerPreferences {
        return SchedulerPreferences()
    }
}
