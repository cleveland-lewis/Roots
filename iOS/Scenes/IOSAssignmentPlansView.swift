import SwiftUI

// MARK: - Assignment Plan Card

struct AssignmentPlanCard: View {
    let assignment: Assignment
    let plan: AssignmentPlan?
    let onGeneratePlan: () -> Void
    let onToggleStep: (UUID) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            
            if let plan = plan {
                if isExpanded {
                    planSteps(plan)
                } else {
                    planSummary(plan)
                }
            } else {
                noPlanView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignSystem.Materials.card)
        )
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.headline)
                Text("Due \(formattedDate(assignment.dueDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if plan != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func planSummary(_ plan: AssignmentPlan) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(plan.completedStepsCount)/\(plan.steps.count) steps")
                    .font(.subheadline.weight(.semibold))
                Text("\(plan.totalEstimatedMinutes) min total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            progressCircle(plan)
        }
    }
    
    private func planSteps(_ plan: AssignmentPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(plan.sortedSteps) { step in
                PlanStepRow(
                    step: step,
                    isBlocked: plan.isStepBlocked(step),
                    onToggle: { onToggleStep(step.id) }
                )
            }
        }
    }
    
    private var noPlanView: some View {
        VStack(spacing: 8) {
            Text("No plan yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button("Generate Plan") {
                onGeneratePlan()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    private func progressCircle(_ plan: AssignmentPlan) -> some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                .frame(width: 44, height: 44)
            
            Circle()
                .trim(from: 0, to: plan.progressPercentage / 100)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(plan.progressPercentage))%")
                .font(.caption2.weight(.semibold))
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        LocaleFormatters.mediumDate.string(from: date)
    }
}

// MARK: - Plan Step Row

struct PlanStepRow: View {
    let step: PlanStep
    let isBlocked: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                if !isBlocked {
                    onToggle()
                }
            } label: {
                Image(systemName: checkboxIcon)
                    .foregroundStyle(checkboxColor)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(isBlocked)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(step.isCompleted)
                    .foregroundStyle(step.isCompleted ? .secondary : .primary)
                
                HStack(spacing: 8) {
                    Label("\(step.estimatedMinutes) min", systemImage: "clock")
                    
                    if let dueBy = step.dueBy {
                        Label(shortDate(dueBy), systemImage: "calendar")
                    }
                    
                    if step.isOverdue {
                        Label("Overdue", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                    
                    if isBlocked {
                        Label("Blocked", systemImage: "lock")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            stepTypeIcon
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isBlocked ? Color.orange.opacity(0.1) : Color.clear)
        )
    }
    
    private var checkboxIcon: String {
        if isBlocked {
            return "lock.circle"
        }
        return step.isCompleted ? "checkmark.circle.fill" : "circle"
    }
    
    private var checkboxColor: Color {
        if isBlocked {
            return .orange
        }
        return step.isCompleted ? .accentColor : .secondary
    }
    
    private var stepTypeIcon: some View {
        Image(systemName: iconForStepType)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    
    private var iconForStepType: String {
        switch step.stepType {
        case .task: return "doc.text"
        case .reading: return "book"
        case .practice: return "pencil.and.list.clipboard"
        case .review: return "arrow.triangle.2.circlepath"
        case .research: return "magnifyingglass"
        case .writing: return "pencil"
        case .preparation: return "calendar.badge.checkmark"
        }
    }
    
    private func shortDate(_ date: Date) -> String {
        LocaleFormatters.shortDate.string(from: date)
    }
}

// MARK: - Plans List View (for iOS)

#if os(iOS)
struct IOSAssignmentPlansView: View {
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var plansStore: AssignmentPlansStore
    @EnvironmentObject private var filterState: IOSFilterState
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var toastRouter: IOSToastRouter
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                header
                
                IOSFilterHeaderView(
                    coursesStore: coursesStore,
                    filterState: filterState
                )
                
                if filteredAssignments.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredAssignments) { assignment in
                        AssignmentPlanCard(
                            assignment: assignment,
                            plan: plansStore.plan(for: assignment.id),
                            onGeneratePlan: {
                                plansStore.generatePlan(for: assignment)
                                toastRouter.show("Plan generated")
                            },
                            onToggleStep: { stepId in
                                toggleStep(stepId, in: assignment.id)
                            }
                        )
                    }
                }
            }
            .padding(20)
        }
        .modifier(IOSNavigationChrome(title: "Plans") {
            Button {
                regenerateAll()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Regenerate all plans")
        })
        .onAppear {
            ensurePlansExist()
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Assignment Plans")
                    .font(.title3.weight(.semibold))
                if let lastRefresh = plansStore.lastRefreshDate {
                    Text("Updated \(timeAgo(lastRefresh))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No assignments")
                .font(.headline)
            Text("Add assignments to see their plans")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var filteredAssignments: [Assignment] {
        let tasks = assignmentsStore.tasks
        let courseLookup = coursesStore.courses
        
        let filtered = tasks.filter { task in
            guard let assignment = convertTaskToAssignment(task) else { return false }
            
            guard let courseId = assignment.courseId else {
                return filterState.selectedCourseId == nil && filterState.selectedSemesterId == nil
            }
            
            if let selectedCourse = filterState.selectedCourseId, selectedCourse != courseId {
                return false
            }
            
            if let semesterId = filterState.selectedSemesterId,
               let course = courseLookup.first(where: { $0.id == courseId }),
               course.semesterId != semesterId {
                return false
            }
            
            return !task.isCompleted
        }
        
        return filtered.compactMap { convertTaskToAssignment($0) }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    private func convertTaskToAssignment(_ task: AppTask) -> Assignment? {
        guard let due = task.due else { return nil }
        
        let assignmentCategory: AssignmentCategory
        switch task.category {
        case .exam: assignmentCategory = .exam
        case .quiz: assignmentCategory = .quiz
        case .practiceHomework: assignmentCategory = .practiceHomework
        case .reading: assignmentCategory = .reading
        case .review: assignmentCategory = .review
        case .project: assignmentCategory = .project
        }
        
        return Assignment(
            id: task.id,
            courseId: task.courseId,
            title: task.title,
            dueDate: due,
            estimatedMinutes: task.estimatedMinutes,
            weightPercent: task.gradeWeightPercent,
            category: assignmentCategory,
            urgency: urgencyFromImportance(task.importance),
            isLockedToDueDate: task.locked,
            plan: []
        )
    }
    
    private func urgencyFromImportance(_ importance: Double) -> AssignmentUrgency {
        switch importance {
        case ..<0.3: return .low
        case ..<0.6: return .medium
        case ..<0.85: return .high
        default: return .critical
        }
    }
    
    private func ensurePlansExist() {
        let assignments = filteredAssignments.filter { !plansStore.hasPlan(for: $0.id) }
        if !assignments.isEmpty {
            plansStore.generatePlans(for: assignments)
        }
    }
    
    private func regenerateAll() {
        plansStore.regenerateAllPlans(for: filteredAssignments)
        toastRouter.show("Plans regenerated")
    }
    
    private func toggleStep(_ stepId: UUID, in assignmentId: UUID) {
        guard let plan = plansStore.plan(for: assignmentId),
              let step = plan.steps.first(where: { $0.id == stepId }) else { return }
        
        if step.isCompleted {
            plansStore.uncompleteStep(stepId: stepId, in: assignmentId)
        } else {
            plansStore.completeStep(stepId: stepId, in: assignmentId)
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
#endif
