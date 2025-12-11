import Foundation

final class SchedulerAdaptationManager {
    static let shared = SchedulerAdaptationManager()
    private init() {}

    private let lastRunKey = "SchedulerLearnerLastRun"

    func runAdaptiveSchedulerUpdateIfNeeded(force: Bool = false) {
        let feedback = SchedulerFeedbackStore.shared.feedback
        guard !feedback.isEmpty else { return }
        if !force {
            if let last = UserDefaults.standard.object(forKey: lastRunKey) as? Date {
                let elapsed = Date().timeIntervalSince(last)
                // Run at most once every 6 hours by default
                if elapsed < 6 * 3600 { return }
            }
        }

        var prefs = SchedulerPreferencesStore.shared.preferences
        SchedulerLearner.updatePreferences(from: feedback, preferences: &prefs)
        SchedulerPreferencesStore.shared.preferences = prefs
        SchedulerPreferencesStore.shared.save()
        SchedulerFeedbackStore.shared.clear()
        UserDefaults.standard.set(Date(), forKey: lastRunKey)
    }
}
