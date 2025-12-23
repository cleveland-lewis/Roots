#if os(macOS)
import SwiftUI
import Combine
import AppKit

// MARK: - Models

enum PlannerBlockStatus {
    case upcoming
    case inProgress
    case completed
    case overdue
}

struct PlannedBlock: Identifiable {
    let id: UUID
    var taskId: UUID?
    var courseId: UUID?
    var title: String
    var course: String?
    var start: Date
    var end: Date
    var isLocked: Bool
    var status: PlannerBlockStatus
    var source: String
    var isOmodoroLinked: Bool
}

struct PlannerTask: Identifiable {
    let id: UUID
    var courseId: UUID?
    var assignmentId: UUID?
    var title: String
    var course: String?
    var dueDate: Date
    var estimatedMinutes: Int
    var isLockedToDueDate: Bool
    var isScheduled: Bool
    var isCompleted: Bool
    var importance: Double? = nil   // 0...1
    var difficulty: Double? = nil   // 0...1
    var category: AssignmentCategory? = nil
}

// New task drafting types
struct PlannerTaskDraft {
    var id: UUID?
    var title: String
    var courseId: UUID?
    var courseCode: String?
    var assignmentID: UUID?
    var dueDate: Date
    var estimatedMinutes: Int
    var lockToDueDate: Bool
    var priority: PlannerTaskPriority
}

// Overdue task row view
struct OverdueTaskRow: View {
    var item: PlannerTask
    var onTap: () -> Void
    var onComplete: () -> Void

    private var daysLate: Int {
        let now = Date()
        let days = Calendar.current.dateComponents([.day], from: (item.dueDate), to: now).day ?? 0
        return max(0, days)
    }

    private var pillColor: Color {
        switch daysLate {
        case 0...1: return .yellow
        case 2...7: return .orange
        default: return .red
        }
    }

    private var pillText: String {
        switch daysLate {
        case 0: return NSLocalizedString("planner.overdue.today", comment: "")
        case 1: return NSLocalizedString("planner.overdue.one_day", comment: "")
        default: return String(format: NSLocalizedString("planner.overdue.days", comment: ""), daysLate)
        }
    }

    private func dueText(from date: Date) -> String {
        let now = Date()
        let days = Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0
        if days == 0 { return NSLocalizedString("planner.due.today", comment: "") }
        if days == 1 { return NSLocalizedString("planner.due.one_day_ago", comment: "") }
        return String(format: NSLocalizedString("planner.due.days_ago", comment: ""), days)
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: DesignSystem.Layout.spacing.small) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(DesignSystem.Typography.body)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let course = item.course { Text(course) }
                        Text("·")
                        Text(dueText(from: item.dueDate))
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                Text(pillText)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(pillColor.opacity(0.18)))

                Button {
                    onComplete()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(DesignSystem.Typography.body)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignSystem.Materials.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Overdue, due \(item.dueDate)")
    }
}

enum PlannerTaskPriority: String, CaseIterable, Identifiable {
    case low, normal, high, critical
    var id: String { rawValue }
}

/// Tracks day progress (time remaining / elapsed) for header metrics or future use.
final class DayProgressModel: ObservableObject {
    @Published var elapsedFraction: Double = 0.0
    @Published var remainingMinutes: Int = 0

    private var timer: Timer?

    func startUpdating(clock: Calendar = .current) {
        timer?.invalidate()
        update(clock: clock)
        // schedule to fire on next minute boundary to align nicely
        let nextInterval = 60.0 - Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + nextInterval) { [weak self] in
            self?.timer?.invalidate()
            self?.timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.update(clock: clock)
            }
        }
    }

    func stopUpdating() {
        timer?.invalidate()
        timer = nil
    }

    private func update(clock: Calendar) {
        let now = Date()
        let startOfDay = clock.startOfDay(for: now)
        guard let endOfDay = clock.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let totalSeconds = endOfDay.timeIntervalSince(startOfDay)
        let elapsedSeconds = now.timeIntervalSince(startOfDay)
        let clampedElapsed = max(0, min(elapsedSeconds, totalSeconds))

        elapsedFraction = totalSeconds > 0 ? clampedElapsed / totalSeconds : 0
        let remaining = max(0, Int((totalSeconds - clampedElapsed) / 60))
        remainingMinutes = remaining
    }
}

struct CourseSummary: Identifiable, Hashable {
    let id: UUID
    var code: String
    var title: String
}

// MARK: - Root Planner Page

// Minimal PlannerSettings used locally
struct PlannerSettings {
    var isOmodoroLinkedForToday: Bool = false
}


struct PlannerPageView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var plannerStore: PlannerStore
    @EnvironmentObject var assignmentsStore: AssignmentsStore
    @EnvironmentObject var plannerCoordinator: PlannerCoordinator
    @EnvironmentObject var coursesStore: CoursesStore
    @StateObject private var dayProgress = DayProgressModel()

    @State private var filterCancellable: AnyCancellable? = nil
    @State private var courseDeletedCancellable: AnyCancellable? = nil

    @State private var selectedDate: Date = Date()
    @State private var plannedBlocks: [PlannedBlock] = []
    @State private var unscheduledTasks: [PlannerTask] = []
    @State private var isRunningPlanner: Bool = false
    @State private var showTaskSheet: Bool = false
    @State private var editingTask: PlannerTask? = nil

    // new sheet state
    @State private var editingTaskDraft: PlannerTaskDraft? = nil

    // local simplified planner settings used during build
    @State private var plannerSettings = PlannerSettings()

    private let cardCornerRadius: CGFloat = 26
    private let studySettings = StudyPlanSettings()

    private var plannerLoading: Bool {
        plannerStore.isLoading || isRunningPlanner
    }

    private var hasStoredSessionsForSelectedDay: Bool {
        plannerStore.scheduled.contains { Calendar.current.isDate($0.start, inSameDayAs: selectedDate) }
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    headerBar
                        .padding(.top, DesignSystem.Layout.spacing.small)

                    HStack(alignment: .top, spacing: 18) {
                        timelineCard
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .layoutPriority(1)

                        rightColumn
                            .frame(minWidth: 280, idealWidth: 320, maxWidth: 360, alignment: .top)
                    }
                }
                .padding(.horizontal, DesignSystem.Layout.padding.window)
                .padding(.bottom, DesignSystem.Layout.spacing.large)
            }
        }
        .accentColor(settings.activeAccentColor)
        .sheet(isPresented: $showTaskSheet) {
            if let draft = editingTaskDraft {
                NewTaskSheet(
                    draft: draft,
                    isNew: draft.id == nil,
                    availableCourses: PlannerPageView.sampleCourses
                ) { updated in
                    applyDraft(updated)
                }
            }
        }
        .onAppear {
            dayProgress.startUpdating()
            hydrateFromStoredScheduleIfNeeded()
            syncTodayTasksAndSchedule()

            // subscribe to planner filter changes
            filterCancellable = plannerCoordinator.$selectedCourseFilter
                .receive(on: DispatchQueue.main)
                .sink { courseId in
                    if let cid = courseId {
                        // filter existing views immediately
                        plannedBlocks.removeAll { $0.courseId != nil && $0.courseId != cid }
                        unscheduledTasks.removeAll { $0.courseId != nil && $0.courseId != cid }
                    } else {
                        // refresh to show all
                        syncTodayTasksAndSchedule()
                    }
                }

            // subscribe to course deletions
            courseDeletedCancellable = CoursesStore.courseDeletedPublisher
                .receive(on: DispatchQueue.main)
                .sink { deletedId in
                    plannedBlocks.removeAll { $0.courseId == deletedId }
                    unscheduledTasks.removeAll { $0.courseId == deletedId }
                    if plannerCoordinator.selectedCourseFilter == deletedId {
                        plannerCoordinator.selectedCourseFilter = nil
                    }
                }
        }
        .onDisappear {
            dayProgress.stopUpdating()
        }
        .onChange(of: selectedDate) { _, _ in
            syncTodayTasksAndSchedule()
        }
        .onReceive(assignmentsStore.$tasks) { _ in
            syncTodayTasksAndSchedule()
        }
    }
}

// MARK: - Header

private extension PlannerPageView {
    var headerBar: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: DesignSystem.Layout.spacing.small) {
                Button {
                    withAnimation(DesignSystem.Motion.standardSpring) { adjustDate(by: -1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(DesignSystem.Typography.body)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.dayFormatter.string(from: selectedDate))
                        .font(DesignSystem.Typography.body)
                    Text(subtitleText)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    withAnimation(DesignSystem.Motion.standardSpring) { adjustDate(by: 1) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(DesignSystem.Typography.body)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: DesignSystem.Layout.spacing.small) {
                Button {
                    showNewTaskSheet()
                } label: {
                    Label(NSLocalizedString("planner.action.new_task", comment: ""), systemImage: "plus")
                        .font(DesignSystem.Typography.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(height: 38)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    runAIScheduler()
                } label: {
                    Text(isRunningPlanner ? NSLocalizedString("planner.action.planning", comment: "") : NSLocalizedString("planner.action.plan_day", comment: ""))
                        .font(DesignSystem.Typography.body)
                        .frame(height: 36)
                        .frame(minWidth: 120)
                }
                .buttonStyle(.bordered)
                .tint(settings.activeAccentColor)
                .controlSize(.regular)
                .disabled(isRunningPlanner)
                .opacity(isRunningPlanner ? 0.85 : 1)
            }
        }
        .padding(.horizontal, DesignSystem.Layout.padding.card)
    }

    var subtitleText: String {
        return "AI-planned focus blocks"
    }

    func adjustDate(by offset: Int) {
        let component: Calendar.Component = .day
        if let newDate = Calendar.current.date(byAdding: component, value: offset, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

// MARK: - Timeline Card

private extension PlannerPageView {
    func syncTodayTasksAndSchedule() {
        // Generate sessions for all assignments, schedule across days, then filter for selected date.
        func urgency(from importance: Double) -> AssignmentUrgency {
            if importance >= 0.75 { return .high }
            if importance >= 0.5 { return .medium }
            return .low
        }

        func category(from type: TaskType) -> AssignmentCategory {
            switch type {
            case .exam: return .exam
            case .quiz: return .quiz
            case .project: return .project
            case .practiceHomework: return .practiceHomework
            case .reading: return .reading
            case .review: return .review
            }
        }

        let assignments = assignmentsStore.tasks.map { task in
            Assignment(
                id: task.id,
                courseId: task.courseId,
                title: task.title,
                courseCode: "",
                courseName: "",
                category: category(from: task.type),
                dueDate: task.due ?? Date(),
                estimatedMinutes: max(30, task.estimatedMinutes),
                status: task.isCompleted ? .completed : .notStarted,
                urgency: urgency(from: task.importance),
                weightPercent: nil,
                isLockedToDueDate: task.locked,
                notes: "",
                plan: []
            )
        }

        let sessions = assignments.flatMap { PlannerEngine.generateSessions(for: $0, settings: studySettings) }
        let energy = SchedulerPreferencesStore.shared.preferences.learnedEnergyProfile
        let scheduledResult = PlannerEngine.scheduleSessions(sessions, settings: studySettings, energyProfile: energy)
        plannerStore.persist(scheduled: scheduledResult.scheduled, overflow: scheduledResult.overflow)

        let dayBlocks: [PlannedBlock] = scheduledResult.scheduled.compactMap { scheduled -> PlannedBlock? in
            let start = scheduled.start
            if !Calendar.current.isDate(start, inSameDayAs: selectedDate) { return nil }
            return PlannedBlock(
                id: scheduled.id,
                taskId: scheduled.session.assignmentId,
                courseId: nil,
                title: scheduled.session.title,
                course: nil,
                start: scheduled.start,
                end: scheduled.end,
                isLocked: scheduled.session.isLockedToDueDate,
                status: .upcoming,
                source: "Auto-plan",
                isOmodoroLinked: false
            )
        }

        plannedBlocks = dayBlocks

        let overflow = scheduledResult.overflow
        unscheduledTasks = overflow.map { session in
            PlannerTask(
                id: session.id,
                courseId: nil,
                assignmentId: session.assignmentId,
                title: session.title,
                course: nil,
                dueDate: session.dueDate,
                estimatedMinutes: session.estimatedMinutes,
                isLockedToDueDate: session.isLockedToDueDate,
                isScheduled: false,
                isCompleted: false,
                importance: session.importance == .high ? 0.8 : 0.5,
                difficulty: session.difficulty == .high ? 0.8 : 0.5,
                category: session.category
            )
        }
    }

    private func hydrateFromStoredScheduleIfNeeded() {
        if !plannedBlocks.isEmpty || plannerStore.scheduled.isEmpty {
            return
        }

        let calendar = Calendar.current
        let dayBlocks: [PlannedBlock] = plannerStore.scheduled.compactMap { stored -> PlannedBlock? in
            if !calendar.isDate(stored.start, inSameDayAs: selectedDate) { return nil }
            return PlannedBlock(
                id: stored.id,
                taskId: stored.assignmentId,
                courseId: nil,
                title: stored.title,
                course: nil,
                start: stored.start,
                end: stored.end,
                isLocked: stored.isLockedToDueDate,
                status: .upcoming,
                source: "Auto-plan",
                isOmodoroLinked: false
            )
        }
        plannedBlocks = dayBlocks
        unscheduledTasks = plannerStore.overflow.map { stored in
            PlannerTask(
                id: stored.id,
                courseId: nil,
                assignmentId: stored.assignmentId,
                title: stored.title,
                course: nil,
                dueDate: stored.dueDate,
                estimatedMinutes: stored.estimatedMinutes,
                isLockedToDueDate: stored.isLockedToDueDate,
                isScheduled: false,
                isCompleted: false,
                importance: stored.category == .exam ? 0.8 : 0.5,
                difficulty: stored.category == .project ? 0.7 : 0.5,
                category: stored.category
            )
        }
    }

    var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(NSLocalizedString("planner.timeline.title", comment: ""))
                    .font(DesignSystem.Typography.subHeader)
                if !unscheduledTasks.isEmpty {
                    Text("• \(unscheduledTasks.count) \(NSLocalizedString("planner.timeline.overflow", comment: ""))")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 1)
                        )
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                if plannerLoading {
                    plannerLoadingState
                } else if plannedBlocks.isEmpty && !hasStoredSessionsForSelectedDay {
                    plannerEmptyState
                } else {
                    ForEach(9...21, id: \.self) { hour in
                        timelineRow(for: hour)
                    }
                }
            }
        }
        .padding(18)
        .rootsCardBackground(radius: cardCornerRadius)
    }

    func timelineRow(for hour: Int) -> some View {
        let calendar = Calendar.current
        let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourDate) ?? hourDate
        let blocks = plannedBlocks.filter { $0.start < hourEnd && $0.end > hourDate }

        return HStack(alignment: .top, spacing: 12) {
            Text(Self.hourFormatter.string(from: hourDate))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                if blocks.isEmpty {
                    RoundedRectangle(cornerRadius: DesignSystem.Corners.block, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Corners.block, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                        )
                        .frame(height: 34)
                        .overlay(
                            HStack { Text(NSLocalizedString("planner.timeline.free", comment: "")).font(.caption).foregroundStyle(.secondary); Spacer() }
                                .padding(.horizontal, 10)
                        )
                } else {
                    ForEach(blocks) { block in
                        PlannerBlockRow(block: block)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Corners.block, style: .continuous)
                                    .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 1)
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var plannerLoadingState: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Loading sessions…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private var plannerEmptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No sessions for this day yet.")
                .font(.subheadline.weight(.semibold))
            Text("Run Plan Day to schedule tasks or add a task manually.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

}

// MARK: - Right Column

private extension PlannerPageView {
    var rightColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            unscheduledTasksCard
            overdueTasksCard
        }
    }

    var unscheduledTasksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("planner.unscheduled.title", comment: ""))
                    .font(DesignSystem.Typography.body)
                Spacer()
                if !unscheduledTasks.isEmpty {
                    Text("\(unscheduledTasks.count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 1)
                        )
                }
                Button {
                    showNewTaskSheet()
                } label: {
                    Image(systemName: "plus")
                        .font(DesignSystem.Typography.body)
                        .padding(DesignSystem.Layout.spacing.small)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if plannerLoading {
                plannerLoadingState
                    .padding(.vertical, 4)
            } else if unscheduledTasks.isEmpty && plannerStore.overflow.isEmpty {
                Text(NSLocalizedString("planner.unscheduled.empty", comment: ""))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignSystem.Layout.spacing.small) {
                        ForEach(unscheduledTasks) { task in
                            PlannerTaskRow(task: task) {
                                editingTask = task
                                editingTaskDraft = PlannerTaskDraft(
                                    id: task.id,
                                    title: task.title,
                                    courseId: task.courseId,
                                    courseCode: task.course,
                                    assignmentID: nil,
                                    dueDate: task.dueDate,
                                    estimatedMinutes: task.estimatedMinutes,
                                    lockToDueDate: task.isLockedToDueDate,
                                    priority: .normal
                                )
                                showTaskSheet = true
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .rootsCardBackground(radius: cardCornerRadius)
    }

    var overdueTasksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("planner.overdue.title", comment: ""))
                    .font(DesignSystem.Typography.body)
                Spacer()
                if !overdueTasks.isEmpty {
                    Text("● \(overdueTasks.count)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                }
            }

            if overdueTasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You’re caught up.")
                        .font(.subheadline.weight(.semibold))
                    Text("Anything overdue will appear here so the planner can prioritize it.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                let items = overdueTasks
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignSystem.Layout.spacing.small) {
                        ForEach(items.prefix(10)) { item in
                            OverdueTaskRow(item: item,
                                           onTap: {
                                               if item.isScheduled {
                                                   // TODO: scroll/focus timeline
                                               } else {
                                                   editingTaskDraft = PlannerTaskDraft(
                                                       id: item.id,
                                                       title: item.title,
                                                       courseId: item.courseId,
                                                       courseCode: item.course,
                                                       assignmentID: nil,
                                                       dueDate: item.dueDate,
                                                       estimatedMinutes: 60,
                                                       lockToDueDate: false,
                                                       priority: .normal
                                                   )
                                                   showTaskSheet = true
                                               }
                                           },
                                           onComplete: {
                                               withAnimation(DesignSystem.Motion.fluidSpring) {
                                                   markCompleted(item)
                                               }
                                           })
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    var overdueTasks: [PlannerTask] {
        let now = Date()
        return (unscheduledTasks + plannedTasksFromBlocks()).filter {
            !$0.isCompleted && ($0.dueDate) < now
        }
        .sorted { $0.dueDate < $1.dueDate }
    }

    private func plannedTasksFromBlocks() -> [PlannerTask] {
        plannedBlocks.compactMap { block in
            PlannerTask(id: block.id, title: block.title, course: block.course, dueDate: block.end, estimatedMinutes: Int(block.end.timeIntervalSince(block.start) / 60), isLockedToDueDate: block.isLocked, isScheduled: true, isCompleted: block.status == .completed)
        }
    }
}

// MARK: - Actions & Helpers

private extension PlannerPageView {
    func applyDraft(_ draft: PlannerTaskDraft) {
        // convert draft to PlannerTask for existing arrays
        let task = PlannerTask(
            id: draft.id ?? UUID(),
            courseId: draft.courseId,
            assignmentId: draft.assignmentID,
            title: draft.title,
            course: draft.courseCode,
            dueDate: draft.dueDate,
            estimatedMinutes: draft.estimatedMinutes,
            isLockedToDueDate: draft.lockToDueDate,
            isScheduled: false,
            isCompleted: false
        )
        if let idx = unscheduledTasks.firstIndex(where: { $0.id == task.id }) {
            unscheduledTasks[idx] = task
        } else {
            unscheduledTasks.append(task)
        }
    }

    func markCompleted(_ item: PlannerTask) {
        // mark completed in unscheduledTasks or plannedBlocks
        if let idx = unscheduledTasks.firstIndex(where: { $0.id == item.id }) {
            guard !unscheduledTasks[idx].isCompleted else { return }
            unscheduledTasks[idx].isCompleted = true
            unscheduledTasks.remove(at: idx)
            
            // Play completion feedback
            Task { @MainActor in
                Feedback.shared.play(.taskCompleted)
            }
            return
        }
        if let idx = plannedBlocks.firstIndex(where: { $0.id == item.id }) {
            let wasCompleted = plannedBlocks[idx].status == .completed
            plannedBlocks[idx].status = .completed
            
            if !wasCompleted {
                Task { @MainActor in
                    Feedback.shared.play(.taskCompleted)
                }
            }
        }
    }

    func showNewTaskSheet() {
        editingTaskDraft = PlannerTaskDraft(
            id: nil,
            title: "",
            courseId: nil,
            courseCode: nil,
            assignmentID: nil,
            dueDate: Date(),
            estimatedMinutes: 60,
            lockToDueDate: false,
            priority: .normal
        )
        showTaskSheet = true
    }

    func runAIScheduler() {
        guard !isRunningPlanner else { return }
        isRunningPlanner = true
        let tasksToSchedule = unscheduledTasks
        unscheduledTasks.removeAll()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            var currentStart = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: selectedDate) ?? selectedDate
            var newBlocks: [PlannedBlock] = []

            for task in tasksToSchedule {
                let endDate = Calendar.current.date(byAdding: .minute, value: task.estimatedMinutes, to: currentStart) ?? currentStart
                let block = PlannedBlock(
                    id: UUID(),
                    taskId: task.id,
                    courseId: task.courseId,
                    title: task.title,
                    course: task.course,
                    start: currentStart,
                    end: endDate,
                    isLocked: task.isLockedToDueDate,
                    status: .upcoming,
                    source: "Auto-scheduled",
                    isOmodoroLinked: false
                )
                newBlocks.append(block)
                currentStart = endDate
            }

            plannedBlocks.append(contentsOf: newBlocks)
            isRunningPlanner = false
        }
    }
}

// MARK: - Formatters

private extension PlannerPageView {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter
    }()

    static func samplePlannedBlocks(for date: Date) -> [PlannedBlock] {
        []
    }

    static func sampleUnscheduledTasks(for date: Date) -> [PlannerTask] {
        []
    }

    static var sampleCourses: [CourseSummary] {
        []
    }
}

// MARK: - Block Row

struct PlannerBlockRow: View {
    var block: PlannedBlock

    private var isFixedEvent: Bool {
        let lower = block.source.lowercased()
        return lower.contains("class") || lower.contains("calendar") || lower.contains("event")
    }

    private var accentBarColor: Color {
        if isFixedEvent { return .blue.opacity(0.8) }
        switch block.status {
        case .upcoming: return .accentColor
        case .inProgress: return .yellow
        case .completed: return .green
        case .overdue: return .red
        }
    }

    private var statusColor: Color {
        switch block.status {
        case .upcoming: return .accentColor
        case .inProgress: return .yellow
        case .completed: return .green
        case .overdue: return .red
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accentBarColor)
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(block.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                Text(metadataText)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if block.isLocked {
                Image(systemName: "lock.fill")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: DesignSystem.Layout.rowHeight.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Corners.block, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isFixedEvent ? 0.95 : 0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Corners.block, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 1)
        )
    }

    private var metadataText: String {
        let courseText = block.course ?? NSLocalizedString("planner.course.default", comment: "")
        return "\(courseText) · \(block.source)"
    }
}

// MARK: - Task Row

struct PlannerTaskRow: View {
    var task: PlannerTask
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(DesignSystem.Typography.body)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(task.course ?? NSLocalizedString("planner.course.default", comment: ""))
                        Text("· ~\(task.estimatedMinutes) \(NSLocalizedString("planner.task.minutes_short", comment: ""))")
                        Text("· \(NSLocalizedString("planner.task.due", comment: "")) \(PlannerTaskRow.dateFormatter.string(from: task.dueDate))")
                        if task.isLockedToDueDate {
                            Image(systemName: "lock.fill")
                        }
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()
}

// MARK: - New Task Sheet (redesigned)

struct NewTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var draft: PlannerTaskDraft
    let isNew: Bool
    let availableCourses: [CourseSummary]
    var onSave: (PlannerTaskDraft) -> Void

    private var isSaveDisabled: Bool {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var courseSelection: Binding<UUID?> {
        Binding(get: {
            draft.courseId
        }, set: { newValue in
            draft.courseId = newValue
            if let id = newValue, let match = availableCourses.first(where: { $0.id == id }) {
                draft.courseCode = match.code
            } else {
                draft.courseCode = nil
            }
        })
    }

    var body: some View {
        RootsPopupContainer(
            title: isNew ? NSLocalizedString("planner.task_sheet.new_title", comment: "") : NSLocalizedString("planner.task_sheet.edit_title", comment: ""),
            subtitle: NSLocalizedString("planner.task_sheet.subtitle", comment: "")
        ) {
            VStack(alignment: .leading, spacing: RootsSpacing.l) {
                taskSection
                courseSection
                timingSection
            }
        } footer: {
            footer
        }
        .frame(maxWidth: 560, maxHeight: 380)
        .frame(minWidth: RootsWindowSizing.minPopupWidth, minHeight: RootsWindowSizing.minPopupHeight)
        .onAppear {
            if draft.courseId == nil, let code = draft.courseCode,
               let match = availableCourses.first(where: { $0.code == code }) {
                draft.courseId = match.id
            }
        }
    }

    // Sections
    private var taskSection: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            Text(NSLocalizedString("planner.task_sheet.section.task", comment: "")).rootsSectionHeader()
            RootsFormRow(label: NSLocalizedString("planner.task_sheet.field.title", comment: "")) {
                TextField(NSLocalizedString("planner.task_sheet.field.title", comment: ""), text: $draft.title)
                    .textFieldStyle(.roundedBorder)
            }
            RootsFormRow(label: NSLocalizedString("planner.task_sheet.field.priority", comment: "")) {
                Picker("", selection: $draft.priority) {
                    ForEach(PlannerTaskPriority.allCases) { p in
                        Text(p.rawValue.capitalized).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }
        }
    }

    private var courseSection: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            Text(NSLocalizedString("planner.task_sheet.section.course", comment: "")).rootsSectionHeader()
            RootsFormRow(label: NSLocalizedString("planner.task_sheet.field.course", comment: "")) {
                Picker(NSLocalizedString("planner.task_sheet.field.course", comment: ""), selection: courseSelection) {
                    Text(NSLocalizedString("planner.task_sheet.field.course_none", comment: "")).tag(UUID?.none)
                    ForEach(availableCourses) { course in
                        Text("\(course.code) · \(course.title)").tag(Optional(course.id))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            RootsFormRow(label: NSLocalizedString("planner.task_sheet.field.assignment", comment: "")) {
                TextField(NSLocalizedString("planner.task_sheet.field.assignment_placeholder", comment: ""), text: Binding(
                    get: { draft.assignmentID == nil ? "" : NSLocalizedString("planner.task_sheet.field.assignment_linked", comment: "") },
                    set: { _ in /* hook later */ }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            Text(NSLocalizedString("planner.task_sheet.section.timing", comment: "")).rootsSectionHeader()
            RootsFormRow(label: NSLocalizedString("planner.task_sheet.field.due_date", comment: "")) {
                DatePicker("", selection: $draft.dueDate, in: Date()..., displayedComponents: .date)
                    .labelsHidden()
            }
            RootsFormRow(label: NSLocalizedString("planner.task_sheet.field.focus_estimate", comment: "")) {
                Stepper(value: $draft.estimatedMinutes, in: 15...480, step: 15) {
                    Text("\(draft.estimatedMinutes) \(NSLocalizedString("planner.task_sheet.field.minutes", comment: ""))")
                }
                .frame(maxWidth: 220, alignment: .leading)
            }
            RootsFormRow(label: "") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(NSLocalizedString("planner.task_sheet.field.lock_due_date", comment: ""), isOn: $draft.lockToDueDate)
                    Text(NSLocalizedString("planner.task_sheet.field.lock_due_date_help", comment: ""))
                        .rootsCaption()
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(NSLocalizedString("planner.task_sheet.action.cancel", comment: "")) { dismiss() }
            Button(isNew ? NSLocalizedString("planner.task_sheet.action.create", comment: "") : NSLocalizedString("planner.task_sheet.action.save", comment: "")) {
                onSave(draft)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isSaveDisabled)
        }
    }
}

// MARK: - Previews

struct PlannerPageView_Previews: PreviewProvider {
    static var previews: some View {
        PlannerPageView()
            .environmentObject(AppSettingsModel.shared)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
