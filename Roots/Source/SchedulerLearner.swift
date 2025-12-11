import Foundation

struct SchedulerLearner {
    static func updatePreferences(from feedback: [BlockFeedback], preferences: inout SchedulerPreferences) {
        guard !feedback.isEmpty else { return }

        // Energy profile learning
        var successMinutesByHour: [Int: Double] = [:]
        var failureMinutesByHour: [Int: Double] = [:]
        for h in 0..<24 { successMinutesByHour[h] = 0.0; failureMinutesByHour[h] = 0.0 }

        // Block length by type
        var totalMinutesByType: [String: Double] = [:]
        var countByType: [String: Int] = [:]

        // Course stats
        var successByCourse: [UUID: Int] = [:]
        var failByCourse: [UUID: Int] = [:]

        for fb in feedback {
            let hour = Calendar.current.component(.hour, from: fb.start)
            let minutes = fb.end.timeIntervalSince(fb.start) / 60.0
            if fb.completion >= 0.7 && fb.action == .kept {
                successMinutesByHour[hour, default: 0.0] += minutes
                totalMinutesByType[fb.type.rawValue, default: 0.0] += minutes
                countByType[fb.type.rawValue, default: 0] += 1
                if let cid = fb.courseId { successByCourse[cid, default: 0] += 1 }
            } else if fb.completion < 0.3 || fb.action == .deleted {
                failureMinutesByHour[hour, default: 0.0] += minutes
                if let cid = fb.courseId { failByCourse[cid, default: 0] += 1 }
            }
        }

        // Update energy profile with EMA smoothing
        let alpha = 0.2
        for h in 0..<24 {
            let succ = successMinutesByHour[h] ?? 0
            let fail = failureMinutesByHour[h] ?? 0
            let observed: Double = (succ + fail) > 0 ? (succ / max(1.0, succ + fail)) : preferences.learnedEnergyProfile[h] ?? 0.5
            let old = preferences.learnedEnergyProfile[h] ?? 0.5
            let updated = alpha * observed + (1 - alpha) * old
            preferences.learnedEnergyProfile[h] = min(max(updated, 0.0), 1.0)
        }

        // Update preferred block lengths
        for (typeRaw, total) in totalMinutesByType {
            let count = countByType[typeRaw] ?? 1
            let avg = Int(max(1, round(total / Double(count))))
            // EMA style update
            let old = preferences.preferredBlockLengthByType[typeRaw] ?? 50
            let newVal = Int(round(alpha * Double(avg) + (1 - alpha) * Double(old)))
            preferences.preferredBlockLengthByType[typeRaw] = min(max(newVal, 15), 240)
        }

        // Update course bias
        for (cid, failed) in failByCourse {
            let succ = successByCourse[cid] ?? 0
            let delta = Double(failed - succ)
            let old = preferences.courseBias[cid] ?? 0.0
            // small learning rate
            let lr = 0.05
            preferences.courseBias[cid] = old + lr * delta
        }
    }
}
