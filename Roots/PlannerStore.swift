import SwiftUI
import Combine

@MainActor
final class PlannerStore: ObservableObject {
    static let shared = PlannerStore()
    
    @Published var scheduled: [ScheduledSession] = []
    @Published var overflow: [StudySession] = []
    @Published var isLoading: Bool = false
    
    private init() {
        load()
    }
    
    func persist(scheduled: [ScheduledSession], overflow: [StudySession]) {
        self.scheduled = scheduled
        self.overflow = overflow
        save()
    }
    
    func clearAll() {
        scheduled.removeAll()
        overflow.removeAll()
        save()
    }
    
    // MARK: - Persistence
    
    private func save() {
        let encoder = JSONEncoder()
        if let scheduledData = try? encoder.encode(scheduled) {
            UserDefaults.standard.set(scheduledData, forKey: "roots.planner.scheduled")
        }
        if let overflowData = try? encoder.encode(overflow) {
            UserDefaults.standard.set(overflowData, forKey: "roots.planner.overflow")
        }
    }
    
    private func load() {
        let decoder = JSONDecoder()
        
        if let scheduledData = UserDefaults.standard.data(forKey: "roots.planner.scheduled"),
           let decoded = try? decoder.decode([ScheduledSession].self, from: scheduledData) {
            scheduled = decoded
        }
        
        if let overflowData = UserDefaults.standard.data(forKey: "roots.planner.overflow"),
           let decoded = try? decoder.decode([StudySession].self, from: overflowData) {
            overflow = decoded
        }
    }
}
