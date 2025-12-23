import Foundation
import Combine
import SwiftUI

@MainActor
final class PlannerCoordinator: ObservableObject {
    static let shared = PlannerCoordinator()

    /// Course id requested to open planner with (one-shot semantics)
    @Published var requestedCourseId: UUID? = nil
    /// Date requested to open planner with (one-shot semantics)
    @Published var requestedDate: Date? = nil
    /// Currently active filter for planner (persisted until changed)
    @Published var selectedCourseFilter: UUID? = nil

    func openPlanner(with courseId: UUID?) {
        requestedCourseId = courseId
        selectedCourseFilter = courseId
    }

    func openPlanner(for date: Date?, courseId: UUID? = nil) {
        requestedDate = date
        requestedCourseId = courseId
        selectedCourseFilter = courseId
    }
}
