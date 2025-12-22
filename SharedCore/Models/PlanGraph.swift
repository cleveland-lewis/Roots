import Foundation

// MARK: - Plan Graph (DAG) Model

/// Directed Acyclic Graph for assignment plan dependencies
/// Represents task dependencies where edges flow from prerequisite → dependent
public struct PlanGraph: Codable, Equatable, Sendable {
    public let id: UUID
    public var nodes: [PlanNode]
    public var edges: [PlanEdge]
    public var metadata: PlanGraphMetadata
    
    public init(
        id: UUID = UUID(),
        nodes: [PlanNode] = [],
        edges: [PlanEdge] = [],
        metadata: PlanGraphMetadata = PlanGraphMetadata()
    ) {
        self.id = id
        self.nodes = nodes
        self.edges = edges
        self.metadata = metadata
    }
    
    // MARK: - Validation
    
    /// Validation result for the graph
    public enum ValidationError: Error, Equatable, CustomStringConvertible {
        case cycleDetected([UUID])
        case orphanEdge(PlanEdge)
        case duplicateEdge(PlanEdge)
        case duplicateNodeId(UUID)
        case selfLoop(UUID)
        case invalidNodeReference(UUID)
        
        public var description: String {
            switch self {
            case .cycleDetected(let nodeIds):
                return "Cycle detected in dependency graph: \(nodeIds.map { $0.uuidString.prefix(8) }.joined(separator: " → "))"
            case .orphanEdge(let edge):
                return "Edge references non-existent node(s): \(edge.fromNodeId.uuidString.prefix(8)) → \(edge.toNodeId.uuidString.prefix(8))"
            case .duplicateEdge(let edge):
                return "Duplicate edge: \(edge.fromNodeId.uuidString.prefix(8)) → \(edge.toNodeId.uuidString.prefix(8))"
            case .duplicateNodeId(let id):
                return "Duplicate node ID: \(id.uuidString.prefix(8))"
            case .selfLoop(let id):
                return "Self-loop detected: node \(id.uuidString.prefix(8)) depends on itself"
            case .invalidNodeReference(let id):
                return "Invalid node reference: \(id.uuidString.prefix(8))"
            }
        }
    }
    
    /// Validate the graph structure
    /// Returns array of errors, empty if valid
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Check for duplicate node IDs
        let nodeIds = nodes.map { $0.id }
        let uniqueIds = Set(nodeIds)
        if nodeIds.count != uniqueIds.count {
            let duplicates = nodeIds.filter { id in
                nodeIds.filter { $0 == id }.count > 1
            }
            for duplicate in Set(duplicates) {
                errors.append(.duplicateNodeId(duplicate))
            }
        }
        
        // Check for orphan edges (edges referencing non-existent nodes)
        let nodeIdSet = Set(nodes.map { $0.id })
        for edge in edges {
            if !nodeIdSet.contains(edge.fromNodeId) || !nodeIdSet.contains(edge.toNodeId) {
                errors.append(.orphanEdge(edge))
            }
        }
        
        // Check for self-loops
        for edge in edges {
            if edge.fromNodeId == edge.toNodeId {
                errors.append(.selfLoop(edge.fromNodeId))
            }
        }
        
        // Check for duplicate edges
        let edgeTuples = edges.map { ($0.fromNodeId, $0.toNodeId) }
        let uniqueEdges = Set(edgeTuples)
        if edgeTuples.count != uniqueEdges.count {
            let duplicates = edges.filter { edge in
                edges.filter { $0.fromNodeId == edge.fromNodeId && $0.toNodeId == edge.toNodeId }.count > 1
            }
            for duplicate in Set(duplicates) {
                errors.append(.duplicateEdge(duplicate))
            }
        }
        
        // Check for cycles
        if let cycle = detectCycle() {
            errors.append(.cycleDetected(cycle))
        }
        
        return errors
    }
    
    /// Returns true if the graph is valid (DAG with no orphan edges)
    public var isValid: Bool {
        validate().isEmpty
    }
    
    // MARK: - Cycle Detection (Tarjan's Algorithm)
    
    /// Detect cycle using depth-first search with recursion stack
    /// Returns array of node IDs forming the cycle, or nil if no cycle
    public func detectCycle() -> [UUID]? {
        var visited = Set<UUID>()
        var recursionStack = Set<UUID>()
        var cyclePath: [UUID] = []
        
        func dfs(nodeId: UUID, path: [UUID]) -> Bool {
            if recursionStack.contains(nodeId) {
                // Found cycle - extract cycle path
                if let cycleStart = path.firstIndex(of: nodeId) {
                    cyclePath = Array(path[cycleStart...]) + [nodeId]
                }
                return true
            }
            
            if visited.contains(nodeId) {
                return false
            }
            
            visited.insert(nodeId)
            recursionStack.insert(nodeId)
            
            // Visit all nodes that depend on this node (outgoing edges)
            for edge in edges where edge.fromNodeId == nodeId {
                if dfs(nodeId: edge.toNodeId, path: path + [nodeId]) {
                    return true
                }
            }
            
            recursionStack.remove(nodeId)
            return false
        }
        
        // Check all nodes (handles disconnected components)
        for node in nodes {
            if !visited.contains(node.id) {
                if dfs(nodeId: node.id, path: []) {
                    return cyclePath
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Topological Sort (Kahn's Algorithm)
    
    /// Perform topological sort of nodes
    /// Returns sorted nodes or nil if cycle detected
    public func topologicalSort() -> [PlanNode]? {
        // Cannot sort if cycle exists
        if detectCycle() != nil {
            return nil
        }
        
        var result: [PlanNode] = []
        var inDegree: [UUID: Int] = [:]
        var adjList: [UUID: [UUID]] = [:]
        
        // Initialize in-degree and adjacency list
        for node in nodes {
            inDegree[node.id] = 0
            adjList[node.id] = []
        }
        
        // Build adjacency list and calculate in-degrees
        for edge in edges {
            adjList[edge.fromNodeId, default: []].append(edge.toNodeId)
            inDegree[edge.toNodeId, default: 0] += 1
        }
        
        // Queue nodes with zero in-degree
        var queue = nodes.filter { inDegree[$0.id] == 0 }
        
        // Sort queue by sortIndex for deterministic ordering
        queue.sort { $0.sortIndex < $1.sortIndex }
        
        while !queue.isEmpty {
            let node = queue.removeFirst()
            result.append(node)
            
            // Reduce in-degree for dependent nodes
            for neighborId in adjList[node.id, default: []] {
                inDegree[neighborId, default: 0] -= 1
                
                if inDegree[neighborId] == 0,
                   let neighborNode = nodes.first(where: { $0.id == neighborId }) {
                    queue.append(neighborNode)
                    // Keep queue sorted for deterministic ordering
                    queue.sort { $0.sortIndex < $1.sortIndex }
                }
            }
        }
        
        // If not all nodes processed, there's a cycle (shouldn't happen if detectCycle passed)
        return result.count == nodes.count ? result : nil
    }
    
    // MARK: - Graph Queries
    
    /// Get all prerequisites for a node (nodes that must complete before this one)
    public func getPrerequisites(for nodeId: UUID) -> [PlanNode] {
        let prereqIds = edges.filter { $0.toNodeId == nodeId }.map { $0.fromNodeId }
        return nodes.filter { prereqIds.contains($0.id) }
    }
    
    /// Get all dependents for a node (nodes that depend on this one)
    public func getDependents(for nodeId: UUID) -> [PlanNode] {
        let dependentIds = edges.filter { $0.fromNodeId == nodeId }.map { $0.toNodeId }
        return nodes.filter { dependentIds.contains($0.id) }
    }
    
    /// Check if a node is blocked by incomplete prerequisites
    public func isNodeBlocked(_ nodeId: UUID) -> Bool {
        let prerequisites = getPrerequisites(for: nodeId)
        return prerequisites.contains { !$0.isCompleted }
    }
    
    /// Get all unblocked nodes (no incomplete prerequisites)
    public func getUnblockedNodes() -> [PlanNode] {
        nodes.filter { !isNodeBlocked($0.id) }
    }
    
    /// Get all root nodes (nodes with no prerequisites)
    public func getRootNodes() -> [PlanNode] {
        let nodesWithPrereqs = Set(edges.map { $0.toNodeId })
        return nodes.filter { !nodesWithPrereqs.contains($0.id) }
    }
    
    /// Get all leaf nodes (nodes with no dependents)
    public func getLeafNodes() -> [PlanNode] {
        let nodesWithDependents = Set(edges.map { $0.fromNodeId })
        return nodes.filter { !nodesWithDependents.contains($0.id) }
    }
    
    /// Get node by ID
    public func getNode(_ id: UUID) -> PlanNode? {
        nodes.first { $0.id == id }
    }
    
    // MARK: - Graph Mutations
    
    /// Add a node to the graph
    public mutating func addNode(_ node: PlanNode) throws {
        guard !nodes.contains(where: { $0.id == node.id }) else {
            throw ValidationError.duplicateNodeId(node.id)
        }
        nodes.append(node)
    }
    
    /// Remove a node and all connected edges
    public mutating func removeNode(_ nodeId: UUID) {
        nodes.removeAll { $0.id == nodeId }
        edges.removeAll { $0.fromNodeId == nodeId || $0.toNodeId == nodeId }
    }
    
    /// Add an edge (dependency)
    /// fromNodeId → toNodeId means "toNode depends on fromNode"
    public mutating func addEdge(from fromNodeId: UUID, to toNodeId: UUID) throws {
        // Check for self-loop
        guard fromNodeId != toNodeId else {
            throw ValidationError.selfLoop(fromNodeId)
        }
        
        // Check nodes exist
        guard nodes.contains(where: { $0.id == fromNodeId }) else {
            throw ValidationError.invalidNodeReference(fromNodeId)
        }
        guard nodes.contains(where: { $0.id == toNodeId }) else {
            throw ValidationError.invalidNodeReference(toNodeId)
        }
        
        let edge = PlanEdge(fromNodeId: fromNodeId, toNodeId: toNodeId)
        
        // Check for duplicate
        guard !edges.contains(edge) else {
            throw ValidationError.duplicateEdge(edge)
        }
        
        // Temporarily add edge and check for cycles
        var tempGraph = self
        tempGraph.edges.append(edge)
        
        if let cycle = tempGraph.detectCycle() {
            throw ValidationError.cycleDetected(cycle)
        }
        
        // Safe to add
        edges.append(edge)
    }
    
    /// Remove an edge
    public mutating func removeEdge(from fromNodeId: UUID, to toNodeId: UUID) {
        edges.removeAll { $0.fromNodeId == fromNodeId && $0.toNodeId == toNodeId }
    }
    
    /// Mark a node as completed
    public mutating func markNodeCompleted(_ nodeId: UUID, at date: Date = Date()) {
        if let index = nodes.firstIndex(where: { $0.id == nodeId }) {
            nodes[index].isCompleted = true
            nodes[index].completedAt = date
        }
    }
    
    /// Mark a node as incomplete
    public mutating func markNodeIncomplete(_ nodeId: UUID) {
        if let index = nodes.firstIndex(where: { $0.id == nodeId }) {
            nodes[index].isCompleted = false
            nodes[index].completedAt = nil
        }
    }
}

// MARK: - Plan Node

/// A node in the plan graph representing a task/step
public struct PlanNode: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var assignmentId: UUID?
    public var title: String
    public var nodeType: NodeType
    public var sortIndex: Int  // For deterministic ordering within same dependency level
    public var estimatedDuration: TimeInterval  // seconds
    public var isCompleted: Bool
    public var completedAt: Date?
    public var metadata: NodeMetadata
    
    public init(
        id: UUID = UUID(),
        assignmentId: UUID? = nil,
        title: String,
        nodeType: NodeType = .task,
        sortIndex: Int = 0,
        estimatedDuration: TimeInterval = 0,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        metadata: NodeMetadata = NodeMetadata()
    ) {
        self.id = id
        self.assignmentId = assignmentId
        self.title = title
        self.nodeType = nodeType
        self.sortIndex = sortIndex
        self.estimatedDuration = estimatedDuration
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.metadata = metadata
    }
    
    public enum NodeType: String, Codable, Sendable {
        case task
        case reading
        case practice
        case review
        case research
        case writing
        case preparation
        case exam
        case quiz
        case lab
    }
    
    public struct NodeMetadata: Codable, Equatable, Hashable, Sendable {
        public var notes: String?
        public var priority: Int?  // 1 = highest
        public var tags: [String]
        public var recommendedStartDate: Date?
        public var dueBy: Date?
        
        public init(
            notes: String? = nil,
            priority: Int? = nil,
            tags: [String] = [],
            recommendedStartDate: Date? = nil,
            dueBy: Date? = nil
        ) {
            self.notes = notes
            self.priority = priority
            self.tags = tags
            self.recommendedStartDate = recommendedStartDate
            self.dueBy = dueBy
        }
    }
}

// MARK: - Plan Edge

/// An edge in the plan graph representing a dependency
/// fromNodeId → toNodeId means "toNode depends on fromNode"
/// (toNode cannot start until fromNode is completed)
public struct PlanEdge: Codable, Equatable, Hashable, Sendable {
    public let fromNodeId: UUID  // Prerequisite node
    public let toNodeId: UUID    // Dependent node
    public var metadata: EdgeMetadata
    
    public init(
        fromNodeId: UUID,
        toNodeId: UUID,
        metadata: EdgeMetadata = EdgeMetadata()
    ) {
        self.fromNodeId = fromNodeId
        self.toNodeId = toNodeId
        self.metadata = metadata
    }
    
    public struct EdgeMetadata: Codable, Equatable, Hashable, Sendable {
        public var isHard: Bool  // Hard dependency (must complete) vs soft (recommended)
        public var reason: String?  // Why this dependency exists
        
        public init(isHard: Bool = true, reason: String? = nil) {
            self.isHard = isHard
            self.reason = reason
        }
    }
}

// MARK: - Graph Metadata

public struct PlanGraphMetadata: Codable, Equatable, Sendable {
    public var name: String?
    public var description: String?
    public var createdAt: Date
    public var lastModified: Date
    public var version: Int
    
    public init(
        name: String? = nil,
        description: String? = nil,
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        version: Int = 1
    ) {
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.version = version
    }
}

// MARK: - Helper Extensions

extension PlanNode {
    /// Estimated duration in minutes for UI display
    public var estimatedMinutes: Int {
        Int(estimatedDuration / 60)
    }
    
    /// Whether this node is overdue
    public var isOverdue: Bool {
        guard let dueBy = metadata.dueBy, !isCompleted else { return false }
        return Date() > dueBy
    }
}

extension PlanGraph {
    /// Statistics about the graph
    public struct GraphStatistics: Equatable {
        public let totalNodes: Int
        public let completedNodes: Int
        public let totalEdges: Int
        public let rootNodeCount: Int
        public let leafNodeCount: Int
        public let longestPath: Int
        public let estimatedTotalDuration: TimeInterval
        
        public var completionPercentage: Double {
            guard totalNodes > 0 else { return 0 }
            return Double(completedNodes) / Double(totalNodes) * 100
        }
    }
    
    /// Get statistics about the graph
    public func getStatistics() -> GraphStatistics {
        GraphStatistics(
            totalNodes: nodes.count,
            completedNodes: nodes.filter { $0.isCompleted }.count,
            totalEdges: edges.count,
            rootNodeCount: getRootNodes().count,
            leafNodeCount: getLeafNodes().count,
            longestPath: calculateLongestPath(),
            estimatedTotalDuration: nodes.reduce(0) { $0 + $1.estimatedDuration }
        )
    }
    
    /// Calculate longest path length (critical path)
    private func calculateLongestPath() -> Int {
        guard let sorted = topologicalSort() else { return 0 }
        
        var distances: [UUID: Int] = [:]
        
        // Initialize all distances to 0
        for node in nodes {
            distances[node.id] = 0
        }
        
        // Process nodes in topological order
        for node in sorted {
            for edge in edges where edge.fromNodeId == node.id {
                let newDistance = (distances[node.id] ?? 0) + 1
                distances[edge.toNodeId] = max(distances[edge.toNodeId] ?? 0, newDistance)
            }
        }
        
        return distances.values.max() ?? 0
    }
}
