#if os(macOS)
import SwiftUI

/// Enhanced view for managing task dependencies using PlanGraph
struct EnhancedTaskDependencyEditorView: View {
    let assignmentId: UUID
    let assignmentTitle: String
    @StateObject private var planStore = AssignmentPlanStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var graph: PlanGraph?
    @State private var selectedNode: UUID?
    @State private var showCycleAlert = false
    @State private var cycleMessage = ""
    @State private var draggedNode: PlanNode?
    @State private var showAddDependencySheet = false
    
    private var plan: AssignmentPlan? {
        planStore.getPlan(for: assignmentId)
    }
    
    private var sortedNodes: [PlanNode] {
        guard let graph = graph else { return [] }
        return graph.topologicalSort() ?? graph.nodes.sorted { $0.sortIndex < $1.sortIndex }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            
            if let plan = plan, let graph = graph {
                if graph.nodes.isEmpty {
                    emptyStateView
                } else {
                    contentView(plan: plan, graph: graph)
                }
            } else {
                noPlanView
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            loadGraph()
        }
        .alert("Dependency Cycle Detected", isPresented: $showCycleAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cycleMessage)
        }
        .sheet(isPresented: $showAddDependencySheet) {
            if let nodeId = selectedNode, let graph = graph {
                AddDependencySheet(
                    nodeId: nodeId,
                    graph: graph,
                    onAdd: { prereqId in
                        addDependency(from: prereqId, to: nodeId)
                    }
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Task Dependencies")
                    .font(.title2.weight(.semibold))
                Text(assignmentTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let plan = plan {
                Toggle(isOn: Binding(
                    get: { plan.sequenceEnforcementEnabled },
                    set: { _ in toggleEnforcement() }
                )) {
                    Label("Enforce Dependencies", systemImage: "link.circle")
                        .font(.subheadline.weight(.medium))
                }
                .toggleStyle(.switch)
                .help("When enabled, tasks must be completed in order based on dependencies")
            }
            
            Button("Done") {
                saveAndDismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }
    
    // MARK: - Content Views
    
    private func contentView(plan: AssignmentPlan, graph: PlanGraph) -> some View {
        HSplitView {
            // Left: Task list
            taskListView(plan: plan, graph: graph)
                .frame(minWidth: 350)
            
            // Right: Dependency visualization
            dependencyVisualizationView(graph: graph)
                .frame(minWidth: 300)
        }
    }
    
    private func taskListView(plan: AssignmentPlan, graph: PlanGraph) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Status banner
                if plan.sequenceEnforcementEnabled {
                    statusBanner(graph: graph)
                }
                
                // Task list
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Tasks")
                            .font(.headline)
                        Spacer()
                        if plan.sequenceEnforcementEnabled {
                            Button(action: { showAddDependencySheet = true }) {
                                Label("Add Dependency", systemImage: "plus.circle")
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedNode == nil)
                        }
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(sortedNodes) { node in
                            taskRow(node: node, graph: graph, plan: plan)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    private func statusBanner(graph: PlanGraph) -> some View {
        let stats = graph.getStatistics()
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dependencies Enabled")
                        .font(.subheadline.weight(.semibold))
                    Text("\(stats.totalEdges) dependencies • \(stats.completionPercentage, specifier: "%.0f")% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Clear All") {
                    clearAllDependencies()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if stats.totalEdges > 0 {
                HStack(spacing: 16) {
                    statItem(icon: "arrow.right.circle", value: "\(stats.rootNodeCount)", label: "Start Tasks")
                    statItem(icon: "flag.circle", value: "\(stats.leafNodeCount)", label: "End Tasks")
                    statItem(icon: "arrow.triangle.branch", value: "\(stats.longestPath)", label: "Longest Chain")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(value)
                .fontWeight(.semibold)
            Text(label)
        }
    }
    
    private func taskRow(node: PlanNode, graph: PlanGraph, plan: AssignmentPlan) -> some View {
        let isSelected = selectedNode == node.id
        let isBlocked = graph.isNodeBlocked(node.id)
        let prerequisites = graph.getPrerequisites(for: node.id)
        let dependents = graph.getDependents(for: node.id)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Completion checkbox
                Button(action: { toggleNodeCompletion(node.id) }) {
                    Image(systemName: node.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(node.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.borderless)
                
                // Task info
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.title)
                        .font(.body.weight(.medium))
                        .strikethrough(node.isCompleted)
                    
                    HStack(spacing: 12) {
                        Label("\(node.estimatedMinutes) min", systemImage: "clock")
                            .font(.caption)
                        
                        if node.isCompleted {
                            Label("Completed", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if isBlocked && plan.sequenceEnforcementEnabled {
                            Label("Blocked", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Dependency count
                if plan.sequenceEnforcementEnabled && !prerequisites.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.caption2)
                        Text("\(prerequisites.count)")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                if plan.sequenceEnforcementEnabled && !dependents.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                        Text("\(dependents.count)")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            // Prerequisites list
            if plan.sequenceEnforcementEnabled && !prerequisites.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Depends on:")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    ForEach(prerequisites) { prereq in
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption2)
                            Text(prereq.title)
                                .font(.caption)
                            Spacer()
                            Button(action: { removeDependency(from: prereq.id, to: node.id) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 12)
                    }
                }
                .padding(8)
                .background(Color.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor :
                    isBlocked && plan.sequenceEnforcementEnabled ? Color.orange.opacity(0.5) : Color.clear,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .onTapGesture {
            selectedNode = node.id
        }
    }
    
    private func dependencyVisualizationView(graph: PlanGraph) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Dependency Graph")
                    .font(.headline)
                
                if let selectedNode = selectedNode, let node = graph.getNode(selectedNode) {
                    selectedNodeDetailView(node: node, graph: graph)
                } else {
                    graphOverviewView(graph: graph)
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private func selectedNodeDetailView(node: PlanNode, graph: PlanGraph) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Node header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.title)
                        .font(.title3.weight(.semibold))
                    Text("Node Details")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { selectedNode = nil }) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Prerequisites section
            VStack(alignment: .leading, spacing: 8) {
                Label("Prerequisites (\(graph.getPrerequisites(for: node.id).count))", systemImage: "arrow.left.circle")
                    .font(.subheadline.weight(.semibold))
                
                let prereqs = graph.getPrerequisites(for: node.id)
                if prereqs.isEmpty {
                    Text("No prerequisites")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 24)
                } else {
                    ForEach(prereqs) { prereq in
                        HStack {
                            Image(systemName: prereq.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(prereq.isCompleted ? .green : .secondary)
                            Text(prereq.title)
                                .font(.caption)
                        }
                        .padding(.leading, 24)
                    }
                }
            }
            .padding(12)
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Dependents section
            VStack(alignment: .leading, spacing: 8) {
                Label("Dependents (\(graph.getDependents(for: node.id).count))", systemImage: "arrow.right.circle")
                    .font(.subheadline.weight(.semibold))
                
                let dependents = graph.getDependents(for: node.id)
                if dependents.isEmpty {
                    Text("No dependents")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 24)
                } else {
                    ForEach(dependents) { dependent in
                        HStack {
                            Image(systemName: dependent.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(dependent.isCompleted ? .green : .secondary)
                            Text(dependent.title)
                                .font(.caption)
                        }
                        .padding(.leading, 24)
                    }
                }
            }
            .padding(12)
            .background(Color.purple.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Status
            if graph.isNodeBlocked(node.id) {
                Label("This task is blocked by incomplete prerequisites", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
    
    private func graphOverviewView(graph: PlanGraph) -> some View {
        let stats = graph.getStatistics()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Select a task to view its dependencies")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
            
            // Statistics
            VStack(alignment: .leading, spacing: 12) {
                Text("Graph Statistics")
                    .font(.subheadline.weight(.semibold))
                
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Total Tasks:")
                        Text("\(stats.totalNodes)")
                            .fontWeight(.semibold)
                    }
                    GridRow {
                        Text("Completed:")
                        Text("\(stats.completedNodes)")
                            .fontWeight(.semibold)
                    }
                    GridRow {
                        Text("Dependencies:")
                        Text("\(stats.totalEdges)")
                            .fontWeight(.semibold)
                    }
                    GridRow {
                        Text("Root Tasks:")
                        Text("\(stats.rootNodeCount)")
                            .fontWeight(.semibold)
                    }
                    GridRow {
                        Text("Longest Chain:")
                        Text("\(stats.longestPath)")
                            .fontWeight(.semibold)
                    }
                }
                .font(.caption)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Validation status
            let errors = graph.validate()
            if errors.isEmpty {
                Label("Graph is valid (no cycles)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Graph has issues:", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    ForEach(errors.indices, id: \.self) { index in
                        Text("• \(errors[index].description)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Tasks in Plan")
                .font(.title3.weight(.semibold))
            Text("Create a plan for this assignment to manage task dependencies")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noPlanView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Plan Found")
                .font(.title3.weight(.semibold))
            Text("Create an assignment plan to enable task dependencies")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadGraph() {
        guard let plan = plan else { return }
        graph = plan.toPlanGraph()
    }
    
    private func toggleEnforcement() {
        planStore.toggleSequenceEnforcement(for: assignmentId)
        loadGraph()
    }
    
    private func toggleNodeCompletion(_ nodeId: UUID) {
        guard var graph = graph else { return }
        
        if let node = graph.getNode(nodeId), node.isCompleted {
            graph.markNodeIncomplete(nodeId)
        } else {
            graph.markNodeCompleted(nodeId)
        }
        
        self.graph = graph
    }
    
    private func addDependency(from: UUID, to: UUID) {
        guard var graph = graph else { return }
        
        do {
            try graph.addEdge(from: from, to: to)
            self.graph = graph
        } catch let error as PlanGraph.ValidationError {
            cycleMessage = error.description
            showCycleAlert = true
        } catch {
            cycleMessage = "Failed to add dependency: \(error.localizedDescription)"
            showCycleAlert = true
        }
    }
    
    private func removeDependency(from: UUID, to: UUID) {
        guard var graph = graph else { return }
        graph.removeEdge(from: from, to: to)
        self.graph = graph
    }
    
    private func clearAllDependencies() {
        guard var graph = graph else { return }
        graph.edges.removeAll()
        self.graph = graph
    }
    
    private func saveAndDismiss() {
        guard var plan = plan, let graph = graph else {
            dismiss()
            return
        }
        
        // Apply graph changes back to plan
        plan.applyPlanGraph(graph)
        planStore.savePlan(plan)
        
        dismiss()
    }
}

// MARK: - Add Dependency Sheet

struct AddDependencySheet: View {
    let nodeId: UUID
    let graph: PlanGraph
    let onAdd: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPrereqId: UUID?
    
    private var currentNode: PlanNode? {
        graph.getNode(nodeId)
    }
    
    private var availablePrerequisites: [PlanNode] {
        let existingPrereqs = Set(graph.getPrerequisites(for: nodeId).map { $0.id })
        return graph.nodes.filter { node in
            node.id != nodeId && !existingPrereqs.contains(node.id)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Prerequisite")
                    .font(.title2.weight(.semibold))
                if let node = currentNode {
                    Text("For: \(node.title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Selection list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(availablePrerequisites) { prereq in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(prereq.title)
                                    .font(.body)
                                if prereq.isCompleted {
                                    Label("Completed", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                            Spacer()
                            if selectedPrereqId == prereq.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(12)
                        .background(selectedPrereqId == prereq.id ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .onTapGesture {
                            selectedPrereqId = prereq.id
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            
            if availablePrerequisites.isEmpty {
                Text("No tasks available to add as prerequisites")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: 300)
            }
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add Prerequisite") {
                    if let prereqId = selectedPrereqId {
                        onAdd(prereqId)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedPrereqId == nil)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

// MARK: - Preview

#Preview {
    EnhancedTaskDependencyEditorView(
        assignmentId: UUID(),
        assignmentTitle: "Sample Assignment"
    )
    .frame(width: 900, height: 600)
}

#endif
