import XCTest
@testable import SharedCore

final class PlanGraphTests: XCTestCase {
    
    // MARK: - Basic Construction
    
    func testEmptyGraphCreation() {
        let graph = PlanGraph()
        
        XCTAssertTrue(graph.nodes.isEmpty)
        XCTAssertTrue(graph.edges.isEmpty)
        XCTAssertTrue(graph.isValid)
        XCTAssertNil(graph.detectCycle())
    }
    
    func testAddSingleNode() throws {
        var graph = PlanGraph()
        let node = PlanNode(title: "Study Chapter 1", sortIndex: 0)
        
        try graph.addNode(node)
        
        XCTAssertEqual(graph.nodes.count, 1)
        XCTAssertEqual(graph.nodes.first?.title, "Study Chapter 1")
        XCTAssertTrue(graph.isValid)
    }
    
    func testAddMultipleNodes() throws {
        var graph = PlanGraph()
        let node1 = PlanNode(title: "Read", sortIndex: 0)
        let node2 = PlanNode(title: "Practice", sortIndex: 1)
        let node3 = PlanNode(title: "Review", sortIndex: 2)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        try graph.addNode(node3)
        
        XCTAssertEqual(graph.nodes.count, 3)
        XCTAssertTrue(graph.isValid)
    }
    
    // MARK: - Duplicate Detection
    
    func testDuplicateNodeRejection() {
        var graph = PlanGraph()
        let nodeId = UUID()
        let node1 = PlanNode(id: nodeId, title: "Task 1", sortIndex: 0)
        let node2 = PlanNode(id: nodeId, title: "Task 2", sortIndex: 1)
        
        XCTAssertNoThrow(try graph.addNode(node1))
        XCTAssertThrowsError(try graph.addNode(node2)) { error in
            guard case PlanGraph.ValidationError.duplicateNodeId(let id) = error else {
                XCTFail("Expected duplicateNodeId error")
                return
            }
            XCTAssertEqual(id, nodeId)
        }
    }
    
    func testDuplicateEdgeDetection() throws {
        var graph = PlanGraph()
        let node1 = PlanNode(title: "Task 1", sortIndex: 0)
        let node2 = PlanNode(title: "Task 2", sortIndex: 1)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        try graph.addEdge(from: node1.id, to: node2.id)
        
        XCTAssertThrowsError(try graph.addEdge(from: node1.id, to: node2.id)) { error in
            guard case PlanGraph.ValidationError.duplicateEdge = error else {
                XCTFail("Expected duplicateEdge error")
                return
            }
        }
    }
    
    // MARK: - Edge Validation
    
    func testSelfLoopRejection() throws {
        var graph = PlanGraph()
        let node = PlanNode(title: "Task", sortIndex: 0)
        
        try graph.addNode(node)
        
        XCTAssertThrowsError(try graph.addEdge(from: node.id, to: node.id)) { error in
            guard case PlanGraph.ValidationError.selfLoop(let id) = error else {
                XCTFail("Expected selfLoop error")
                return
            }
            XCTAssertEqual(id, node.id)
        }
    }
    
    func testOrphanEdgeDetection() {
        var graph = PlanGraph()
        let node1 = PlanNode(title: "Task 1", sortIndex: 0)
        let orphanId = UUID()
        
        graph.nodes.append(node1)
        graph.edges.append(PlanEdge(fromNodeId: node1.id, toNodeId: orphanId))
        
        let errors = graph.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { error in
            if case .orphanEdge = error { return true }
            return false
        })
    }
    
    // MARK: - Cycle Detection
    
    func testSimpleCycleDetection() throws {
        var graph = PlanGraph()
        let node1 = PlanNode(title: "A", sortIndex: 0)
        let node2 = PlanNode(title: "B", sortIndex: 1)
        let node3 = PlanNode(title: "C", sortIndex: 2)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        try graph.addNode(node3)
        
        // Create cycle: A → B → C → A
        try graph.addEdge(from: node1.id, to: node2.id)
        try graph.addEdge(from: node2.id, to: node3.id)
        
        XCTAssertThrowsError(try graph.addEdge(from: node3.id, to: node1.id)) { error in
            guard case PlanGraph.ValidationError.cycleDetected(let cycle) = error else {
                XCTFail("Expected cycleDetected error")
                return
            }
            XCTAssertFalse(cycle.isEmpty)
        }
    }
    
    func testComplexCycleDetection() throws {
        var graph = PlanGraph()
        let nodes = (0..<5).map { PlanNode(title: "Task \($0)", sortIndex: $0) }
        
        for node in nodes {
            try graph.addNode(node)
        }
        
        // Create complex dependency structure with cycle
        // 0 → 1 → 2 → 3 → 4 → 2 (cycle)
        try graph.addEdge(from: nodes[0].id, to: nodes[1].id)
        try graph.addEdge(from: nodes[1].id, to: nodes[2].id)
        try graph.addEdge(from: nodes[2].id, to: nodes[3].id)
        try graph.addEdge(from: nodes[3].id, to: nodes[4].id)
        
        XCTAssertThrowsError(try graph.addEdge(from: nodes[4].id, to: nodes[2].id)) { error in
            guard case PlanGraph.ValidationError.cycleDetected = error else {
                XCTFail("Expected cycleDetected error")
                return
            }
        }
    }
    
    func testNoCycleInLinearChain() throws {
        var graph = PlanGraph()
        let nodes = (0..<5).map { PlanNode(title: "Task \($0)", sortIndex: $0) }
        
        for node in nodes {
            try graph.addNode(node)
        }
        
        // Linear chain: 0 → 1 → 2 → 3 → 4
        for i in 0..<4 {
            try graph.addEdge(from: nodes[i].id, to: nodes[i+1].id)
        }
        
        XCTAssertNil(graph.detectCycle())
        XCTAssertTrue(graph.isValid)
    }
    
    func testNoCycleInDiamond() throws {
        var graph = PlanGraph()
        let nodes = (0..<4).map { PlanNode(title: "Task \($0)", sortIndex: $0) }
        
        for node in nodes {
            try graph.addNode(node)
        }
        
        // Diamond: 0 → {1, 2} → 3
        try graph.addEdge(from: nodes[0].id, to: nodes[1].id)
        try graph.addEdge(from: nodes[0].id, to: nodes[2].id)
        try graph.addEdge(from: nodes[1].id, to: nodes[3].id)
        try graph.addEdge(from: nodes[2].id, to: nodes[3].id)
        
        XCTAssertNil(graph.detectCycle())
        XCTAssertTrue(graph.isValid)
    }
    
    // MARK: - Topological Sort
    
    func testTopologicalSortLinearChain() throws {
        var graph = PlanGraph()
        let nodes = (0..<5).map { PlanNode(title: "Task \($0)", sortIndex: $0) }
        
        for node in nodes {
            try graph.addNode(node)
        }
        
        // Chain: 0 → 1 → 2 → 3 → 4
        for i in 0..<4 {
            try graph.addEdge(from: nodes[i].id, to: nodes[i+1].id)
        }
        
        let sorted = graph.topologicalSort()
        XCTAssertNotNil(sorted)
        XCTAssertEqual(sorted?.count, 5)
        
        // Verify order: each node appears before its dependents
        if let sorted = sorted {
            for i in 0..<4 {
                let currentIndex = sorted.firstIndex(where: { $0.id == nodes[i].id })!
                let nextIndex = sorted.firstIndex(where: { $0.id == nodes[i+1].id })!
                XCTAssertLessThan(currentIndex, nextIndex)
            }
        }
    }
    
    func testTopologicalSortDiamond() throws {
        var graph = PlanGraph()
        let nodes = (0..<4).map { PlanNode(title: "Task \($0)", sortIndex: $0) }
        
        for node in nodes {
            try graph.addNode(node)
        }
        
        // Diamond: 0 → {1, 2} → 3
        try graph.addEdge(from: nodes[0].id, to: nodes[1].id)
        try graph.addEdge(from: nodes[0].id, to: nodes[2].id)
        try graph.addEdge(from: nodes[1].id, to: nodes[3].id)
        try graph.addEdge(from: nodes[2].id, to: nodes[3].id)
        
        let sorted = graph.topologicalSort()
        XCTAssertNotNil(sorted)
        XCTAssertEqual(sorted?.count, 4)
        
        if let sorted = sorted {
            // Node 0 must come first
            XCTAssertEqual(sorted.first?.id, nodes[0].id)
            // Node 3 must come last
            XCTAssertEqual(sorted.last?.id, nodes[3].id)
            // Nodes 1 and 2 must come after 0 and before 3
            let index1 = sorted.firstIndex(where: { $0.id == nodes[1].id })!
            let index2 = sorted.firstIndex(where: { $0.id == nodes[2].id })!
            XCTAssertGreaterThan(index1, 0)
            XCTAssertGreaterThan(index2, 0)
            XCTAssertLessThan(index1, 3)
            XCTAssertLessThan(index2, 3)
        }
    }
    
    func testTopologicalSortDeterministic() throws {
        // Test that sorting is deterministic when multiple valid orders exist
        var graph = PlanGraph()
        
        // Create parallel tasks with explicit sortIndex
        let node1 = PlanNode(title: "Task 1", sortIndex: 1)
        let node2 = PlanNode(title: "Task 2", sortIndex: 2)
        let node3 = PlanNode(title: "Task 3", sortIndex: 3)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        try graph.addNode(node3)
        
        // No dependencies - pure parallel
        let sorted = graph.topologicalSort()
        XCTAssertNotNil(sorted)
        
        // Should be sorted by sortIndex
        if let sorted = sorted {
            XCTAssertEqual(sorted[0].id, node1.id)
            XCTAssertEqual(sorted[1].id, node2.id)
            XCTAssertEqual(sorted[2].id, node3.id)
        }
    }
    
    func testTopologicalSortWithCycleReturnsNil() throws {
        var graph = PlanGraph()
        let node1 = PlanNode(title: "A", sortIndex: 0)
        let node2 = PlanNode(title: "B", sortIndex: 1)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        
        // Manually create cycle (bypassing validation)
        graph.edges.append(PlanEdge(fromNodeId: node1.id, toNodeId: node2.id))
        graph.edges.append(PlanEdge(fromNodeId: node2.id, toNodeId: node1.id))
        
        XCTAssertNil(graph.topologicalSort())
    }
    
    // MARK: - Graph Queries
    
    func testGetPrerequisites() throws {
        var graph = PlanGraph()
        let node1 = PlanNode(title: "Read", sortIndex: 0)
        let node2 = PlanNode(title: "Practice", sortIndex: 1)
        let node3 = PlanNode(title: "Review", sortIndex: 2)
        let node4 = PlanNode(title: "Exam", sortIndex: 3)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        try graph.addNode(node3)
        try graph.addNode(node4)
        
        // Dependencies: {1, 2, 3} → 4
        try graph.addEdge(from: node1.id, to: node4.id)
        try graph.addEdge(from: node2.id, to: node4.id)
        try graph.addEdge(from: node3.id, to: node4.id)
        
        let prerequisites = graph.getPrerequisites(for: node4.id)
        XCTAssertEqual(prerequisites.count, 3)
        XCTAssertTrue(prerequisites.contains(where: { $0.id == node1.id }))
        XCTAssertTrue(prerequisites.contains(where: { $0.id == node2.id }))
        XCTAssertTrue(prerequisites.contains(where: { $0.id == node3.id }))
    }
    
    func testGetDependents() throws {
        var graph = PlanGraph()
        let node1 = PlanNode(title: "Read", sortIndex: 0)
        let node2 = PlanNode(title: "Practice", sortIndex: 1)
        let node3 = PlanNode(title: "Review", sortIndex: 2)
        let node4 = PlanNode(title: "Exam", sortIndex: 3)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        try graph.addNode(node3)
        try graph.addNode(node4)
        
        // Dependencies: 1 → {2, 3, 4}
        try graph.addEdge(from: node1.id, to: node2.id)
        try graph.addEdge(from: node1.id, to: node3.id)
        try graph.addEdge(from: node1.id, to: node4.id)
        
        let dependents = graph.getDependents(for: node1.id)
        XCTAssertEqual(dependents.count, 3)
        XCTAssertTrue(dependents.contains(where: { $0.id == node2.id }))
        XCTAssertTrue(dependents.contains(where: { $0.id == node3.id }))
        XCTAssertTrue(dependents.contains(where: { $0.id == node4.id }))
    }
    
    func testGetRootNodes() throws {
        var graph = PlanGraph()
        let node1 = PlanNode(title: "Root 1", sortIndex: 0)
        let node2 = PlanNode(title: "Root 2", sortIndex: 1)
        let node3 = PlanNode(title: "Dependent", sortIndex: 2)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        try graph.addNode(node3)
        
        // 1 → 3, 2 → 3
        try graph.addEdge(from: node1.id, to: node3.id)
        try graph.addEdge(from: node2.id, to: node3.id)
        
        let roots = graph.getRootNodes()
        XCTAssertEqual(roots.count, 2)
        XCTAssertTrue(roots.contains(where: { $0.id == node1.id }))
        XCTAssertTrue(roots.contains(where: { $0.id == node2.id }))
    }
    
    func testGetLeafNodes() throws {
        var graph = PlanGraph()
        let node1 = PlanNode(title: "Root", sortIndex: 0)
        let node2 = PlanNode(title: "Leaf 1", sortIndex: 1)
        let node3 = PlanNode(title: "Leaf 2", sortIndex: 2)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        try graph.addNode(node3)
        
        // 1 → {2, 3}
        try graph.addEdge(from: node1.id, to: node2.id)
        try graph.addEdge(from: node1.id, to: node3.id)
        
        let leaves = graph.getLeafNodes()
        XCTAssertEqual(leaves.count, 2)
        XCTAssertTrue(leaves.contains(where: { $0.id == node2.id }))
        XCTAssertTrue(leaves.contains(where: { $0.id == node3.id }))
    }
    
    func testIsNodeBlocked() throws {
        var graph = PlanGraph()
        var node1 = PlanNode(title: "Read", sortIndex: 0)
        let node2 = PlanNode(title: "Practice", sortIndex: 1)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        try graph.addEdge(from: node1.id, to: node2.id)
        
        // Node 2 is blocked because node 1 is not completed
        XCTAssertTrue(graph.isNodeBlocked(node2.id))
        
        // Complete node 1
        node1.isCompleted = true
        if let index = graph.nodes.firstIndex(where: { $0.id == node1.id }) {
            graph.nodes[index] = node1
        }
        
        // Node 2 is no longer blocked
        XCTAssertFalse(graph.isNodeBlocked(node2.id))
    }
    
    func testGetUnblockedNodes() throws {
        var graph = PlanGraph()
        var node1 = PlanNode(title: "Read", sortIndex: 0)
        let node2 = PlanNode(title: "Practice", sortIndex: 1)
        let node3 = PlanNode(title: "Review", sortIndex: 2)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        try graph.addNode(node3)
        
        // 1 → 2 → 3
        try graph.addEdge(from: node1.id, to: node2.id)
        try graph.addEdge(from: node2.id, to: node3.id)
        
        // Only node 1 is unblocked initially
        var unblocked = graph.getUnblockedNodes()
        XCTAssertEqual(unblocked.count, 1)
        XCTAssertEqual(unblocked.first?.id, node1.id)
        
        // Complete node 1
        node1.isCompleted = true
        if let index = graph.nodes.firstIndex(where: { $0.id == node1.id }) {
            graph.nodes[index] = node1
        }
        
        // Now node 2 is unblocked
        unblocked = graph.getUnblockedNodes()
        XCTAssertEqual(unblocked.count, 2)  // node 1 (completed) and node 2 (unblocked)
    }
    
    // MARK: - Graph Mutations
    
    func testMarkNodeCompleted() throws {
        var graph = PlanGraph()
        let node = PlanNode(title: "Task", sortIndex: 0)
        
        try graph.addNode(node)
        
        XCTAssertFalse(graph.nodes.first!.isCompleted)
        XCTAssertNil(graph.nodes.first!.completedAt)
        
        let completionDate = Date()
        graph.markNodeCompleted(node.id, at: completionDate)
        
        XCTAssertTrue(graph.nodes.first!.isCompleted)
        XCTAssertEqual(graph.nodes.first!.completedAt, completionDate)
    }
    
    func testMarkNodeIncomplete() throws {
        var graph = PlanGraph()
        var node = PlanNode(title: "Task", sortIndex: 0)
        node.isCompleted = true
        node.completedAt = Date()
        
        try graph.addNode(node)
        
        graph.markNodeIncomplete(node.id)
        
        XCTAssertFalse(graph.nodes.first!.isCompleted)
        XCTAssertNil(graph.nodes.first!.completedAt)
    }
    
    func testRemoveNode() throws {
        var graph = PlanGraph()
        let node1 = PlanNode(title: "Task 1", sortIndex: 0)
        let node2 = PlanNode(title: "Task 2", sortIndex: 1)
        let node3 = PlanNode(title: "Task 3", sortIndex: 2)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        try graph.addNode(node3)
        try graph.addEdge(from: node1.id, to: node2.id)
        try graph.addEdge(from: node2.id, to: node3.id)
        
        XCTAssertEqual(graph.nodes.count, 3)
        XCTAssertEqual(graph.edges.count, 2)
        
        // Remove middle node
        graph.removeNode(node2.id)
        
        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertEqual(graph.edges.count, 0)  // Both edges removed
    }
    
    func testRemoveEdge() throws {
        var graph = PlanGraph()
        let node1 = PlanNode(title: "Task 1", sortIndex: 0)
        let node2 = PlanNode(title: "Task 2", sortIndex: 1)
        
        try graph.addNode(node1)
        try graph.addNode(node2)
        try graph.addEdge(from: node1.id, to: node2.id)
        
        XCTAssertEqual(graph.edges.count, 1)
        
        graph.removeEdge(from: node1.id, to: node2.id)
        
        XCTAssertEqual(graph.edges.count, 0)
    }
    
    // MARK: - Statistics
    
    func testGraphStatistics() throws {
        var graph = PlanGraph()
        let nodes = (0..<5).map { 
            PlanNode(title: "Task \($0)", sortIndex: $0, estimatedDuration: 3600) 
        }
        
        for node in nodes {
            try graph.addNode(node)
        }
        
        // Linear chain
        for i in 0..<4 {
            try graph.addEdge(from: nodes[i].id, to: nodes[i+1].id)
        }
        
        // Mark first two as completed
        graph.markNodeCompleted(nodes[0].id)
        graph.markNodeCompleted(nodes[1].id)
        
        let stats = graph.getStatistics()
        
        XCTAssertEqual(stats.totalNodes, 5)
        XCTAssertEqual(stats.completedNodes, 2)
        XCTAssertEqual(stats.totalEdges, 4)
        XCTAssertEqual(stats.rootNodeCount, 1)
        XCTAssertEqual(stats.leafNodeCount, 1)
        XCTAssertEqual(stats.completionPercentage, 40.0, accuracy: 0.01)
        XCTAssertEqual(stats.estimatedTotalDuration, 18000)  // 5 nodes * 3600 seconds
    }
    
    // MARK: - Real-World Scenarios
    
    func testStudyPlanScenario() throws {
        // Scenario: Study → Quiz → Practice Exam → Final Exam
        var graph = PlanGraph()
        
        let study = PlanNode(
            title: "Study Chapters 1-5",
            nodeType: .reading,
            sortIndex: 0,
            estimatedDuration: 3600 * 4  // 4 hours
        )
        
        let quiz = PlanNode(
            title: "Complete Practice Quiz",
            nodeType: .quiz,
            sortIndex: 1,
            estimatedDuration: 1800  // 30 minutes
        )
        
        let practiceExam = PlanNode(
            title: "Practice Exam",
            nodeType: .practice,
            sortIndex: 2,
            estimatedDuration: 3600  // 1 hour
        )
        
        let finalExam = PlanNode(
            title: "Final Exam",
            nodeType: .exam,
            sortIndex: 3,
            estimatedDuration: 7200  // 2 hours
        )
        
        try graph.addNode(study)
        try graph.addNode(quiz)
        try graph.addNode(practiceExam)
        try graph.addNode(finalExam)
        
        // Dependencies: study → quiz → practice → final
        try graph.addEdge(from: study.id, to: quiz.id)
        try graph.addEdge(from: quiz.id, to: practiceExam.id)
        try graph.addEdge(from: practiceExam.id, to: finalExam.id)
        
        XCTAssertTrue(graph.isValid)
        XCTAssertNil(graph.detectCycle())
        
        let sorted = graph.topologicalSort()
        XCTAssertNotNil(sorted)
        XCTAssertEqual(sorted?.count, 4)
        
        // Verify order
        if let sorted = sorted {
            XCTAssertEqual(sorted[0].id, study.id)
            XCTAssertEqual(sorted[1].id, quiz.id)
            XCTAssertEqual(sorted[2].id, practiceExam.id)
            XCTAssertEqual(sorted[3].id, finalExam.id)
        }
        
        // Check initial unblocked nodes
        var unblocked = graph.getUnblockedNodes()
        XCTAssertEqual(unblocked.count, 1)
        XCTAssertEqual(unblocked.first?.id, study.id)
        
        // Complete study
        graph.markNodeCompleted(study.id)
        unblocked = graph.getUnblockedNodes()
        XCTAssertEqual(unblocked.count, 2)  // study + quiz
        
        // Complete quiz
        graph.markNodeCompleted(quiz.id)
        unblocked = graph.getUnblockedNodes()
        XCTAssertEqual(unblocked.count, 3)  // study + quiz + practice
    }
}
