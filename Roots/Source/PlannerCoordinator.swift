import Foundation
import Combine
import SwiftUI

@MainActor
final class PlannerCoordinator: ObservableObject {
    static let shared = PlannerCoordinator()

    /// Course id requested to open planner with (one-shot semantics)
    @Published var requestedCourseId: UUID? = nil
    /// Currently active filter for planner (persisted until changed)
    @Published var selectedCourseFilter: UUID? = nil

    func openPlanner(with courseId: UUID?) {
        requestedCourseId = courseId
        selectedCourseFilter = courseId
    }
}