import SwiftUI
import Combine

// MARK: - Models

enum PlannerScope: String, CaseIterable, Identifiable {
    case today, week, all
    var id: String { rawValue }
}

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
    var priority: TaskPriority
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
        case 0: return "Today"
        case 1: return "1 day overdue"
        default: return "\(daysLate) days overdue"
        }
    }

    private func dueText(from date: Date) -> String {
        let now = Date()
        let days = Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0
        if days == 0 { return "Due today" }
        if days == 1 { return "Due 1 day ago" }
        return "Due \(days) days ago"
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let course = item.course { Text(course) }
                        Text("·")
                        Text(dueText(from: item.dueDate))
                    }
                    .font(.caption)
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
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
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

enum TaskPriority: String, CaseIterable, Identifiable {
    case low, normal, high, critical
    var id: String { rawValue }
}

/// Shared planner preferences for Omodoro linking and related behaviors.
final class PlannerSettings: ObservableObject {
    @Published var isOmodoroLinkedForToday: Bool = false
}

/// Timer integration model; shared queue of Omodoro-linked blocks for the Timer page.
final class TimerPageModel: ObservableObject {
    static let shared = TimerPageModel()
    @Published var queuedOmodoroBlocks: [PlannedBlock] = []
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

struct PlannerPageView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var plannerSettings = PlannerSettings()
    @StateObject private var dayProgress = DayProgressModel()

    @State private var scope: PlannerScope = .today
    @State private var selectedDate: Date = Date()
    @State private var plannedBlocks: [PlannedBlock] = PlannerPageView.samplePlannedBlocks(for: Date())
    @State private var unscheduledTasks: [PlannerTask] = PlannerPageView.sampleUnscheduledTasks(for: Date())
    @State private var isRunningPlanner: Bool = false
    @State private var showTaskSheet: Bool = false
    @State private var editingTask: PlannerTask? = nil

    // new sheet state
    @State private var editingTaskDraft: PlannerTaskDraft? = nil

    private let cardCornerRadius: CGFloat = 26

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerBar
                        .padding(.top, 6)

                    HStack(alignment: .top, spacing: 18) {
                        timelineCard
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        rightColumn
                            .frame(width: 340, alignment: .top)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 24)
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
            // ensure roots settings are available and used if needed
        }
        .onDisappear {
            dayProgress.stopUpdating()
        }
        .environmentObject(plannerSettings)
    }
}

// MARK: - Header

private extension PlannerPageView {
    var headerBar: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { adjustDate(by: -1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.dayFormatter.string(from: selectedDate))
                        .font(.system(size: 18, weight: .semibold))
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { adjustDate(by: 1) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            Spacer()

            Picker("Scope", selection: $scope.animation(.spring(response: 0.3, dampingFraction: 0.85))) {
                Text("Today").tag(PlannerScope.today)
                Text("This Week").tag(PlannerScope.week)
                Text("All").tag(PlannerScope.all)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Spacer()

            HStack(spacing: 10) {
                Button {
                    showNewTaskSheet()
                } label: {
                    Label("New Task", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
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
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                        Text(isRunningPlanner ? "Planning..." : "Auto-Plan Day")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(height: 38)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRunningPlanner)
                .opacity(isRunningPlanner ? 0.85 : 1)
            }
        }
        .padding(.horizontal, 18)
    }

    var subtitleText: String {
        switch scope {
        case .today: return "AI-planned focus blocks"
        case .week: return "Week overview"
        case .all: return "All"
        }
    }

    func adjustDate(by offset: Int) {
        let component: Calendar.Component = .day
        let value = scope == .week ? offset * 7 : offset
        if let newDate = Calendar.current.date(byAdding: component, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

// MARK: - Timeline Card

private extension PlannerPageView {
    var timelineCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Planner Timeline")
                    .font(.headline)
                Spacer()
                // This pill toggles whether today's planner blocks link to Omodoro sessions in Timer.
                Button(action: toggleOmodoroLinked) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.checkmark")
                        Text("Omodoro linked")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(plannerSettings.isOmodoroLinkedForToday ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                            .opacity(plannerSettings.isOmodoroLinkedForToday ? 0.9 : 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .foregroundColor(plannerSettings.isOmodoroLinkedForToday ? .white : .primary)
                    .scaleEffect(plannerSettings.isOmodoroLinkedForToday ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(6...22, id: \.self) { hour in
                    timelineRow(for: hour)
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                if blocks.isEmpty {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .frame(height: 46)
                        .overlay(
                            HStack { Text("Free").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary); Spacer() }
                                .padding(.horizontal, 14)
                        )
                } else {
                    ForEach(blocks) { block in
                        PlannerBlockRow(block: block)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
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
                Text("Unscheduled Tasks")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    showNewTaskSheet()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if unscheduledTasks.isEmpty {
                Text("All tasks are scheduled. Nice.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
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
        .padding(16)
        .rootsCardBackground(radius: cardCornerRadius)
    }

    var overdueTasksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Overdue Tasks")
                    .font(.system(size: 16, weight: .semibold))
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
                    VStack(spacing: 8) {
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
                                               withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
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
        .padding(16)
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
            unscheduledTasks[idx].isCompleted = true
            unscheduledTasks.remove(at: idx)
            return
        }
        if let idx = plannedBlocks.firstIndex(where: { $0.id == item.id }) {
            plannedBlocks[idx].status = .completed
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

    /// Toggles whether today's planner blocks are Omodoro-linked and updates TimerPageModel queue.
    private func toggleOmodoroLinked() {
        plannerSettings.isOmodoroLinkedForToday.toggle()
        updateOmodoroLinking()
    }

    /// Updates the isOmodoroLinked flag for today's blocks and pushes them to the Timer queue.
    private func updateOmodoroLinking() {
        let calendar = Calendar.current
        plannedBlocks = plannedBlocks.map { block in
            if calendar.isDate(block.start, inSameDayAs: selectedDate) {
                var updated = block
                updated.isOmodoroLinked = plannerSettings.isOmodoroLinkedForToday
                return updated
            }
            return block
        }

        let linked = plannedBlocks.filter { $0.isOmodoroLinked && calendar.isDate($0.start, inSameDayAs: selectedDate) }
        TimerPageModel.shared.queuedOmodoroBlocks = linked.sorted(by: { $0.start < $1.start })
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
                    isOmodoroLinked: plannerSettings.isOmodoroLinkedForToday
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
        let calendar = Calendar.current
        let start1 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        let end1 = calendar.date(byAdding: .minute, value: 90, to: start1) ?? date
        let start2 = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: date) ?? date
        let end2 = calendar.date(byAdding: .minute, value: 60, to: start2) ?? date

        return [
            PlannedBlock(id: UUID(), taskId: nil, courseId: nil, title: "Read Chapter 5", course: "CS 240", start: start1, end: end1, isLocked: false, status: .inProgress, source: "Assignment", isOmodoroLinked: false),
            PlannedBlock(id: UUID(), taskId: nil, courseId: nil, title: "Study Group", course: "MA 231", start: start2, end: end2, isLocked: true, status: .upcoming, source: "Class", isOmodoroLinked: false)
        ]
    }

    static func sampleUnscheduledTasks(for date: Date) -> [PlannerTask] {
        let calendar = Calendar.current
        let due1 = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        return [
            PlannerTask(id: UUID(), courseId: nil, assignmentId: nil, title: "Draft lab report", course: "BIO 101", dueDate: due1, estimatedMinutes: 60, isLockedToDueDate: false, isScheduled: false, isCompleted: false)
        ]
    }

    static var sampleCourses: [CourseSummary] {
        [
            CourseSummary(id: UUID(), code: "MA 231", title: "Calculus II"),
            CourseSummary(id: UUID(), code: "CS 240", title: "Data Structures"),
            CourseSummary(id: UUID(), code: "BIO 101", title: "Biology")
        ]
    }
}

// MARK: - Block Row

struct PlannerBlockRow: View {
    var block: PlannedBlock

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
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(block.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if block.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private var metadataText: String {
        let courseText = block.course ?? "Course"
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
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(task.course ?? "Course")
                        Text("· ~\(task.estimatedMinutes) min")
                        Text("· Due \(PlannerTaskRow.dateFormatter.string(from: task.dueDate))")
                        if task.isLockedToDueDate {
                            Image(systemName: "lock.fill")
                        }
                    }
                    .font(.caption)
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

    @State private var linkToOmodoro: Bool = false

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
            title: isNew ? "New Task" : "Edit Task",
            subtitle: "Tasks are auto-scheduled into the Planner timeline and synced to Omodoro."
        ) {
            VStack(alignment: .leading, spacing: RootsSpacing.l) {
                taskSection
                courseSection
                timingSection
                optionsSection
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
            Text("Task").rootsSectionHeader()
            RootsFormRow(label: "Title") {
                TextField("Title", text: $draft.title)
                    .textFieldStyle(.roundedBorder)
            }
            RootsFormRow(label: "Priority") {
                Picker("", selection: $draft.priority) {
                    ForEach(TaskPriority.allCases) { p in
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
            Text("Course").rootsSectionHeader()
            RootsFormRow(label: "Course") {
                Picker("Course", selection: courseSelection) {
                    Text("None").tag(UUID?.none)
                    ForEach(availableCourses) { course in
                        Text("\(course.code) · \(course.title)").tag(Optional(course.id))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            RootsFormRow(label: "Assignment") {
                TextField("Assignment link (optional)", text: Binding(
                    get: { draft.assignmentID == nil ? "" : "Linked" },
                    set: { _ in /* hook later */ }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            Text("Timing").rootsSectionHeader()
            RootsFormRow(label: "Due date") {
                DatePicker("", selection: $draft.dueDate, in: Date()..., displayedComponents: .date)
                    .labelsHidden()
            }
            RootsFormRow(label: "Focus estimate") {
                Stepper(value: $draft.estimatedMinutes, in: 15...480, step: 15) {
                    Text("\(draft.estimatedMinutes) min")
                }
                .frame(maxWidth: 220, alignment: .leading)
            }
            RootsFormRow(label: "") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Lock to exact due date", isOn: $draft.lockToDueDate)
                    Text("When locked, the AI planner schedules this block only on the due date.")
                        .rootsCaption()
                }
            }
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            Text("Focus options").rootsSectionHeader()
            RootsFormRow(label: "Mode") {
                Toggle("Link to Omodoro focus sessions", isOn: $linkToOmodoro)
                    .toggleStyle(.switch)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
            Button(isNew ? "Create" : "Save") {
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
