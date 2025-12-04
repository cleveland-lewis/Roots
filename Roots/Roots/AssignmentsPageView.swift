import SwiftUI

// MARK: - Models

enum AssignmentStatus: String, CaseIterable, Identifiable {
    case notStarted, inProgress, completed, archived
    var id: String { rawValue }

    var label: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
}

enum AssignmentUrgency: String, CaseIterable, Identifiable {
    case low, medium, high, critical
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct Assignment: Identifiable, Hashable {
    let id: UUID
    var courseId: UUID? = nil
    var title: String
    var courseCode: String
    var courseName: String
    var category: String
    var dueDate: Date
    var estimatedMinutes: Int
    var status: AssignmentStatus
    var urgency: AssignmentUrgency
    var weightPercent: Double?
    var isLockedToDueDate: Bool
    var notes: String
}

enum AssignmentSegment: String, CaseIterable, Identifiable {
    case today, upcoming, all, completed
    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .all: return "All"
        case .completed: return "Completed"
        }
    }
}

enum AssignmentSortOption: String, CaseIterable, Identifiable {
    case byDueDate, byCourse, byUrgency
    var id: String { rawValue }

    var label: String {
        switch self {
        case .byDueDate: return "Due Date"
        case .byCourse: return "Course"
        case .byUrgency: return "Urgency"
        }
    }
}

// MARK: - Root View

struct AssignmentsPageView: View {
    @EnvironmentObject private var settings: AppSettings

    @State private var assignments: [Assignment] = AssignmentsPageView.sampleAssignments
    @State private var selectedSegment: AssignmentSegment = .all
    @State private var selectedAssignment: Assignment? = nil
    @State private var searchText: String = ""
    @State private var showNewAssignmentSheet: Bool = false
    @State private var editingAssignment: Assignment? = nil
    @State private var sortOption: AssignmentSortOption = .byDueDate
    @State private var filterStatus: AssignmentStatus? = nil
    @State private var filterCourse: String? = nil
    @State private var showFilterPopover: Bool = false

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
    }

    // MARK: Top Controls

    private var topControls: some View {
        HStack(spacing: RootsSpacing.m) {
            Picker("Segment", selection: $selectedSegment.animation(.spring(response: 0.3, dampingFraction: 0.85))) {
                ForEach(AssignmentSegment.allCases) { seg in
                    Text(seg.label).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 340)

            Spacer()

            TextField("Search assignments", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)

            Picker("Sort", selection: $sortOption) {
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
                    .padding()
                    .frame(width: 260)
            }

            Button {
                editingAssignment = nil
                showNewAssignmentSheet = true
            } label: {
                Label("New", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: NSColor.alternatingContentBackgroundColors[0]).opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                autoPlanSelectedAssignments()
            } label: {
                Label("Auto-Plan", systemImage: "wand.and.stars")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RootsColor.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var filterPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.headline)
            Divider()
            Picker("Status", selection: Binding(
                get: { filterStatus },
                set: { filterStatus = $0 }
            )) {
                Text("Any").tag(AssignmentStatus?.none)
                ForEach(AssignmentStatus.allCases) { status in
                    Text(status.label).tag(AssignmentStatus?.some(status))
                }
            }
            .pickerStyle(.menu)

            Picker("Course", selection: Binding(
                get: { filterCourse },
                set: { filterCourse = $0 }
            )) {
                Text("All courses").tag(String?.none)
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
                Text("Assignments")
                    .rootsSectionHeader()
                Spacer()
                Text(activeFiltersLabel)
                    .rootsCaption()
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(filteredAndSortedAssignments) { assignment in
                        AssignmentsPageRow(
                            assignment: assignment,
                            isSelected: assignment.id == selectedAssignment?.id,
                            onToggleComplete: { toggleCompletion(for: assignment) },
                            onSelect: { selectedAssignment = assignment },
                            onFocusDetail: { selectedAssignment = assignment }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .rootsCardBackground(radius: cardCorner)
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
                $0.courseCode.lowercased().contains(q) ||
                $0.courseName.lowercased().contains(q) ||
                $0.category.lowercased().contains(q)
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
            result = result.sorted { $0.courseCode < $1.courseCode }
        case .byUrgency:
            let order: [AssignmentUrgency: Int] = [.critical: 0, .high: 1, .medium: 2, .low: 3]
            result = result.sorted { (order[$0.urgency] ?? 99) < (order[$1.urgency] ?? 99) }
        }

        return result
    }

    private var uniqueCourses: [String] {
        Set(assignments.map { $0.courseCode }).sorted()
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

    private func upsertAssignment(_ assignment: Assignment) {
        if let idx = assignments.firstIndex(where: { $0.id == assignment.id }) {
            assignments[idx] = assignment
        } else {
            assignments.append(assignment)
        }
        selectedAssignment = assignment
    }

    private func autoPlanSelectedAssignments() {
        let targetAssignments: [Assignment]
        if let selectedAssignment {
            targetAssignments = [selectedAssignment]
        } else {
            targetAssignments = filteredAndSortedAssignments
        }
        // Placeholder: replace with AIScheduler integration
        let titles = targetAssignments.map { $0.title }.joined(separator: ", ")
        print("Auto-plan requested for: \(titles)")
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
                Text("Today").rootsSectionHeader()
                Spacer()
                Button("Focus") {
                    selectedSegment = .today
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
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

    private struct CourseLoad: Identifiable {
        let id = UUID()
        let course: String
        let count: Int
    }

    var body: some View {
        let grouped = Dictionary(grouping: assignments.filter { $0.status != .archived }) { $0.courseCode }
            .map { CourseLoad(course: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
        VStack(alignment: .leading, spacing: 8) {
            Text("By Course").rootsSectionHeader()

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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(RootsColor.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(RootsColor.glassBorder, lineWidth: 1)
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

        VStack(alignment: .leading, spacing: 8) {
            Text("Upcoming Load").rootsSectionHeader()

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(next7, id: \.self) { day in
                    let dayAssignments = assignments.filter { calendar.isDate($0.dueDate, inSameDayAs: day) && $0.status != .archived }
                    let count = dayAssignments.count
                    let avgUrgency = dayAssignments.map { urgencyValue($0.urgency) }.reduce(0, +) / max(1, dayAssignments.count)
                    let urgencyColor = urgencyFromValue(avgUrgency).color

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(urgencyColor.opacity(0.8))
                            .frame(width: 14, height: CGFloat(max(10, count * 10)))
                        Text(shortDayFormatter.string(from: day))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .rootsCardBackground(radius: 16)
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

// MARK: - Assignment Row

struct AssignmentsPageRow: View {
    var assignment: Assignment
    var isSelected: Bool
    var onToggleComplete: () -> Void
    var onSelect: () -> Void
    var onFocusDetail: () -> Void

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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(assignment.courseCode)
                        Text("· \(assignment.category)")
                        Text("· ~\(assignment.estimatedMinutes) min")
                        Text("· Due \(dueFormatter.string(from: assignment.dueDate))")
                        if let weight = assignment.weightPercent {
                            Text("· \(Int(weight))%")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                statusChip

                Button(action: onFocusDetail) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color(nsColor: NSColor.unemphasizedSelectedContentBackgroundColor).opacity(0.12) : Color(nsColor: NSColor.alternatingContentBackgroundColors[0]))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var statusChip: some View {
        Text(assignment.status.label)
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

    private let cardCorner: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let assignment {
                header(for: assignment)
                Divider()
                dueSection(for: assignment)
                gradeImpact(for: assignment)
                plannerSection(for: assignment)
                notesSection(for: assignment)
                footerActions(for: assignment)
            } else {
                placeholder
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .rootsCardBackground(radius: cardCorner)
    }

    private func header(for assignment: Assignment) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(assignment.title)
                    .font(.title3.weight(.semibold))
                Text("\(assignment.courseCode) · \(assignment.courseName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(assignment.status.label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color(nsColor: .controlBackgroundColor))
                )
        }
    }

    private func dueSection(for assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Due \(fullDateFormatter.string(from: assignment.dueDate))")
                .font(.headline)
            Text(countdownText(for: assignment.dueDate))
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Label("~\(assignment.estimatedMinutes) min focus block", systemImage: "timer")
                    .font(.caption)
                    .padding(8)
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
            Text("Grade Impact")
                .font(.headline)
            if let weight = assignment.weightPercent {
                Text("Worth \(Int(weight))% of final grade in \(assignment.category)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ProgressView(value: min(max(weight / 100, 0), 1))
                    .progressViewStyle(.linear)
            } else {
                Text("No weight specified yet. This will sync from Syllabus later.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func plannerSection(for assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Planner & Omodoro")
                .font(.headline)
            HStack {
                Button("Plan a focus block") {
                    // stub planner hook
                }
                Button("Add to Omodoro queue") {
                    // stub timer hook
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func notesSection(for assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(.headline)
            TextEditor(text: Binding(
                get: { assignment.notes },
                set: { newValue in
                    var updated = assignment
                    updated.notes = newValue
                    onUpdate(updated)
                    self.assignment = updated
                }
            ))
            .frame(minHeight: 140)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }

    private func footerActions(for assignment: Assignment) -> some View {
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
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.full")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Select an assignment to see details.")
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

    var assignment: Assignment?
    var onSave: (Assignment) -> Void

    @State private var title: String = ""
    @State private var courseCode: String = ""
    @State private var courseName: String = ""
    @State private var category: String = "Homework"
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
                        Text("Task").rootsSectionHeader()
                        RootsFormRow(label: "Title") {
                            TextField("Title", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }
                        RootsFormRow(label: "Course code") {
                            TextField("Course code", text: $courseCode)
                                .textFieldStyle(.roundedBorder)
                        }
                        RootsFormRow(label: "Course name") {
                            TextField("Course name", text: $courseName)
                                .textFieldStyle(.roundedBorder)
                        }
                        RootsFormRow(label: "Category") {
                            TextField("Category", text: $category)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    VStack(alignment: .leading, spacing: RootsSpacing.m) {
                        Text("Timing").rootsSectionHeader()
                        RootsFormRow(label: "Due") {
                            DatePicker("", selection: $dueDate)
                                .labelsHidden()
                        }
                        RootsFormRow(label: "Estimated") {
                            Stepper("Estimated time: \(estimatedMinutes) min", value: $estimatedMinutes, in: 15...240, step: 15)
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
                        Text("Status").rootsSectionHeader()
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
                            .frame(minHeight: 120)
                            .rootsCardBackground(radius: 12)
                    }
                }
            }
        } footer: {
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let weight = Double(weightText)
                    let newAssignment = Assignment(
                        id: assignment?.id ?? UUID(),
                        courseId: assignment?.courseId,
                        title: title,
                        courseCode: courseCode,
                        courseName: courseName.isEmpty ? courseCode : courseName,
                        category: category,
                        dueDate: dueDate,
                        estimatedMinutes: estimatedMinutes,
                        status: status,
                        urgency: urgency,
                        weightPercent: weight,
                        isLockedToDueDate: isLocked,
                        notes: notes
                    )
                    onSave(newAssignment)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            if let assignment {
                title = assignment.title
                courseCode = assignment.courseCode
                courseName = assignment.courseName
                category = assignment.category
                dueDate = assignment.dueDate
                estimatedMinutes = assignment.estimatedMinutes
                urgency = assignment.urgency
                if let weight = assignment.weightPercent {
                    weightText = "\(weight)"
                }
                isLocked = assignment.isLockedToDueDate
                notes = assignment.notes
                status = assignment.status
            }
        }
        .frame(minWidth: RootsWindowSizing.minPopupWidth, minHeight: RootsWindowSizing.minPopupHeight)
    }
}

// MARK: - Samples

private extension AssignmentsPageView {
    static var sampleAssignments: [Assignment] {
        let now = Date()
        let calendar = Calendar.current
        let day1 = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let day2 = calendar.date(byAdding: .day, value: 3, to: now) ?? now
        let day3 = calendar.date(byAdding: .day, value: 5, to: now) ?? now

        return [
            Assignment(id: UUID(), courseId: UUID(), title: "Problem Set 5", courseCode: "MA 231", courseName: "Calculus II", category: "Homework", dueDate: day1, estimatedMinutes: 90, status: .inProgress, urgency: .high, weightPercent: 8, isLockedToDueDate: false, notes: "Focus on integrals."),
            Assignment(id: UUID(), courseId: UUID(), title: "Quiz 3 Review", courseCode: "CS 240", courseName: "Data Structures", category: "Quiz", dueDate: day2, estimatedMinutes: 45, status: .notStarted, urgency: .medium, weightPercent: 5, isLockedToDueDate: false, notes: "Queue to planner."),
            Assignment(id: UUID(), courseId: UUID(), title: "Lab Report", courseCode: "BIO 101", courseName: "Biology", category: "Lab", dueDate: day3, estimatedMinutes: 120, status: .notStarted, urgency: .critical, weightPercent: 10, isLockedToDueDate: true, notes: "Need data from partner."),
            Assignment(id: UUID(), courseId: UUID(), title: "Essay Outline", courseCode: "ENG 210", courseName: "Literature", category: "Essay", dueDate: day1, estimatedMinutes: 60, status: .completed, urgency: .low, weightPercent: nil, isLockedToDueDate: false, notes: ""),
            Assignment(id: UUID(), courseId: UUID(), title: "Exam Prep", courseCode: "MA 231", courseName: "Calculus II", category: "Exam", dueDate: day2, estimatedMinutes: 180, status: .notStarted, urgency: .critical, weightPercent: 20, isLockedToDueDate: true, notes: "Create flashcards.")
        ]
    }
}
