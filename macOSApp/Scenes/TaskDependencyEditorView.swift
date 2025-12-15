#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

/// View for managing task dependencies within an assignment plan
struct TaskDependencyEditorView: View {
    let assignmentId: UUID
    let assignmentTitle: String
    @StateObject private var planStore = AssignmentPlanStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showCycleAlert = false
    @State private var cycleMessage = ""
    @State private var draggedStep: PlanStep?
    
    private var plan: AssignmentPlan? {
        planStore.getPlan(for: assignmentId)
    }
    
    private var sortedSteps: [PlanStep] {
        plan?.sortedSteps ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if let plan = plan {
                if plan.steps.isEmpty {
                    emptyStateView
                } else {
                    contentView(plan: plan)
                }
            } else {
                noPlanView
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .alert("Dependency Cycle Detected", isPresented: $showCycleAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cycleMessage)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: DesignSystem.Layout.spacing.medium) {
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
                    Label("Enforce Task Order", systemImage: "arrow.right.circle")
                        .font(.subheadline.weight(.medium))
                }
                .toggleStyle(.switch)
                .help("When enabled, tasks must be completed in order")
            }
            
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(DesignSystem.Layout.padding.window)
    }
    
    // MARK: - Content Views
    
    private func contentView(plan: AssignmentPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.large) {
                // Status banner
                if plan.sequenceEnforcementEnabled {
                    enforcementBanner
                }
                
                // Task list
                VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
                    Text("Task Order")
                        .font(.headline)
                        .padding(.horizontal, DesignSystem.Layout.padding.window)
                    
                    taskListView(plan: plan)
                }
                
                // Info section
                if plan.sequenceEnforcementEnabled {
                    infoSection
                }
            }
            .padding(.vertical, DesignSystem.Layout.spacing.medium)
        }
    }
    
    private var enforcementBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "link.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Task Order Enforced")
                    .font(.subheadline.weight(.semibold))
                Text("Tasks must be completed in sequence. Drag to reorder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Clear Dependencies") {
                clearDependencies()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(DesignSystem.Layout.padding.card)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Corners.medium, style: .continuous))
        .padding(.horizontal, DesignSystem.Layout.padding.window)
    }
    
    private func taskListView(plan: AssignmentPlan) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(sortedSteps.enumerated()), id: \.element.id) { index, step in
                taskRow(step: step, index: index, plan: plan)
                    .onDrag {
                        self.draggedStep = step
                        return NSItemProvider(object: step.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: TaskDropDelegate(
                        step: step,
                        steps: sortedSteps,
                        draggedStep: $draggedStep,
                        onMove: { from, to in
                            reorderSteps(from: from, to: to)
                        }
                    ))
            }
        }
        .padding(.horizontal, DesignSystem.Layout.padding.window)
    }
    
    private func taskRow(step: PlanStep, index: Int, plan: AssignmentPlan) -> some View {
        HStack(spacing: DesignSystem.Layout.spacing.medium) {
            // Sequence number
            Text("\(index + 1)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())
            
            // Dependency indicator
            if plan.sequenceEnforcementEnabled && step.hasPrerequisites {
                Image(systemName: "arrow.right.circle")
                    .font(.body)
                    .foregroundStyle(.blue)
                    .help("Depends on previous task")
            }
            
            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.body.weight(.medium))
                
                HStack(spacing: 12) {
                    Label("\(step.estimatedMinutes) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if step.isCompleted {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if plan.isStepBlocked(step) {
                        Label("Blocked", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .padding(DesignSystem.Layout.padding.card)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Corners.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Corners.small, style: .continuous)
                .strokeBorder(plan.isStepBlocked(step) ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How Dependencies Work")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "arrow.right.circle", text: "Each task depends on the previous task in the list")
                infoRow(icon: "lock.fill", text: "Blocked tasks cannot start until prerequisites are completed")
                infoRow(icon: "line.3.horizontal", text: "Drag tasks to reorder the sequence")
            }
        }
        .padding(DesignSystem.Layout.padding.window)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Corners.medium, style: .continuous))
        .padding(.horizontal, DesignSystem.Layout.padding.window)
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
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
    
    private func toggleEnforcement() {
        planStore.toggleSequenceEnforcement(for: assignmentId)
        
        // Check for cycles after toggling
        if let plan = planStore.getPlan(for: assignmentId),
           plan.sequenceEnforcementEnabled,
           plan.detectCycle() != nil {
            showCycleAlert = true
            cycleMessage = "A circular dependency was detected in your task order. Please review and reorder tasks."
        }
    }
    
    private func clearDependencies() {
        planStore.clearAllDependencies(for: assignmentId)
    }
    
    private func reorderSteps(from: Int, to: Int) {
        guard var plan = planStore.getPlan(for: assignmentId) else { return }
        
        var steps = plan.sortedSteps
        let step = steps.remove(at: from)
        steps.insert(step, at: to)
        
        // Update sequence indices
        for (index, var updatedStep) in steps.enumerated() {
            updatedStep.sequenceIndex = index
            if let stepIndex = plan.steps.firstIndex(where: { $0.id == updatedStep.id }) {
                plan.steps[stepIndex] = updatedStep
            }
        }
        
        // If enforcement is enabled, rebuild the linear chain
        if plan.sequenceEnforcementEnabled {
            plan.setupLinearChain()
            
            // Check for cycles
            if plan.detectCycle() != nil {
                showCycleAlert = true
                cycleMessage = "Reordering created a circular dependency. Changes reverted."
                return
            }
        }
        
        planStore.savePlan(plan)
    }
}

// MARK: - Drag and Drop Delegate

struct TaskDropDelegate: DropDelegate {
    let step: PlanStep
    let steps: [PlanStep]
    @Binding var draggedStep: PlanStep?
    let onMove: (Int, Int) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        draggedStep = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedStep = draggedStep,
              draggedStep.id != step.id,
              let fromIndex = steps.firstIndex(where: { $0.id == draggedStep.id }),
              let toIndex = steps.firstIndex(where: { $0.id == step.id }) else {
            return
        }
        
        if fromIndex != toIndex {
            onMove(fromIndex, toIndex)
        }
    }
}

// MARK: - Preview

#Preview {
    TaskDependencyEditorView(
        assignmentId: UUID(),
        assignmentTitle: "Sample Assignment"
    )
    .frame(width: 700, height: 500)
}

#endif
