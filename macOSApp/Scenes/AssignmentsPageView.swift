#if os(macOS)
import SwiftUI
import Combine

// MARK: - Models







enum EffortBias: String, Codable {
    case shortBursts
    case mediumBlocks
    case longBlocks
}

struct CategoryEffortProfile: Codable, Equatable {
    let baseMinutes: Int
    let minSessions: Int
    let spreadDaysBeforeDue: Int
    let sessionBias: EffortBias
}

extension AssignmentCategory {
    var effortProfile: CategoryEffortProfile {
        switch self {
        case .project:
            return .init(baseMinutes: 240, minSessions: 4, spreadDaysBeforeDue: 7, sessionBias: .longBlocks)
        case .exam:
            return .init(baseMinutes: 180, minSessions: 3, spreadDaysBeforeDue: 5, sessionBias: .mediumBlocks)
        case .quiz:
            return .init(baseMinutes: 60, minSessions: 2, spreadDaysBeforeDue: 2, sessionBias: .shortBursts)
        case .homework, .practiceHomework:
            return .init(baseMinutes: 60, minSessions: 1, spreadDaysBeforeDue: 2, sessionBias: .mediumBlocks)
        case .reading:
            return .init(baseMinutes: 45, minSessions: 1, spreadDaysBeforeDue: 1, sessionBias: .shortBursts)
        case .review:
            return .init(baseMinutes: 90, minSessions: 2, spreadDaysBeforeDue: 3, sessionBias: .shortBursts)
        }
    }
}

extension Assignment {
    static func defaultPlan(for category: AssignmentCategory, due: Date, totalMinutes: Int) -> [PlanStepStub] {
        let cal = Calendar.current
        func dayOffset(_ days: Int) -> Date {
            cal.date(byAdding: .day, value: -days, to: due) ?? due
        }

        let minutes = max(totalMinutes, category.effortProfile.baseMinutes)

        switch category {
        case .project:
            let chunk = max(60, minutes / 4)
            return [
                PlanStepStub(title: NSLocalizedString("assignments.plan.research_gather", comment: "Assignment plan step"), expectedMinutes: chunk),
                PlanStepStub(title: NSLocalizedString("assignments.plan.outline_plan", comment: "Assignment plan step"), expectedMinutes: chunk),
                PlanStepStub(title: NSLocalizedString("assignments.plan.draft", comment: "Assignment plan step"), expectedMinutes: chunk),
                PlanStepStub(title: NSLocalizedString("assignments.plan.polish_submit", comment: "Assignment plan step"), expectedMinutes: chunk)
            ]
        case .exam:
            let chunk = max(60, minutes / 3)
            return [
                PlanStepStub(title: NSLocalizedString("assignments.plan.review_notes", comment: "Assignment plan step"), expectedMinutes: chunk),
                PlanStepStub(title: NSLocalizedString("assignments.plan.practice_problems", comment: "Assignment plan step"), expectedMinutes: chunk),
                PlanStepStub(title: NSLocalizedString("assignments.plan.mock_test", comment: "Assignment plan step"), expectedMinutes: chunk)
            ]
        case .quiz:
            let chunk = max(45, minutes / 2)
            return [
                PlanStepStub(title: NSLocalizedString("assignments.plan.skim_outline", comment: "Assignment plan step"), expectedMinutes: chunk),
                PlanStepStub(title: NSLocalizedString("assignments.plan.practice_set", comment: "Assignment plan step"), expectedMinutes: chunk)
            ]
        case .homework, .practiceHomework:
            let chunk = max(45, minutes)
            return [
                PlanStepStub(title: NSLocalizedString("assignments.plan.solve_set", comment: "Assignment plan step"), expectedMinutes: chunk)
            ]
        case .reading:
            return [
                PlanStepStub(title: NSLocalizedString("assignments.plan.read_annotate", comment: "Assignment plan step"), expectedMinutes: max(30, minutes / 2)),
                PlanStepStub(title: NSLocalizedString("assignments.plan.summarize", comment: "Assignment plan step"), expectedMinutes: max(20, minutes / 2))
            ]
        case .review:
            return [
                PlanStepStub(title: NSLocalizedString("assignments.plan.review_key_points", comment: "Assignment plan step"), expectedMinutes: max(30, minutes / 2)),
                PlanStepStub(title: NSLocalizedString("assignments.plan.flashcards_drill", comment: "Assignment plan step"), expectedMinutes: max(20, minutes / 2))
            ]
        }
    }
}

fileprivate func suggestedSessionLength(_ bias: EffortBias) -> Int {
    switch bias {
    case .shortBursts:  return 30
    case .mediumBlocks: return 60
    case .longBlocks:   return 90
    }
}



enum AssignmentSegment: String, CaseIterable, Identifiable {
    case today, upcoming, all, completed
    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return NSLocalizedString("assignments.segment.today", comment: "Today segment")
        case .upcoming: return NSLocalizedString("assignments.segment.upcoming", comment: "Upcoming segment")
        case .all: return NSLocalizedString("assignments.segment.all", comment: "All segment")
        case .completed: return NSLocalizedString("assignments.segment.completed", comment: "Completed segment")
        }
    }
}

enum AssignmentSortOption: String, CaseIterable, Identifiable {
    case byDueDate, byCourse, byUrgency
    var id: String { rawValue }

    var label: String {
        switch self {
        case .byDueDate: return NSLocalizedString("assignments.sort.due_date", comment: "Sort by due date")
        case .byCourse: return NSLocalizedString("assignments.sort.course", comment: "Sort by course")
        case .byUrgency: return NSLocalizedString("assignments.sort.urgency", comment: "Sort by urgency")
        }
    }
}

// MARK: - Root View

struct AssignmentsPageView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var appModel: AppModel

    @State private var assignments: [Assignment] = []
    @State private var courseDeletedCancellable: AnyCancellable? = nil
    @State private var selectedSegment: AssignmentSegment = .all
    @State private var selectedAssignment: Assignment? = nil
    @State private var searchText: String = ""
    @State private var showNewAssignmentSheet: Bool = false
    @State private var editingAssignment: Assignment? = nil
    @State private var sortOption: AssignmentSortOption = .byDueDate
    @State private var filterStatus: AssignmentStatus? = nil
    @State private var filterCourse: String? = nil
    @State private var showFilterPopover: Bool = false
    // Drag selection state
    @State private var selectionStart: CGPoint?
    @State private var selectionRect: CGRect?
    @State private var selectionMenuLocation: CGPoint?
    @State private var selectedIDs: Set<UUID> = []
    @State private var assignmentFrames: [UUID: CGRect] = [:]
    @State private var clipboard: [Assignment] = []

    private let cardCorner: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let columnWidth = max(width / 5, 220)

            VStack(spacing: RootsSpacing.l) {
                topControls

                HStack(alignment: .top, spacing: 16) {
                    leftSummaryColumn
                        .frame(width: columnWidth)

                    assignmentListCard
                        .coordinateSpace(name: "assignmentsArea")
                        .gesture(dragSelectionGesture())
                        .overlay(selectionOverlay)

                    detailPanel
                        .frame(width: columnWidth + 60)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(RootsSpacing.l)
            .rootsSystemBackground()
        }
        .sheet(isPresented: $showNewAssignmentSheet) {
            AssignmentEditorSheet(assignment: editingAssignment) { newAssignment in
                upsertAssignment(newAssignment)
            }
        }
        .onChange(of: appModel.requestedAssignmentDueDate) { _, dueDate in
            guard let dueDate else { return }
            focusAssignment(closestTo: dueDate)
            appModel.requestedAssignmentDueDate = nil
        }
        .onAppear {
            // subscribe to course deletions
            courseDeletedCancellable = CoursesStore.courseDeletedPublisher
                .receive(on: DispatchQueue.main)
                .sink { deletedId in
                    assignmentsStore.tasks.removeAll { $0.courseId == deletedId }
                    if let fc = filterCourse, UUID(uuidString: fc) == deletedId {
                        filterCourse = nil
                    }
                    if let sel = selectedAssignment, sel.courseId == deletedId {
                        selectedAssignment = nil
                    }
                }
        }
    }

    // MARK: Top Controls

    private var topControls: some View {
        HStack(spacing: RootsSpacing.m) {
            Picker(NSLocalizedString("assignments.segment.today", comment: "Segment picker"), selection: $selectedSegment.animation(DesignSystem.Motion.standardSpring)) {
                ForEach(AssignmentSegment.allCases) { seg in
                    Text(seg.label).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 340)

            Spacer()

            HStack(spacing: RootsSpacing.s) {
                Picker(NSLocalizedString("assignments.sort.due_date", comment: "Sort picker"), selection: $sortOption) {
                    ForEach(AssignmentSortOption.allCases) { opt in
                        Text(opt.label).tag(opt)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    showFilterPopover.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showFilterPopover, arrowEdge: .top) {
                    filterPopover
                        .padding(DesignSystem.Layout.padding.card)
                        .frame(width: 260)
                }
            }

            Button {
                editingAssignment = nil
                showNewAssignmentSheet = true
            } label: {
                Label(NSLocalizedString("assignments.action.new", comment: "New button"), systemImage: "plus")
                    .font(DesignSystem.Typography.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: NSColor.alternatingContentBackgroundColors[0]).opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                autoPlanSelectedAssignments()
            } label: {
                Text(NSLocalizedString("assignments.action.plan_day", comment: "Plan day button"))
                    .font(DesignSystem.Typography.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(height: 36)
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)
            .controlSize(.regular)
        }
    }

    private var filterPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("assignments.action.filters", comment: "Filters label"))
                .font(DesignSystem.Typography.subHeader)
            Divider()
            Picker(NSLocalizedString("assignments.filter.status", comment: "Status filter"), selection: Binding(
                get: { filterStatus },
                set: { filterStatus = $0 }
            )) {
                Text(NSLocalizedString("assignments.filter.any", comment: "Any filter option")).tag(AssignmentStatus?.none)
                ForEach(AssignmentStatus.allCases) { status in
                    Text(status.label).tag(AssignmentStatus?.some(status))
                }
            }
            .pickerStyle(.menu)

            Picker(NSLocalizedString("assignments.sort.course", comment: "Course filter"), selection: Binding(
                get: { filterCourse },
                set: { filterCourse = $0 }
            )) {
                Text(NSLocalizedString("assignments.filter.all_courses", comment: "All courses filter")).tag(String?.none)
                ForEach(uniqueCourses, id: \.self) { course in
                    Text(course).tag(String?.some(course))
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: Columns

    private var leftSummaryColumn: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                TodaySummaryCard(assignments: assignments, selectedSegment: $selectedSegment)
                UpcomingCountCard(assignments: assignments)
                MissedCountCard(assignments: assignments)
                ByCourseSummaryCard(assignments: assignments) { course in
                    filterCourse = course
                }
                LoadTimelineCard(assignments: assignments)
            }
            .padding(4)
        }
        .rootsCardBackground(radius: cardCorner)
    }

    private var assignmentListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Search assignments", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)
                Spacer()
            }

            ScrollView {
                VStack(spacing: DesignSystem.Layout.spacing.small) {
                    ForEach(filteredAndSortedAssignments) { assignment in
                        AssignmentsPageRow(
                            assignment: assignment,
                            isSelected: assignment.id == selectedAssignment?.id || selectedIDs.contains(assignment.id),
                            onToggleComplete: { toggleCompletion(for: assignment) },
                            onSelect: { selectedAssignment = assignment },
                            leadingAction: settings.assignmentSwipeLeading,
                            trailingAction: settings.assignmentSwipeTrailing,
                            onPerformAction: { performSwipeAction($0, assignment: assignment) }
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: AssignmentFramePreference.self, value: [assignment.id: geo.frame(in: .named("assignmentsArea"))])
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Corners.card, style: .continuous)
                .fill(Color(nsColor: NSColor.alternatingContentBackgroundColors[0]).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Corners.card, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var detailPanel: some View {
        AssignmentDetailPanel(
            assignment: Binding(
                get: { selectedAssignment },
                set: { selectedAssignment = $0 }
            ),
            onUpdate: { updated in
                upsertAssignment(updated)
            },
            onEdit: { toEdit in
                editingAssignment = toEdit
                showNewAssignmentSheet = true
            },
            onDelete: { toDelete in
                deleteAssignment(toDelete)
            }
        )
    }

    // MARK: Helpers

    private var filteredAndSortedAssignments: [Assignment] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? Date()
        let upcomingEnd = calendar.date(byAdding: .day, value: 7, to: todayStart) ?? Date()

        var result = assignments

        // Segment filter
        result = result.filter { assignment in
            switch selectedSegment {
            case .today:
                return assignment.status != .completed &&
                calendar.isDate(assignment.dueDate, inSameDayAs: todayStart)
            case .upcoming:
                return assignment.status != .completed &&
                assignment.dueDate >= tomorrow &&
                assignment.dueDate <= upcomingEnd
            case .all:
                return assignment.status != .archived
            case .completed:
                return assignment.status == .completed
            }
        }

        // Search
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                ($0.courseCode ?? "").lowercased().contains(q) ||
                ($0.courseName ?? "").lowercased().contains(q) ||
                $0.category.displayName.lowercased().contains(q)
            }
        }

        // Filters
        if let filterStatus {
            result = result.filter { $0.status == filterStatus }
        }
        if let filterCourse {
            result = result.filter { $0.courseCode == filterCourse || $0.courseName == filterCourse }
        }

        // Sort
        switch sortOption {
        case .byDueDate:
            result = result.sorted { $0.dueDate < $1.dueDate }
        case .byCourse:
            result = result.sorted { ($0.courseCode ?? "") < ($1.courseCode ?? "") }
        case .byUrgency:
            let order: [AssignmentUrgency: Int] = [.critical: 0, .high: 1, .medium: 2, .low: 3]
            result = result.sorted { (order[$0.urgency] ?? 99) < (order[$1.urgency] ?? 99) }
        }

        return result
    }

    private var uniqueCourses: [String] {
        Set(assignments.map { $0.courseCode ?? "" }).sorted()
    }

    private var activeFiltersLabel: String {
        var parts: [String] = []
        parts.append("Segment: \(selectedSegment.label)")
        parts.append("Sort: \(sortOption.label)")
        parts.append("Status: \(filterStatus?.label ?? "Any")")
        parts.append("Course: \(filterCourse ?? "Any")")
        return parts.joined(separator: " · ")
    }

    private func toggleCompletion(for assignment: Assignment) {
        guard let idx = assignments.firstIndex(where: { $0.id == assignment.id }) else { return }
        assignments[idx].status = assignments[idx].status == .completed ? .notStarted : .completed
        if selectedAssignment?.id == assignment.id {
            selectedAssignment = assignments[idx]
        }
    }

    private func performSwipeAction(_ action: AssignmentSwipeAction, assignment: Assignment) {
        switch action {
        case .complete:
            toggleCompletion(for: assignment)
        case .edit:
            editingAssignment = assignment
            showNewAssignmentSheet = true
        case .delete:
            deleteAssignment(assignment)
        case .openDetail:
            selectedAssignment = assignment
        }
    }

    private func upsertAssignment(_ assignment: Assignment) {
        if let idx = assignments.firstIndex(where: { $0.id == assignment.id }) {
            assignments[idx] = ensurePlan(assignment)
        } else {
            assignments.append(ensurePlan(assignment))
        }
        selectedAssignment = ensurePlan(assignment)
    }

    private func deleteAssignment(_ assignment: Assignment) {
        assignments.removeAll { $0.id == assignment.id }
        if selectedAssignment?.id == assignment.id {
            selectedAssignment = nil
        }
    }

    private func autoPlanSelectedAssignments() {
        let targetAssignments: [Assignment]
        if let selectedAssignment {
            targetAssignments = [selectedAssignment]
        } else {
            targetAssignments = filteredAndSortedAssignments
        }

        for assignment in targetAssignments {
            let defaultProfile = assignment.category.effortProfile
            var profile = defaultProfile
            if let stored = AppSettingsModel.shared.categoryEffortProfilesStorage[assignment.category.rawValue] {
                profile = CategoryEffortProfile(
                    baseMinutes: stored.baseMinutes,
                    minSessions: stored.minSessions,
                    spreadDaysBeforeDue: stored.spreadDaysBeforeDue,
                    sessionBias: EffortBias(rawValue: stored.sessionBiasRaw) ?? defaultProfile.sessionBias
                )
            }

            var totalMinutes = assignment.estimatedMinutes
            if totalMinutes == 0 || totalMinutes == 60 {
                totalMinutes = profile.baseMinutes
            }
            let suggestedLen = suggestedSessionLength(profile.sessionBias)
            let computedSessions = max(profile.minSessions, Int(round(Double(totalMinutes) / Double(suggestedLen))))
            let days = max(1, profile.spreadDaysBeforeDue)
            print("Auto-plan for '\(assignment.title)': Typical: \(computedSessions) × \(suggestedLen) min across \(days) days (category: \(assignment.category.displayName))")

            // TODO: integrate with Planner engine to actually schedule SuggestedBlocks
        }
    }

    private func ensurePlan(_ assignment: Assignment) -> Assignment {
        if assignment.plan.isEmpty {
            var updated = assignment
            updated.plan = Assignment.defaultPlan(for: assignment.category, due: assignment.dueDate, totalMinutes: assignment.estimatedMinutes)
            return updated
        }
        return assignment
    }

    private func focusAssignment(closestTo dueDate: Date) {
        let sorted = assignments
            .filter { $0.status != .archived }
            .sorted { $0.dueDate < $1.dueDate }
        guard !sorted.isEmpty else { return }
        if let match = sorted.first(where: { $0.dueDate >= dueDate }) {
            selectedAssignment = match
        } else {
            selectedAssignment = sorted.first
        }
    }

}

// MARK: - Summary Cards

struct TodaySummaryCard: View {
    var assignments: [Assignment]
    @Binding var selectedSegment: AssignmentSegment

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueToday = assignments.filter { calendar.isDate($0.dueDate, inSameDayAs: today) && $0.status != .archived }
        let planned = dueToday.filter { $0.status == .inProgress }
        let remaining = dueToday.filter { $0.status != .completed }

        RootsCard(compact: true) {
            HStack {
                Text(NSLocalizedString("assignments.section.today", comment: "Today section")).rootsSectionHeader()
                Spacer()
            }

            Text("\(dueToday.count) due · \(planned.count) planned · \(remaining.count) remaining")
                .rootsCaption()

            HStack(spacing: 6) {
                ForEach(AssignmentUrgency.allCases, id: \.self) { urgency in
                    let count = dueToday.filter { $0.urgency == urgency }.count
                    if count > 0 {
                        Label("\(count)", systemImage: "circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(urgency.color)
                    }
                }
            }
        }
    }
}

struct ByCourseSummaryCard: View {
    var assignments: [Assignment]
    var onSelectCourse: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private struct CourseLoad: Identifiable {
        let id = UUID()
        let course: String
        let count: Int
    }

    var body: some View {
        let grouped = Dictionary(grouping: assignments.filter { ($0.status ?? .notStarted) != .archived }) { $0.courseCode ?? "Unknown" as String }
            .map { CourseLoad(course: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
        VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
            Text(NSLocalizedString("assignments.section.by_course", comment: "By course section")).rootsSectionHeader()

            ForEach(grouped.prefix(4)) { item in
                HStack {
                    Text(item.course)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(item.count)").rootsCaption()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                        .fill(RootsColor.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous)
                        .stroke(RootsColor.glassBorder(for: colorScheme), lineWidth: 1)
                )
                .onTapGesture {
                    onSelectCourse(item.course)
                }
            }
        }
        .padding(12)
        .rootsCardBackground(radius: 16)
    }
}

struct LoadTimelineCard: View {
    var assignments: [Assignment]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let next7 = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: today) ?? today }

        VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
            Text(NSLocalizedString("assignments.section.upcoming_load", comment: "Upcoming load section")).rootsSectionHeader()

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(next7, id: \.self) { day in
                    let dayAssignments = assignments.filter { calendar.isDate($0.dueDate, inSameDayAs: day) && $0.status != .archived }
                    let count = dayAssignments.count
                    let avgUrgency = dayAssignments.map { urgencyValue($0.urgency) }.reduce(0, +) / max(1, dayAssignments.count)
                    let urgencyColor = urgencyFromValue(avgUrgency).color

                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(urgencyColor.opacity(0.85))
                            .frame(width: 22, height: CGFloat(max(10, min(120, count * 14))))
                        Text(shortDayFormatter.string(from: day))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .rootsCardBackground(radius: 16)
        .frame(maxWidth: .infinity)
    }

    private func urgencyValue(_ urgency: AssignmentUrgency) -> Int {
        switch urgency {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }

    private func urgencyFromValue(_ value: Int) -> AssignmentUrgency {
        switch value {
        case 4: return .critical
        case 3: return .high
        case 2: return .medium
        default: return .low
        }
    }

    private var shortDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }
}

struct UpcomingCountCard: View {
    var assignments: [Assignment]

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let upcoming = assignments.filter { task in
            guard task.status != .archived else { return false }
            let due = task.dueDate
            return due >= today
        }.count

        RootsCard(compact: true) {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("assignments.section.upcoming", comment: "Upcoming section")).rootsSectionHeader()
                Text("\(upcoming)")
                    .font(.title.bold())
                Text(NSLocalizedString("assignments.stats.assignments_due", comment: "Assignments due info"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MissedCountCard: View {
    var assignments: [Assignment]

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let missed = assignments.filter { task in
            guard task.status != .archived else { return false }
            let due = task.dueDate
            return due < today && task.status != .completed
        }.count

        RootsCard(compact: true) {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("assignments.section.missed", comment: "Missed section")).rootsSectionHeader()
                Text("\(missed)")
                    .font(.title.bold())
                Text(NSLocalizedString("assignments.stats.overdue_assignments", comment: "Overdue info"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Assignment Row

struct AssignmentsPageRow: View {
    var assignment: Assignment
    var isSelected: Bool
    var onToggleComplete: () -> Void
    var onSelect: () -> Void
    var leadingAction: AssignmentSwipeAction
    var trailingAction: AssignmentSwipeAction
    var onPerformAction: (AssignmentSwipeAction) -> Void

    private var urgencyColor: Color { assignment.urgency.color }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(urgencyColor)
                    .frame(width: 4)
                    .cornerRadius(2)

                Button(action: onToggleComplete) {
                    Image(systemName: assignment.status == .completed ? "checkmark.square.fill" : "square")
                        .foregroundColor(assignment.status == .completed ? .green : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(assignment.courseCode ?? "")
                        Text("· \(assignment.category.displayName)")
                        Text("· ~\(assignment.estimatedMinutes) min")
                        Text("·")
                        Text("Due \(dueFormatter.string(from: assignment.dueDate))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                            )
                            .clipShape(Capsule())
                        if let weight = assignment.weightPercent {
                            Text("· \(Int(weight))%")
                        }
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                statusChip
            }
            .padding(.horizontal, 10)
            .frame(height: DesignSystem.Layout.rowHeight.medium)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Corners.block, style: .continuous)
                    .fill(isSelected ? Color(nsColor: NSColor.unemphasizedSelectedContentBackgroundColor).opacity(0.14) : Color(nsColor: NSColor.alternatingContentBackgroundColors[0]).opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Corners.block, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            swipeButton(for: leadingAction)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            swipeButton(for: trailingAction)
        }
    }

    @ViewBuilder
    private func swipeButton(for action: AssignmentSwipeAction) -> some View {
        Button {
            onPerformAction(action)
        } label: {
            Label(action.label, systemImage: action.systemImage)
        }
        .tint(tintColor(for: action))
    }

    private func tintColor(for action: AssignmentSwipeAction) -> Color {
        switch action {
        case .complete: return .green
        case .edit: return .blue
        case .delete: return .red
        case .openDetail: return .accentColor
        }
    }

    private var statusChip: some View {
        Text((assignment.status ?? .notStarted).label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                Capsule()
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }

    private var dueFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }
}

// MARK: - Detail Panel

struct AssignmentDetailPanel: View {
    @Binding var assignment: Assignment?
    var onUpdate: (Assignment) -> Void
    var onEdit: (Assignment) -> Void
    var onDelete: (Assignment) -> Void

    private let cardCorner: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let assignment {
                header(for: assignment)
                Divider()
                dueSection(for: assignment)
                gradeImpact(for: assignment)
                actionsSection(for: assignment)
                planSection(for: assignment)
                footerActions(for: assignment)
            } else {
                placeholder
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .rootsCardBackground(radius: cardCorner)
    }

    private func header(for assignment: Assignment) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(assignment.title)
                    .font(.title3.weight(.semibold))
                Text("\(assignment.courseCode ?? "Unknown") · \(assignment.courseName ?? "Unknown")")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text((assignment.status ?? .notStarted).label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color(nsColor: .controlBackgroundColor))
                )
            Button {
                onEdit(assignment)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.plain)
        }
    }

    private func dueSection(for assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
            Text("Due \(fullDateFormatter.string(from: assignment.dueDate))")
                .font(DesignSystem.Typography.subHeader)
            Text(countdownText(for: assignment.dueDate))
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack(spacing: DesignSystem.Layout.spacing.small) {
                Label("Est. Time: \(assignment.estimatedMinutes) min", systemImage: "timer")
                    .font(DesignSystem.Typography.caption)
                    .padding(DesignSystem.Layout.spacing.small)
                    .background(Capsule().fill(Color(nsColor: NSColor.alternatingContentBackgroundColors[0])))
                Toggle("Lock work to due date", isOn: Binding(
                    get: { assignment.isLockedToDueDate },
                    set: { newValue in
                        var updated = assignment
                        updated.isLockedToDueDate = newValue
                        onUpdate(updated)
                        self.assignment = updated
                    }
                ))
                .toggleStyle(.switch)
            }
        }
    }

    private func gradeImpact(for assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("assignments.detail.grade_impact", comment: "Grade impact label"))
                .font(DesignSystem.Typography.subHeader)
            if let weight = assignment.weightPercent {
                Text("Worth \(Int(weight))% of final grade in \(assignment.category.displayName)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
                ProgressView(value: min(max(weight / 100, 0), 1))
                    .progressViewStyle(.linear)
            } else {
                Text(NSLocalizedString("assignments.detail.no_weight", comment: "No weight message"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func planSection(for assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("assignments.detail.plan", comment: "Plan section"))
                .font(DesignSystem.Typography.subHeader)
            ForEach(assignment.plan) { step in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(DesignSystem.Typography.body)
                        Text("\(step.expectedMinutes) min")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("~\(step.expectedMinutes) min")
                        .font(DesignSystem.Typography.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: NSColor.alternatingContentBackgroundColors[0]))
                )
            }
        }
    }

    private func actionsSection(for assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.spacing.small) {
            Text(NSLocalizedString("assignments.detail.actions", comment: "Actions section")).rootsSectionHeader()
            HStack(spacing: RootsSpacing.s) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("assignments.detail.state", comment: "State label"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button("Mark Completed") {
                        var updated = assignment
                        updated.status = .completed
                        onUpdate(updated)
                        self.assignment = updated
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("assignments.detail.planning", comment: "Planning label"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button("Planner") {
                        // TODO: navigate to Planner with this assignment
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel("Open Planner for this assignment")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("assignments.detail.execution", comment: "Execution label"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button("Timer") {
                        // TODO: open Timer with this assignment
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel("Open Timer for this assignment")
                }
            }
        }
    }

    private func footerActions(for assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Mark as completed") {
                    var updated = assignment
                    updated.status = .completed
                    onUpdate(updated)
                    self.assignment = updated
                }

                Button("Archive") {
                    var updated = assignment
                    updated.status = .archived
                    onUpdate(updated)
                    self.assignment = updated
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Divider()

            Button(role: .destructive) {
                onDelete(assignment)
                self.assignment = nil
            } label: {
                Text(NSLocalizedString("assignments.detail.delete", comment: "Delete button"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.full")
                .font(DesignSystem.Typography.display)
                .foregroundColor(.secondary)
            Text(NSLocalizedString("assignments.detail.select_prompt", comment: "Select prompt"))
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func countdownText(for date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour], from: now, to: date)
        if let day = components.day, day > 0 {
            return "Due in \(day) day\(day == 1 ? "" : "s")"
        } else if let hour = components.hour, hour > 0 {
            return "Due in \(hour) hour\(hour == 1 ? "" : "s")"
        } else {
            return "Due soon"
        }
    }

    private var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d · h:mm a"
        return formatter
    }
}

// MARK: - Editor Sheet

struct AssignmentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coursesStore: CoursesStore

    var assignment: Assignment?
    var onSave: (Assignment) -> Void

    @State private var title: String = ""
    @State private var selectedCourseId: UUID? = nil
    @State private var category: AssignmentCategory = .practiceHomework
    @State private var dueDate: Date = Date()
    @State private var estimatedMinutes: Int = 60
    @State private var urgency: AssignmentUrgency = .medium
    @State private var weightText: String = ""
    @State private var isLocked: Bool = false
    @State private var notes: String = ""
    @State private var status: AssignmentStatus = .notStarted

    var body: some View {
        RootsPopupContainer(
            title: assignment == nil ? "New Assignment" : "Edit Assignment",
            subtitle: "Planner tasks connect to Assignments and Timer."
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: RootsSpacing.l) {
                VStack(alignment: .leading, spacing: RootsSpacing.m) {
                    Text(NSLocalizedString("assignments.editor.section.task", comment: "Task section")).rootsSectionHeader()
                    RootsFormRow(label: "Title") {
                        TextField("Title", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    coursePickerRow
                    RootsFormRow(label: "Category") {
                        Picker("Category", selection: $category) {
                            ForEach(AssignmentCategory.allCases) { cat in
                                Text(cat.displayName).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                    VStack(alignment: .leading, spacing: RootsSpacing.m) {
                        Text(NSLocalizedString("assignments.editor.section.timing", comment: "Timing section")).rootsSectionHeader()
                        RootsFormRow(label: "Due") {
                            DatePicker("", selection: $dueDate)
                                .labelsHidden()
                        }
                        RootsFormRow(label: "Estimated") {
                            Stepper(value: $estimatedMinutes, in: 15...240, step: 15) {
                                Text("\(estimatedMinutes) min")
                                    .rootsBody()
                            }
                        } helper: {
                            // Show category-driven suggestion
                            let profile = category.effortProfile
                            let sessionLen = suggestedSessionLength(profile.sessionBias)
                            let sessions = max(profile.minSessions, Int(round(Double(profile.baseMinutes) / Double(sessionLen))))
                            Text("Typical: \(sessions) × \(sessionLen) min over \(profile.spreadDaysBeforeDue) days for \(category.displayName)")
                                .rootsCaption()
                                .foregroundColor(.secondary)
                        }
                        RootsFormRow(label: "Urgency") {
                            Picker("", selection: $urgency) {
                                ForEach(AssignmentUrgency.allCases) { u in
                                    Text(u.rawValue.capitalized).tag(u)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        RootsFormRow(label: "Weight %") {
                            TextField("Optional", text: $weightText)
                                .textFieldStyle(.roundedBorder)
                        }
                        RootsFormRow(label: "Lock") {
                            Toggle("Lock work to due date", isOn: $isLocked)
                                .toggleStyle(.switch)
                        }
                    }

                    VStack(alignment: .leading, spacing: RootsSpacing.m) {
                        Text(NSLocalizedString("assignments.editor.section.status", comment: "Status section")).rootsSectionHeader()
                        RootsFormRow(label: "Status") {
                            Picker("", selection: $status) {
                                ForEach(AssignmentStatus.allCases) { s in
                                    Text(s.label).tag(s)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    VStack(alignment: .leading, spacing: RootsSpacing.m) {
                        Text("Notes").rootsSectionHeader()
                        TextEditor(text: $notes)
                            .textEditorStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .padding(DesignSystem.Layout.spacing.small)
                            .frame(minHeight: 120)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.Cards.cardCornerRadius, style: .continuous)
                                    .fill(RootsColor.inputBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Cards.cardCornerRadius, style: .continuous))
                    }
                }
            }
        } footer: {
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let weight = Double(weightText)
                    let course = coursesStore.courses.first(where: { $0.id == selectedCourseId })
                    let newAssignment = Assignment(
                        id: assignment?.id ?? UUID(),
                        courseId: course?.id,
                        title: title,
                        dueDate: dueDate,
                        estimatedMinutes: estimatedMinutes,
                        weightPercent: weight,
                        category: category,
                        urgency: urgency,
                        isLockedToDueDate: isLocked,
                        plan: [],
                        status: status,
                        courseCode: course?.code ?? "",
                        courseName: course?.title ?? "",
                        notes: notes
                    )
                    onSave(newAssignment)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCourseId == nil)
            }
        }
        .onAppear {
            prefillCourse()
            if let assignment {
                title = assignment.title
                selectedCourseId = assignment.courseId
                category = assignment.category
                dueDate = assignment.dueDate
                estimatedMinutes = assignment.estimatedMinutes
                urgency = assignment.urgency
                if let weight = assignment.weightPercent {
                    weightText = "\(weight)"
                }
                isLocked = assignment.isLockedToDueDate
                notes = assignment.notes ?? "" as String
                status = assignment.status ?? .notStarted
            }
        }
        .frame(minWidth: RootsWindowSizing.minPopupWidth, minHeight: RootsWindowSizing.minPopupHeight)
    }

    private var coursePickerRow: some View {
        let activeCourses = currentSemesterCourses
        return RootsFormRow(label: "Course") {
            if activeCourses.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No courses in this semester")
                        .foregroundStyle(.secondary)
                    Button("Add Course…") {
                        // TODO: open Settings → Courses
                    }
                    .buttonStyle(.link)
                }
            } else {
                Picker(NSLocalizedString("assignments.sort.course", comment: "Course filter"), selection: $selectedCourseId) {
                    ForEach(activeCourses) { course in
                        Text("\(course.code) · \(course.title)")
                            .tag(Optional(course.id))
                    }
                }
                .pickerStyle(.menu)
            }
        } helper: {
            if selectedCourseId == nil {
                Text("Select a course from the active semester to save.")
                    .rootsCaption()
                    .foregroundStyle(.red)
            }
        }
    }

    private var currentSemesterCourses: [Course] {
        if let current = coursesStore.currentSemesterId {
            return coursesStore.courses.filter { $0.semesterId == current }
        }
        // Fallback to most recent semester by start date
        if let recent = coursesStore.semesters.sorted(by: { $0.startDate > $1.startDate }).first {
            return coursesStore.courses.filter { $0.semesterId == recent.id }
        }
        return []
    }

    private func prefillCourse() {
        if let assignment, let existingId = assignment.courseId {
            selectedCourseId = existingId
            return
        }
        if selectedCourseId == nil {
            selectedCourseId = currentSemesterCourses.first?.id
        }
    }
}

// MARK: - Samples

private extension AssignmentsPageView {
    static var sampleAssignments: [Assignment] { [] }
}

// MARK: - Drag Selection (Assignments)

private extension AssignmentsPageView {
    func dragSelectionGesture() -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("assignmentsArea"))
            .onChanged { value in
                if selectionStart == nil { selectionStart = value.startLocation }
                if let start = selectionStart {
                    selectionRect = rect(from: start, to: value.location)
                    selectionMenuLocation = nil
                }
            }
            .onEnded { value in
                guard let start = selectionStart else { selectionRect = nil; return }
                let finalRect = rect(from: start, to: value.location)
                let hits = assignmentFrames.compactMap { id, frame in
                    finalRect.intersects(frame) ? id : nil
                }
                selectedIDs = Set(hits)
                selectionMenuLocation = hits.isEmpty ? nil : value.location
                selectionStart = nil
                selectionRect = nil
            }
    }

    var selectionOverlay: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                if let rect = selectionRect {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.2)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
                if let menuPoint = selectionMenuLocation, !selectedIDs.isEmpty {
                    selectionMenu
                        .position(menuPoint)
                        .transition(DesignSystem.Motion.scaleTransition)
                }
            }
            .onPreferenceChange(AssignmentFramePreference.self) { frames in
                assignmentFrames = frames
            }
        }
    }

    var selectionMenu: some View {
        HStack(spacing: 10) {
            Button("Cut") { cutSelection() }
                .disabled(selectedIDs.isEmpty)
            Button("Copy") { copySelection() }
                .disabled(selectedIDs.isEmpty)
            Button("Duplicate") { duplicateSelection() }
                .disabled(selectedIDs.isEmpty)
            Button("Paste") { pasteClipboard() }
                .disabled(clipboard.isEmpty)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
    }

    func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(x: min(start.x, end.x),
               y: min(start.y, end.y),
               width: abs(end.x - start.x),
               height: abs(end.y - start.y))
    }

    func copySelection() {
        clipboard = assignments.filter { selectedIDs.contains($0.id) }
    }

    func cutSelection() {
        copySelection()
        assignments.removeAll { selectedIDs.contains($0.id) }
        selectedIDs.removeAll()
        selectionMenuLocation = nil
    }

    func duplicateSelection() {
        let toDuplicate = assignments.filter { selectedIDs.contains($0.id) }
        let copies = toDuplicate.map { item in
            Assignment(
                id: UUID(),
                courseId: item.courseId,
                title: item.title + " (copy)",
                dueDate: item.dueDate,
                estimatedMinutes: item.estimatedMinutes,
                weightPercent: item.weightPercent,
                category: item.category,
                urgency: item.urgency,
                isLockedToDueDate: item.isLockedToDueDate,
                plan: item.plan,
                status: item.status,
                courseCode: item.courseCode,
                courseName: item.courseName,
                notes: item.notes
            )
        }
        assignments.append(contentsOf: copies)
        selectedIDs.removeAll()
    }

    func pasteClipboard() {
        guard !clipboard.isEmpty else { return }
        let pasted = clipboard.map { item in
            Assignment(
                id: UUID(),
                courseId: item.courseId,
                title: item.title,
                dueDate: item.dueDate,
                estimatedMinutes: item.estimatedMinutes,
                weightPercent: item.weightPercent,
                category: item.category,
                urgency: item.urgency,
                isLockedToDueDate: item.isLockedToDueDate,
                plan: item.plan,
                status: item.status,
                courseCode: item.courseCode,
                courseName: item.courseName,
                notes: item.notes
            )
        }
        assignments.append(contentsOf: pasted)
        selectedIDs.removeAll()
    }
}

// MARK: - Preferences

private struct AssignmentFramePreference: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
#endif
