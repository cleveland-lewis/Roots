import Foundation

struct SchedulerPreferences: Codable {
    // Weights for priority
    var wUrgency: Double
    var wImportance: Double
    var wDifficulty: Double
    var wSize: Double

    // Learned energy profile (hour -> 0..1)
    var learnedEnergyProfile: [Int: Double]

    // Preferred block lengths per task type (string keyed)
    var preferredBlockLengthByType: [String: Int]

    // Course bias
    var courseBias: [UUID: Double]

    static func `default`() -> SchedulerPreferences {
        var energy: [Int: Double] = [:]
        for h in 0..<24 { energy[h] = (h >= 9 && h <= 21) ? 0.7 : 0.3 }
        var pref: [String: Int] = [:]
        for t in TaskType.allCases { pref[t.rawValue] = 50 }
        return SchedulerPreferences(wUrgency: 0.45, wImportance: 0.35, wDifficulty: 0.10, wSize: 0.10, learnedEnergyProfile: energy, preferredBlockLengthByType: pref, courseBias: [:])
    }

    // Helpers
    func preferredBlockLength(for type: TaskType) -> Int {
        return preferredBlockLengthByType[type.rawValue] ?? 50
    }
}
