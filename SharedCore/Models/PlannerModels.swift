//
//  PlannerModels.swift
//  Roots
//
//  Created for issue #181 - AssignmentPlan data model
//

#if !DISABLE_SWIFTDATA
import Foundation
import SwiftData

@Model
final class AssignmentPlan {
    @Attribute(.unique) var assignmentId: UUID
    var generatedAt: Date
    var version: Int
    var status: PlanStatus
    
    @Relationship(deleteRule: .cascade, inverse: \PlanStep.plan)
    var steps: [PlanStep]
    
    init(assignmentId: UUID, generatedAt: Date = Date(), version: Int = 1, status: PlanStatus = .draft, steps: [PlanStep] = []) {
        self.assignmentId = assignmentId
        self.generatedAt = generatedAt
        self.version = version
        self.status = status
        self.steps = steps
    }
}

@Model
final class PlanStep {
    var id: UUID
    var title: String
    var estimatedDuration: Int
    var recommendedWindow: Date?
    var dueBy: Date?
    var sequenceIndex: Int
    var stepType: StepType
    
    var plan: AssignmentPlan?
    
    init(id: UUID = UUID(), title: String, estimatedDuration: Int, recommendedWindow: Date? = nil, dueBy: Date? = nil, sequenceIndex: Int, stepType: StepType = .work) {
        self.id = id
        self.title = title
        self.estimatedDuration = estimatedDuration
        self.recommendedWindow = recommendedWindow
        self.dueBy = dueBy
        self.sequenceIndex = sequenceIndex
        self.stepType = stepType
    }
}

enum PlanStatus: String, Codable {
    case draft
    case active
    case completed
    case archived
}

enum StepType: String, Codable {
    case work
    case review
    case practice
    case research
}

#endif
