#if os(iOS)
import SwiftUI
import EventKit

struct IOSPlannerView: View {
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var plannerStore: PlannerStore
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var filterState: IOSFilterState
    @EnvironmentObject private var toastRouter: IOSToastRouter
    @EnvironmentObject private var settings: AppSettingsModel
    @State private var selectedDate = Date()
    @State private var showingPlanHelp = false
    @State private var isEditing = false
    @State private var editingBlock: StoredScheduledSession? = nil
    @State private var showingBlockEditor = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                planHeader
                IOSFilterHeaderView(
                    coursesStore: coursesStore,
                    filterState: filterState
                )
                scheduleSection
                overflowSection
                unscheduledSection
            }
            .padding(20)
        }
        .background(DesignSystem.Colors.appBackground)
        .modifier(IOSNavigationChrome(title: "Planner") {
            Button {
                generatePlan()
            } label: {
                Image(systemName: "sparkles")
            }
            .accessibilityLabel("Generate plan")
        })
        .sheet(isPresented: $showingPlanHelp) {
            IOSPlanHelpView()
        }
        .sheet(item: $editingBlock) { block in
            IOSBlockEditorView(
                block: block,
                minHour: settings.workdayStartHourStorage,
                maxHour: settings.workdayEndHourStorage,
                onSave: { updated in
                    if canPlaceBlock(updated, excluding: block.id) {
                        plannerStore.updateScheduledSession(updated)
                        toastRouter.show("Block updated")
                    } else {
                        toastRouter.show("Time conflict")
                    }
                }
            )
        }
    }

    private var planHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
                .font(.caption.weight(.semibold))
                Button("How it works") {
                    showingPlanHelp = true
                }
                .font(.caption.weight(.semibold))
            }
            Text(formattedDate(selectedDate))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                generatePlan()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Generate Plan")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Schedule", subtitle: "Time blocks")
            if scheduledToday.isEmpty {
                IOSInlineEmptyState(title: "No blocks scheduled", subtitle: "Generate a plan to fill today.")
            } else {
                ForEach(scheduledToday) { session in
                    IOSPlannerBlockRow(
                        session: session,
                        isEditing: isEditing,
                        snapMinutes: 15,
                        onEdit: {
                            editingBlock = session
                        },
                        onMove: { moved in
                            if canPlaceBlock(moved, excluding: session.id) {
                                plannerStore.updateScheduledSession(moved)
                            } else {
                                toastRouter.show("Time conflict")
                            }
                        }
                    )
                }
            }
        }
    }

    private var overflowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Overflow", subtitle: "Not scheduled yet")
            if plannerStore.overflow.isEmpty {
                IOSInlineEmptyState(title: "All sessions placed", subtitle: "Nothing waiting in overflow.")
            } else {
                ForEach(plannerStore.overflow) { session in
                    IOSInfoRow(
                        title: session.title,
                        subtitle: "Due \(formattedDate(session.dueDate)) · \(session.estimatedMinutes) min",
                        systemImage: "clock.badge.exclamationmark"
                    )
                }
            }
        }
    }

    private var unscheduledSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Unscheduled", subtitle: "Needs attention")
            if tasksMissingDates.isEmpty {
                IOSInlineEmptyState(title: "All tasks have dates", subtitle: "Add due dates to keep planning accurate.")
            } else {
                ForEach(tasksMissingDates, id: \.id) { task in
                    IOSInfoRow(
                        title: task.title,
                        subtitle: "Add a due date",
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
        }
    }

    private var scheduledToday: [StoredScheduledSession] {
        let calendar = Calendar.current
        return plannerStore.scheduled
            .filter { calendar.isDate($0.start, inSameDayAs: selectedDate) }
            .sorted { $0.start < $1.start }
    }

    private var tasksMissingDates: [AppTask] {
        filteredTasks.filter { !$0.isCompleted && $0.due == nil }
    }

    private func generatePlan() {
        let assignments = assignmentsForPlanning()
        guard !assignments.isEmpty else { return }
        let settings = StudyPlanSettings()
        let sessions = assignments.flatMap { PlannerEngine.generateSessions(for: $0, settings: settings) }
        let result = PlannerEngine.scheduleSessions(sessions, settings: settings, energyProfile: defaultEnergyProfile())
        plannerStore.persist(scheduled: result.scheduled, overflow: result.overflow)
    }

    private func assignmentsForPlanning() -> [Assignment] {
        let today = Calendar.current.startOfDay(for: Date())
        return filteredTasks.compactMap { task in
            guard !task.isCompleted, let due = task.due else { return nil }
            if due < today { return nil }
            return Assignment(
                id: task.id,
                courseId: task.courseId,
                title: task.title,
                dueDate: due,
                estimatedMinutes: task.estimatedMinutes,
                weightPercent: nil,
                category: category(for: task),
                urgency: urgency(for: task.importance),
                isLockedToDueDate: task.locked,
                plan: []
            )
        }
    }

    private func category(for task: AppTask) -> AssignmentCategory {
        switch task.category {
        case .exam: return .exam
        case .quiz: return .quiz
        case .practiceHomework: return .practiceHomework
        case .reading: return .reading
        case .review: return .review
        case .project: return .project
        }
    }

    private func urgency(for value: Double) -> AssignmentUrgency {
        switch value {
        case ..<0.3: return .low
        case ..<0.6: return .medium
        case ..<0.85: return .high
        default: return .critical
        }
    }

    private func defaultEnergyProfile() -> [Int: Double] {
        [
            9: 0.55, 10: 0.65, 11: 0.7, 12: 0.6,
            13: 0.5, 14: 0.55, 15: 0.65, 16: 0.7,
            17: 0.6, 18: 0.5, 19: 0.45, 20: 0.4
        ]
    }

    private var filteredTasks: [AppTask] {
        let courseLookup = coursesStore.courses
        return assignmentsStore.tasks.filter { task in
            guard let courseId = task.courseId else {
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
            return true
        }
    }

    private func canPlaceBlock(_ updated: StoredScheduledSession, excluding id: UUID) -> Bool {
        let calendar = Calendar.current
        let sameDay = plannerStore.scheduled.filter { calendar.isDate($0.start, inSameDayAs: updated.start) && $0.id != id }
        let hasOverlap = sameDay.contains { candidate in
            max(candidate.start, updated.start) < min(candidate.end, updated.end)
        }
        guard !hasOverlap else { return false }
        let startHour = calendar.component(.hour, from: updated.start)
        let endHour = calendar.component(.hour, from: updated.end)
        let endMinute = calendar.component(.minute, from: updated.end)
        if startHour < settings.workdayStartHourStorage { return false }
        if endHour > settings.workdayEndHourStorage { return false }
        if endHour == settings.workdayEndHourStorage && endMinute > 0 { return false }
        return true
    }

    private func timeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: start))-\(formatter.string(from: end))"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct IOSAssignmentsView: View {
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var filterState: IOSFilterState
    @State private var showingEditor = false
    @State private var editingTask: AppTask? = nil

    var body: some View {
        List {
            Section {
                IOSFilterHeaderView(
                    coursesStore: coursesStore,
                    filterState: filterState
                )
            }
            if assignmentsStore.tasks.isEmpty {
                IOSInlineEmptyState(
                    title: "No tasks yet",
                    subtitle: "Capture tasks and due dates here."
                )
            } else {
                ForEach(sortedTasks, id: \.id) { task in
                    HStack(spacing: 12) {
                        Button {
                            toggleCompletion(task)
                        } label: {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isCompleted ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.body.weight(.medium))
                            if let due = task.due {
                                Text("Due \(formattedDate(due))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No due date")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingTask = task
                        showingEditor = true
                    }
                }
                .onDelete(perform: deleteTasks)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.appBackground)
        .modifier(IOSNavigationChrome(title: "Tasks") {
            Button {
                editingTask = nil
                showingEditor = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add task")
        })
        .sheet(isPresented: $showingEditor) {
            IOSTaskEditorView(
                task: editingTask,
                courses: coursesStore.activeCourses,
                itemLabel: "Task",
                onSave: upsertTask
            )
        }
    }

    private func toggleCompletion(_ task: AppTask) {
        var updated = task
        updated.isCompleted.toggle()
        assignmentsStore.updateTask(updated)
    }

    private var sortedTasks: [AppTask] {
        filteredTasks.sorted { lhs, rhs in
            switch (lhs.due, rhs.due) {
            case (nil, nil): return lhs.title < rhs.title
            case (nil, _): return false
            case (_, nil): return true
            case (let l?, let r?): return l < r
            }
        }
    }

    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            let task = sortedTasks[index]
            assignmentsStore.removeTask(id: task.id)
        }
    }

    private var filteredTasks: [AppTask] {
        let courseLookup = coursesStore.courses
        return assignmentsStore.tasks.filter { task in
            guard let courseId = task.courseId else {
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
            return true
        }
    }

    private func upsertTask(_ draft: IOSTaskEditorView.TaskDraft) {
        let task = draft.makeTask(existing: editingTask)
        if editingTask == nil {
            assignmentsStore.addTask(task)
        } else {
            assignmentsStore.updateTask(task)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct IOSCoursesView: View {
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var filterState: IOSFilterState
    @State private var showingCourseEditor = false
    @State private var showingSemesterEditor = false

    var body: some View {
        List {
            Section {
                IOSFilterHeaderView(
                    coursesStore: coursesStore,
                    filterState: filterState
                )
            }
            if coursesStore.activeSemesters.isEmpty {
                IOSInlineEmptyState(
                    title: "No semester yet",
                    subtitle: "Create a semester to organize courses."
                )
                Button("Create Semester") {
                    showingSemesterEditor = true
                }
            } else if coursesStore.activeCourses.isEmpty {
                IOSInlineEmptyState(
                    title: "No active courses",
                    subtitle: "Add a course to filter tasks and planner blocks."
                )
                Button("Add Course") {
                    showingCourseEditor = true
                }
            } else {
                Section("Active Courses") {
                ForEach(filteredCourses) { course in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(course.code.isEmpty ? course.title : course.code)
                            .font(.body.weight(.medium))
                        if !course.code.isEmpty {
                            Text(course.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.appBackground)
        .modifier(IOSNavigationChrome(title: "Courses") {
            Button {
                showingCourseEditor = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add course")
        })
        .sheet(isPresented: $showingCourseEditor) {
            IOSCourseEditorView(
                semesters: coursesStore.activeSemesters,
                currentSemesterId: filterState.selectedSemesterId ?? coursesStore.currentSemesterId,
                onSave: addCourse
            )
        }
        .sheet(isPresented: $showingSemesterEditor) {
            IOSSemesterEditorView(onSave: addSemester)
        }
    }

    private func addCourse(_ draft: IOSCourseEditorView.CourseDraft) {
        guard let semester = coursesStore.activeSemesters.first(where: { $0.id == draft.semesterId }) else { return }
        coursesStore.addCourse(title: draft.title, code: draft.code, to: semester)
    }

    private func addSemester(_ draft: IOSSemesterEditorView.SemesterDraft) {
        let semester = Semester(
            startDate: draft.startDate,
            endDate: draft.endDate,
            isCurrent: true,
            educationLevel: draft.educationLevel,
            semesterTerm: draft.semesterTerm
        )
        coursesStore.addSemester(semester)
    }

    private var filteredCourses: [Course] {
        let base = coursesStore.activeCourses
        if let semesterId = filterState.selectedSemesterId {
            return base.filter { $0.semesterId == semesterId }
        }
        if let courseId = filterState.selectedCourseId {
            return base.filter { $0.id == courseId }
        }
        return base
    }
}

struct IOSCalendarView: View {
    @EnvironmentObject private var deviceCalendar: DeviceCalendarManager

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if !deviceCalendar.isAuthorized {
                    IOSInfoCard(
                        title: "Connect Calendar",
                        subtitle: "Access events on iOS",
                        systemImage: "calendar.badge.exclamationmark",
                        detail: "Enable calendar access to see your schedule."
                    )
                } else if upcomingEvents.isEmpty {
                    IOSInfoCard(
                        title: "Nothing scheduled",
                        subtitle: "Your calendar is clear",
                        systemImage: "calendar",
                        detail: "Add events quickly from the plus menu."
                    )
                } else {
                    ForEach(upcomingEvents.prefix(8), id: \.eventIdentifier) { event in
                        IOSInfoCard(
                            title: event.title,
                            subtitle: timeRange(for: event),
                            systemImage: "calendar",
                            detail: event.location ?? "No location"
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(DesignSystem.Colors.appBackground)
        .modifier(IOSNavigationChrome(title: "Calendar"))
        .task {
            await deviceCalendar.bootstrapOnLaunch()
        }
    }

    private var upcomingEvents: [EKEvent] {
        let now = Date()
        return deviceCalendar.events
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
    }

    private func timeRange(for event: EKEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) • \(formatter.string(from: event.endDate))"
    }
}

struct IOSPracticeView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                IOSInfoCard(
                    title: "Practice Sessions",
                    subtitle: "Warmups, drills, reviews",
                    systemImage: "list.clipboard",
                    detail: "Build short, focused practice loops."
                )
                IOSInfoCard(
                    title: "Track Progress",
                    subtitle: "Stay consistent",
                    systemImage: "chart.line.uptrend.xyaxis",
                    detail: "Log repetitions and streaks over time."
                )
            }
            .padding(20)
        }
        .background(DesignSystem.Colors.appBackground)
        .modifier(IOSNavigationChrome(title: "Practice"))
    }
}

struct IOSSettingsView: View {
    @EnvironmentObject private var settings: AppSettingsModel

    var body: some View {
        Form {
            Section("Tab Bar Pages") {
                ForEach(IOSTabConfiguration.tabCandidates, id: \.self) { tab in
                    Toggle(isOn: Binding(get: {
                        settings.visibleTabs.contains(tab)
                    }, set: { newValue in
                        updateTabs(tab, isVisible: newValue)
                    })) {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                }

                Button("Restore Defaults") {
                    settings.visibleTabs = IOSTabConfiguration.defaultTabs
                    settings.tabOrder = IOSTabConfiguration.defaultTabs
                    settings.save()
                }
            }
        }
        .modifier(IOSNavigationChrome(title: "Settings"))
    }

    private func updateTabs(_ tab: RootTab, isVisible: Bool) {
        var visible = settings.visibleTabs
        var order = settings.tabOrder

        if isVisible {
            if !visible.contains(tab) { visible.append(tab) }
            if !order.contains(tab) { order.append(tab) }
        } else {
            visible.removeAll { $0 == tab }
            order.removeAll { $0 == tab }
        }

        settings.visibleTabs = visible
        settings.tabOrder = order
        settings.save()
    }
}

struct IOSPlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .modifier(IOSNavigationChrome(title: title))
    }
}

private struct IOSInfoCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.headline)
            }
            Text(subtitle)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

private struct IOSInlineEmptyState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

private struct IOSInfoRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

struct IOSTaskEditorView: View {
    struct TaskDraft {
        var title: String = ""
        var hasDueDate: Bool = true
        var dueDate: Date = Date()
        var estimatedMinutes: Int = 60
        var courseId: UUID? = nil
        var type: TaskType = .practiceHomework
        var importance: Double = 0.6
        var difficulty: Double = 0.6

        init(task: AppTask? = nil) {
            guard let task else { return }
            title = task.title
            hasDueDate = task.due != nil
            dueDate = task.due ?? dueDate
            estimatedMinutes = task.estimatedMinutes
            courseId = task.courseId
            type = task.type
            importance = task.importance
            difficulty = task.difficulty
        }

        func makeTask(existing: AppTask?) -> AppTask {
            AppTask(
                id: existing?.id ?? UUID(),
                title: title,
                courseId: courseId,
                due: hasDueDate ? dueDate : nil,
                estimatedMinutes: estimatedMinutes,
                minBlockMinutes: 15,
                maxBlockMinutes: 120,
                difficulty: difficulty,
                importance: importance,
                type: type,
                locked: false,
                attachments: [],
                isCompleted: existing?.isCompleted ?? false,
                category: type
            )
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TaskDraft

    let task: AppTask?
    let courses: [Course]
    let defaults: TaskDraft
    let itemLabel: String
    let onSave: (TaskDraft) -> Void

    init(task: AppTask?, courses: [Course], defaults: TaskDraft = TaskDraft(), itemLabel: String = "Assignment", onSave: @escaping (TaskDraft) -> Void) {
        self.task = task
        self.courses = courses
        self.defaults = defaults
        self.itemLabel = itemLabel
        self.onSave = onSave
        _draft = State(initialValue: TaskDraft(task: task))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Title", text: $draft.title)
                    Picker("Type", selection: $draft.type) {
                        Text("Homework").tag(TaskType.practiceHomework)
                        Text("Quiz").tag(TaskType.quiz)
                        Text("Exam").tag(TaskType.exam)
                        Text("Reading").tag(TaskType.reading)
                        Text("Review").tag(TaskType.review)
                        Text("Project").tag(TaskType.project)
                    }
                    Picker("Course", selection: $draft.courseId) {
                        Text("No Course").tag(UUID?.none)
                        ForEach(courses) { course in
                            Text(course.code.isEmpty ? course.title : course.code)
                                .tag(Optional(course.id))
                        }
                    }
                }

                Section("Schedule") {
                    Toggle("Has Due Date", isOn: $draft.hasDueDate)
                    if draft.hasDueDate {
                        DatePicker("Due", selection: $draft.dueDate, displayedComponents: .date)
                    }
                    Stepper("Estimated Minutes: \(draft.estimatedMinutes)", value: $draft.estimatedMinutes, in: 15...360, step: 15)
                }

                Section("Priority") {
                    Slider(value: $draft.importance, in: 0...1) {
                        Text("Importance")
                    }
                    Slider(value: $draft.difficulty, in: 0...1) {
                        Text("Difficulty")
                    }
                }
            }
            .navigationTitle(task == nil ? "New \(itemLabel)" : "Edit \(itemLabel)")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if task == nil {
                    draft.title = defaults.title
                    draft.courseId = defaults.courseId
                    draft.dueDate = defaults.dueDate
                    draft.type = defaults.type
                }
            }
        }
    }
}

struct IOSCourseEditorView: View {
    struct CourseDraft {
        var title: String = ""
        var code: String = ""
        var semesterId: UUID?
    }

    @Environment(\.dismiss) private var dismiss
    @State private var draft = CourseDraft()

    let semesters: [Semester]
    let currentSemesterId: UUID?
    let defaults: CourseDraft
    let onSave: (CourseDraft) -> Void

    init(semesters: [Semester], currentSemesterId: UUID?, defaults: CourseDraft = CourseDraft(), onSave: @escaping (CourseDraft) -> Void) {
        self.semesters = semesters
        self.currentSemesterId = currentSemesterId
        self.defaults = defaults
        self.onSave = onSave
        _draft = State(initialValue: defaults)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Course") {
                    TextField("Title", text: $draft.title)
                    TextField("Code", text: $draft.code)
                }

                Section("Semester") {
                    Picker("Semester", selection: $draft.semesterId) {
                        ForEach(semesters) { semester in
                            Text(semester.name)
                                .tag(Optional(semester.id))
                        }
                    }
                }
            }
            .navigationTitle("New Course")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if draft.semesterId == nil {
                            draft.semesterId = currentSemesterId ?? semesters.first?.id
                        }
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || semesters.isEmpty)
                }
            }
            .onAppear {
                if draft.semesterId == nil {
                    draft.semesterId = currentSemesterId ?? semesters.first?.id
                }
            }
        }
    }
}

struct IOSSemesterEditorView: View {
    struct SemesterDraft {
        var startDate: Date = Date()
        var endDate: Date = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
        var educationLevel: EducationLevel = .college
        var semesterTerm: SemesterType = .fall
    }

    @Environment(\.dismiss) private var dismiss
    @State private var draft = SemesterDraft()

    let onSave: (SemesterDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Dates") {
                    DatePicker("Start", selection: $draft.startDate, displayedComponents: .date)
                    DatePicker("End", selection: $draft.endDate, displayedComponents: .date)
                }

                Section("Details") {
                    Picker("Education Level", selection: $draft.educationLevel) {
                        ForEach(EducationLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    Picker("Term", selection: $draft.semesterTerm) {
                        ForEach(SemesterType.allCases) { term in
                            Text(term.rawValue).tag(term)
                        }
                    }
                }
            }
            .navigationTitle("New Semester")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.endDate <= draft.startDate)
                }
            }
        }
    }
}

private struct IOSPlanHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Planner uses your assignment due dates to build a schedule of study blocks.")
                    Text("Generate Plan to create time blocks for today and the next few days.")
                    Text("Tasks without a due date stay in the Unscheduled section.")
                }
                .padding(20)
            }
            .navigationTitle("How Planner Works")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct IOSPlannerBlockRow: View {
    let session: StoredScheduledSession
    let isEditing: Bool
    let snapMinutes: Int
    let onEdit: () -> Void
    let onMove: (StoredScheduledSession) -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        IOSInfoRow(
            title: session.title,
            subtitle: "\(timeRange(start: session.start, end: session.end)) · \(session.estimatedMinutes) min",
            systemImage: session.isUserEdited ? "pencil.and.outline" : "calendar.badge.clock"
        )
        .offset(y: dragOffset.height)
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    guard isEditing else { return }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    guard isEditing else { return }
                    let deltaMinutes = snappedMinutes(for: value.translation.height)
                    dragOffset = .zero
                    if deltaMinutes != 0 {
                        let updated = rescheduled(session: session, deltaMinutes: deltaMinutes)
                        onMove(updated)
                    }
                }
        )
        .onTapGesture {
            onEdit()
        }
    }

    private func snappedMinutes(for deltaHeight: CGFloat) -> Int {
        let pointsPerStep: CGFloat = 28
        let steps = Int((deltaHeight / pointsPerStep).rounded())
        return steps * snapMinutes
    }

    private func rescheduled(session: StoredScheduledSession, deltaMinutes: Int) -> StoredScheduledSession {
        let start = Calendar.current.date(byAdding: .minute, value: deltaMinutes, to: session.start) ?? session.start
        let end = Calendar.current.date(byAdding: .minute, value: deltaMinutes, to: session.end) ?? session.end
        return StoredScheduledSession(
            id: session.id,
            assignmentId: session.assignmentId,
            title: session.title,
            dueDate: session.dueDate,
            estimatedMinutes: session.estimatedMinutes,
            isLockedToDueDate: session.isLockedToDueDate,
            category: session.category,
            start: start,
            end: end,
            type: session.type,
            isLocked: session.isLocked,
            isUserEdited: true
        )
    }

    private func timeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: start))-\(formatter.string(from: end))"
    }
}

private struct IOSBlockEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var start: Date
    @State private var durationMinutes: Int
    @State private var isLocked: Bool

    let block: StoredScheduledSession
    let minHour: Int
    let maxHour: Int
    let onSave: (StoredScheduledSession) -> Void

    init(block: StoredScheduledSession, minHour: Int, maxHour: Int, onSave: @escaping (StoredScheduledSession) -> Void) {
        self.block = block
        self.minHour = minHour
        self.maxHour = maxHour
        self.onSave = onSave
        _title = State(initialValue: block.title)
        _start = State(initialValue: block.start)
        _durationMinutes = State(initialValue: max(15, block.estimatedMinutes))
        _isLocked = State(initialValue: block.isLocked)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                }
                Section("Timing") {
                    DatePicker("Start", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 15...240, step: 15)
                    Toggle("Locked", isOn: $isLocked)
                }
                Section("Workday") {
                    Text("Allowed hours: \(minHour):00–\(maxHour):00")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Block")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let end = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: start) ?? block.end
                        let updated = StoredScheduledSession(
                            id: block.id,
                            assignmentId: block.assignmentId,
                            title: title,
                            dueDate: block.dueDate,
                            estimatedMinutes: durationMinutes,
                            isLockedToDueDate: block.isLockedToDueDate,
                            category: block.category,
                            start: start,
                            end: end,
                            type: block.type,
                            isLocked: isLocked,
                            isUserEdited: true
                        )
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct IOSFilterHeaderView: View {
    let coursesStore: CoursesStore
    let filterState: IOSFilterState

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                Button("All Semesters") {
                    filterState.setSemester(nil, availableCourseIds: availableCourseIds(for: nil))
                }
                ForEach(coursesStore.activeSemesters) { semester in
                    Button(semester.name) {
                        filterState.setSemester(semester.id, availableCourseIds: availableCourseIds(for: semester.id))
                    }
                }
            } label: {
                filterChip(label: semesterLabel, systemImage: "calendar")
            }

            Menu {
                Button("All Courses") {
                    filterState.selectedCourseId = nil
                }
                ForEach(availableCourses) { course in
                    Button(course.code.isEmpty ? course.title : course.code) {
                        filterState.selectedCourseId = course.id
                    }
                }
            } label: {
                filterChip(label: courseLabel, systemImage: "book.closed")
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var semesterLabel: String {
        guard let id = filterState.selectedSemesterId,
              let semester = coursesStore.activeSemesters.first(where: { $0.id == id }) else {
            return "All Semesters"
        }
        return semester.name
    }

    private var courseLabel: String {
        guard let id = filterState.selectedCourseId,
              let course = coursesStore.courses.first(where: { $0.id == id }) else {
            return "All Courses"
        }
        return course.code.isEmpty ? course.title : course.code
    }

    private var availableCourses: [Course] {
        if let semesterId = filterState.selectedSemesterId {
            return coursesStore.activeCourses.filter { $0.semesterId == semesterId }
        }
        return coursesStore.activeCourses
    }

    private func availableCourseIds(for semesterId: UUID?) -> Set<UUID> {
        let courses = semesterId == nil
            ? coursesStore.activeCourses
            : coursesStore.activeCourses.filter { $0.semesterId == semesterId }
        return Set(courses.map { $0.id })
    }

    private func filterChip(label: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(uiColor: .systemBackground))
        )
    }
}
#endif
