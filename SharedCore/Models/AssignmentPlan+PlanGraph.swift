import Foundation

// MARK: - AssignmentPlan <-> PlanGraph Bridge

extension AssignmentPlan {
    /// Convert AssignmentPlan to PlanGraph for dependency management
    func toPlanGraph() -> PlanGraph {
        var graph = PlanGraph(
            id: self.id,
            metadata: PlanGraphMetadata(
                name: "Plan for Assignment \(self.assignmentId)",
                description: nil,
                createdAt: self.generatedAt,
                lastModified: Date(),
                version: self.version
            )
        )
        
        // Add nodes from steps
        for step in steps {
            let node = PlanNode(
                id: step.id,
                assignmentId: self.assignmentId,
                title: step.title,
                nodeType: mapStepTypeToNodeType(step.stepType),
                sortIndex: step.sequenceIndex,
                estimatedDuration: step.estimatedDuration,
                isCompleted: step.isCompleted,
                completedAt: step.completedAt,
                metadata: PlanNode.NodeMetadata(
                    notes: step.notes,
                    priority: nil,
                    tags: [],
                    recommendedStartDate: step.recommendedStartDate,
                    dueBy: step.dueBy
                )
            )
            
            try? graph.addNode(node)
        }
        
        // Add edges from prerequisiteIds
        for step in steps {
            for prereqId in step.prerequisiteIds {
                try? graph.addEdge(from: prereqId, to: step.id)
            }
        }
        
        return graph
    }
    
    /// Update AssignmentPlan from PlanGraph
    mutating func applyPlanGraph(_ graph: PlanGraph) {
        // Update steps with node information
        for node in graph.nodes {
            if let index = steps.firstIndex(where: { $0.id == node.id }) {
                steps[index].isCompleted = node.isCompleted
                steps[index].completedAt = node.completedAt
                steps[index].sequenceIndex = node.sortIndex
                
                // Update prerequisites from edges
                let prereqIds = graph.getPrerequisites(for: node.id).map { $0.id }
                steps[index].prerequisiteIds = prereqIds
            }
        }
        
        // Update version
        self.version = graph.metadata.version
    }
    
    private func mapStepTypeToNodeType(_ stepType: PlanStep.StepType) -> PlanNode.NodeType {
        switch stepType {
        case .task: return .task
        case .reading: return .reading
        case .practice: return .practice
        case .review: return .review
        case .research: return .research
        case .writing: return .writing
        case .preparation: return .preparation
        }
    }
}

extension PlanGraph {
    /// Create a PlanGraph from an AssignmentPlan
    static func from(_ plan: AssignmentPlan) -> PlanGraph {
        return plan.toPlanGraph()
    }
}
