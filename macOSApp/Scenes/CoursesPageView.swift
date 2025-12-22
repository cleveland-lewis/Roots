#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Models (namespaced to avoid clashing with existing Course model)

enum CoursesPageModel {
    struct Course: Identifiable, Hashable {
        let id: UUID
        var code: String
        var title: String
        var instructor: String
        var location: String
        var credits: Int
        var colorTag: ColorTag
        var semesterId: UUID?
        var semesterName: String
        var isArchived: Bool

        var meetingTimes: [CourseMeeting]
        var gradeInfo: CourseGradeInfo
        var syllabus: CourseSyllabus?
    }

    struct CourseMeeting: Identifiable, Hashable {
        let id: UUID
        var weekday: Int
        var startTime: Date
        var endTime: Date
        var type: String
    }

    struct CourseGradeInfo: Hashable {
        var currentPercentage: Double?
        var targetPercentage: Double?
        var letterGrade: String?
    }

    struct CourseSyllabus: Hashable {
        var categories: [SyllabusCategory]
        var notes: String
    }

    struct SyllabusCategory: Identifiable, Hashable {
        let id: UUID
        var name: String
        var weight: Double
    }


}

// Short aliases for readability inside this file
typealias CoursePageCourse = CoursesPageModel.Course
typealias CourseMeeting = CoursesPageModel.CourseMeeting
typealias CourseGradeInfo = CoursesPageModel.CourseGradeInfo
typealias CourseSyllabus = CoursesPageModel.CourseSyllabus
typealias SyllabusCategory = CoursesPageModel.SyllabusCategory


// MARK: - Root Page

struct CoursesPageView: View {
    @EnvironmentObject private var settings: AppSettingsModel
    @EnvironmentObject private var settingsCoordinator: SettingsCoordinator
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var timerManager: TimerManager
    @EnvironmentObject private var calendarManager: CalendarManager
    @EnvironmentObject private var gradesStore: GradesStore
    @EnvironmentObject private var plannerCoordinator: PlannerCoordinator
    @EnvironmentObject private var parsingStore: SyllabusParsingStore

    @State private var showingAddTaskSheet = false
    @State private var addTaskType: TaskType = .practiceHomework
    @State private var addTaskCourseId: UUID? = nil
    @State private var showingGradeSheet = false
    @State private var gradePercentInput: Double = 90
    @State private var gradeLetterInput: String = "A"
    @State private var showingParsedAssignmentsReview = false

    @State private var selectedCourseId: UUID? = nil
    @State private var searchText: String = ""
    @State private var showNewCourseSheet: Bool = false
    @State private var editingCourse: CoursePageCourse? = nil

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            GeometryReader { proxy in
                let width = proxy.size.width
                let isStacked = width < 820
                let ratios: (CGFloat, CGFloat) = {
                    if isStacked { return (1, 1) }
                    if width < 1200 { return (0.4, 0.6) }
                    return (1.0 / 3.0, 2.0 / 3.0)
                }()

                let sidebarWidth = isStacked ? width : max(240, width * ratios.0)

                if isStacked {
                    VStack(spacing: RootsSpacing.l) {
                        sidebarView
                            .frame(maxWidth: .infinity)
                            .layoutPriority(1)

                        rightColumn
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .layoutPriority(2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                } else {
                    HStack(alignment: .top, spacing: RootsSpacing.l) {
                        sidebarView
                            .frame(width: sidebarWidth)
                            .layoutPriority(1)

                        rightColumn
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .layoutPriority(2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .sheet(isPresented: $showNewCourseSheet) {
            CourseEditorSheet(course: editingCourse) { updated in
                persistCourse(updated)
                selectedCourseId = updated.id
            }
        }
        .sheet(isPresented: $showingAddTaskSheet) {
            AddAssignmentView(initialType: addTaskType, preselectedCourseId: addTaskCourseId) { task in
                assignmentsStore.addTask(task)
            }
            .environmentObject(coursesStore)
        }
        .sheet(isPresented: $showingGradeSheet) {
            gradeEntrySheet
        }
        .sheet(isPresented: $showingParsedAssignmentsReview) {
            if let courseId = selectedCourseId {
                ParsedAssignmentsReviewView(courseId: courseId)
                    .environmentObject(parsingStore)
                    .environmentObject(assignmentsStore)
                    .environmentObject(coursesStore)
            }
        }
        .onAppear {
            if selectedCourseId == nil {
                selectedCourseId = filteredCourses.first?.id
            }
        }
        .onChange(of: filteredCourses.count) { _, _ in
            guard let currentSelection = selectedCourseId else { return }
            if !filteredCourses.contains(where: { $0.id == currentSelection }) {
                selectedCourseId = filteredCourses.first?.id
            }
        }
    }

    private var sidebarView: some View {
        CoursesSidebarView(
            courses: filteredCourses,
            selectedCourse: $selectedCourseId,
            searchText: $searchText,
            onNewCourse: {
                editingCourse = nil
                showNewCourseSheet = true
            }
        )
        .rootsCardBackground(radius: RootsRadius.card)
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            if let course = currentSelection {
                CoursesPageDetailView(
                    course: course,
                    onEdit: {
                        editingCourse = course
                        showNewCourseSheet = true
                    },
                    onAddAssignment: {
                        beginAddTask(for: course, type: .practiceHomework)
                    },
                    onAddExam: {
                        beginAddTask(for: course, type: .exam)
                    },
                    onAddGrade: {
                        beginAddGrade(for: course)
                    },
                    onViewPlanner: {
                        openPlanner(for: course)
                    },
                    onReviewParsedAssignments: hasParsedAssignments(for: course) ? {
                        showingParsedAssignmentsReview = true
                    } : nil
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                emptyDetailState
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func placeholderModule(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: RootsSpacing.s) {
            Text(title)
                .rootsSectionHeader()
            Text(detail)
                .rootsBodySecondary()
        }
        .padding(RootsSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RootsRadius.card, style: .continuous)
                .fill(RootsColor.subtleFill)
        )
    }

    private var filteredCourses: [CoursePageCourse] {
        let active = liveCourses.filter { !$0.isArchived }
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return active }
        let query = searchText.lowercased()
        return active.filter { course in
            course.code.lowercased().contains(query) ||
            course.title.lowercased().contains(query) ||
            course.instructor.lowercased().contains(query)
        }
    }

    private var liveCourses: [CoursePageCourse] {
        coursesStore.activeCourses.map { vm(from: $0) }
    }

    private var currentSelection: CoursePageCourse? {
        guard let selectedCourseId else { return filteredCourses.first }
        return filteredCourses.first(where: { $0.id == selectedCourseId }) ?? filteredCourses.first
    }

    private func vm(from course: Course) -> CoursePageCourse {
        let semesterName = coursesStore.semesters.first(where: { $0.id == course.semesterId })?.name ?? "Current Term"
        let colorTag = ColorTag.fromHex(course.colorHex) ?? .blue
        let gradeEntry = gradesStore.grade(for: course.id)
        let gradeInfo = CourseGradeInfo(currentPercentage: gradeEntry?.percent, targetPercentage: nil, letterGrade: gradeEntry?.letter)
        return CoursePageCourse(
            id: course.id,
            code: course.code,
            title: course.title,
            instructor: course.instructor ?? "Instructor",
            location: course.location ?? "Location TBA",
            credits: Int(course.credits ?? 3),
            colorTag: colorTag,
            semesterId: course.semesterId,
            semesterName: semesterName,
            isArchived: course.isArchived,
            meetingTimes: [],
            gradeInfo: gradeInfo,
            syllabus: nil
        )
    }

    private func persistCourse(_ course: CoursePageCourse) {
        let semesterId = course.semesterId ?? ensureSemester()
        if let idx = coursesStore.courses.firstIndex(where: { $0.id == course.id }) {
            var existing = coursesStore.courses[idx]
            existing.code = course.code
            existing.title = course.title
            existing.instructor = course.instructor
            existing.location = course.location
            existing.credits = Double(course.credits)
            existing.semesterId = semesterId
            existing.isArchived = course.isArchived
            existing.colorHex = ColorTag.hex(for: course.colorTag)
            coursesStore.updateCourse(existing)
        } else {
            let newCourse = Course(
                id: course.id,
                title: course.title,
                code: course.code,
                semesterId: semesterId,
                colorHex: ColorTag.hex(for: course.colorTag),
                isArchived: course.isArchived,
                courseType: .regular,
                instructor: course.instructor,
                location: course.location,
                credits: Double(course.credits),
                creditType: .credits,
                meetingTimes: nil,
                syllabus: nil,
                notes: nil,
                attachments: []
            )
            coursesStore.addCourse(newCourse)
        }

        if coursesStore.currentSemesterId == nil {
            coursesStore.currentSemesterId = semesterId
        }
    }

    private func ensureSemester() -> UUID {
        if let current = coursesStore.currentSemesterId {
            return current
        }
        if let first = coursesStore.semesters.first {
            coursesStore.currentSemesterId = first.id
            return first.id
        }

        let calendar = Calendar.current
        let now = Date()
        let end = calendar.date(byAdding: .month, value: 4, to: now) ?? now
        let defaultSemester = Semester(
            startDate: now,
            endDate: end,
            isCurrent: true,
            educationLevel: .college,
            semesterTerm: .fall,
            academicYear: "\(calendar.component(.year, from: now))-\(calendar.component(.year, from: end))"
        )
        coursesStore.addSemester(defaultSemester)
        coursesStore.currentSemesterId = defaultSemester.id
        return defaultSemester.id
    }

    private func beginAddTask(for course: CoursePageCourse, type: TaskType) {
        selectedCourseId = course.id
        addTaskCourseId = course.id
        addTaskType = type
        showingAddTaskSheet = true
    }

    private func beginAddGrade(for course: CoursePageCourse) {
        selectedCourseId = course.id
        gradePercentInput = gradesStore.grade(for: course.id)?.percent ?? 90
        gradeLetterInput = gradesStore.grade(for: course.id)?.letter ?? "A"
        showingGradeSheet = true
    }

    private func openPlanner(for course: CoursePageCourse) {
        selectedCourseId = course.id
        plannerCoordinator.openPlanner(with: course.id)
    }
    
    private func hasParsedAssignments(for course: CoursePageCourse) -> Bool {
        return !parsingStore.parsedAssignmentsByCourse(course.id).isEmpty
    }

    private var emptyDetailState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.secondary)
            Text(NSLocalizedString("courses.empty.select", comment: "Select course"))
                .font(DesignSystem.Typography.subHeader)
            Text(NSLocalizedString("courses.empty.overview", comment: "Overview"))
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar

struct CoursesSidebarView: View {
    @EnvironmentObject private var settingsCoordinator: SettingsCoordinator

    var courses: [CoursePageCourse]
    @Binding var selectedCourse: UUID?
    @Binding var searchText: String
    var onNewCourse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            VStack(alignment: .leading, spacing: 4) {
                Text("Courses")
                    .font(DesignSystem.Typography.body)
                Text(currentTerm)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 8)

            TextField("Search courses", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            // Scrollable Course List
            ScrollView {
                VStack(spacing: DesignSystem.Layout.spacing.small) {
                    ForEach(courses) { course in
                        CourseSidebarRow(course: course, isSelected: selectedCourse == course.id) {
                            selectedCourse = course.id
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .frame(maxHeight: .infinity) // Allow scroll to expand

            // Bottom Action Buttons (Pinned)
            VStack(spacing: 0) {
                Divider()
                    .padding(.vertical, 8)
                
                HStack(spacing: RootsSpacing.s) {
                    Button {
                        onNewCourse()
                    } label: {
                        Label("New Course", systemImage: "plus")
                            .font(DesignSystem.Typography.body)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .glassChrome(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)

                    Button {
                        settingsCoordinator.show(selecting: .courses)
                    } label: {
                        Label("Edit Courses", systemImage: "pencil")
                            .font(DesignSystem.Typography.body)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .glassChrome(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, RootsSpacing.m)
                .padding(.bottom, RootsSpacing.m)
            }
        }
        .frame(maxHeight: .infinity)
        .glassCard(cornerRadius: 22)
    }

    private var currentTerm: String {
        courses.first?.semesterName ?? "Current Term"
    }
}

struct CourseSidebarRow: View {
    var course: CoursePageCourse
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Layout.spacing.small) {
                Circle()
                    .fill(course.colorTag.color.opacity(0.9))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.code)
                        .rootsBody()
                        .lineLimit(1)
                    Text(course.title)
                        .rootsCaption()
                        .foregroundColor(RootsColor.textSecondary)
                        .lineLimit(1)
                    Text(course.instructor)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                GradeChip(gradeInfo: course.gradeInfo)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.accentColor.opacity(0.14)
                        : Color(nsColor: .controlBackgroundColor).opacity(0.12)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected
                        ? Color.accentColor.opacity(0.35)
                        : Color(nsColor: .separatorColor).opacity(0.18),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel("\(course.code), \(course.title)")
    }
}

// MARK: - Detail

struct CoursesPageDetailView: View {
    let course: CoursePageCourse
    var onEdit: () -> Void
    var onAddAssignment: () -> Void
    var onAddExam: () -> Void
    var onAddGrade: () -> Void
    var onViewPlanner: () -> Void
    var onReviewParsedAssignments: (() -> Void)? = nil

    private let cardCorner: CGFloat = 24

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                HStack(alignment: .top, spacing: 16) {
                    meetingsCard
                    syllabusCard
                }
                quickActionsCard
            }
            .padding(.trailing, 6)
            .padding(.vertical, 12)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(course.code)
                        .font(DesignSystem.Typography.subHeader)
                        .foregroundStyle(.secondary)
                    Text(course.title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    GradeRing(gradeInfo: course.gradeInfo)
                    Button("Edit") { onEdit() }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
                        .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                Label(course.instructor, systemImage: "person")
                Label(course.location, systemImage: "mappin.and.ellipse")
                Label("\(course.credits) credits", systemImage: "number")
                Label(course.semesterName, systemImage: "calendar")
            }
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(.thinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .overlay(cardStroke)
    }

    private var meetingsCard: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            sectionHeader("Meetings")

            if course.meetingTimes.isEmpty {
                VStack(alignment: .leading, spacing: RootsSpacing.s) {
                    Text(NSLocalizedString("courses.empty.no_meetings", comment: "No meetings"))
                        .rootsBodySecondary()

                }
            } else {
                VStack(alignment: .leading, spacing: RootsSpacing.s) {
                    ForEach(course.meetingTimes) { meeting in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(weekdayName(meeting.weekday)) · \(timeRange(for: meeting))")
                                .font(DesignSystem.Typography.body)
                            Text(meeting.type)
                                .rootsCaption()
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                }
            }
        }
        .padding(RootsSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(.thinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .overlay(cardStroke)
    }

    private var syllabusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Syllabus")
            if let syllabus = course.syllabus {
                VStack(spacing: DesignSystem.Layout.spacing.small) {
                    ForEach(syllabus.categories) { category in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(category.name)
                                    .font(DesignSystem.Typography.body)
                                Spacer()
                                Text("\(Int(category.weight))%")
                                    .font(.caption.weight(.semibold))
                            }
                            ProgressView(value: min(max(category.weight / 100, 0), 1))
                                .progressViewStyle(.linear)
                                .tint(.accentColor)
                        }
                    }
                }

                Text(syllabus.notes)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("courses.empty.no_syllabus", comment: "No syllabus"))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                    Text("You’ll eventually be able to import this from a syllabus parser.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DesignSystem.Layout.padding.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(.thinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .overlay(cardStroke)
    }

    private var quickActionsCard: some View {
        RootsCard(title: "Quick Actions") {
            HStack(spacing: RootsSpacing.m) {
                quickActionTile(
                    title: "Add Assignment",
                    subtitle: "Create a new assignment for this course",
                    systemImage: "doc.badge.plus",
                    action: onAddAssignment
                )

                quickActionTile(
                    title: "Add Exam",
                    subtitle: "Schedule an exam or quiz",
                    systemImage: "calendar.badge.clock",
                    action: onAddExam
                )

                quickActionTile(
                    title: "Add Grade",
                    subtitle: "Log a grade for this course",
                    systemImage: "checkmark.seal",
                    action: onAddGrade
                )

                quickActionTile(
                    title: "View Plan for Course",
                    subtitle: "Open Planner with this course filtered",
                    systemImage: "list.bullet.rectangle",
                    action: onViewPlanner
                )
                
                if let reviewAction = onReviewParsedAssignments {
                    quickActionTile(
                        title: "Review Parsed Assignments",
                        subtitle: "Import assignments from syllabus parsing",
                        systemImage: "doc.text.magnifyingglass",
                        action: reviewAction
                    )
                }
            }
        }
    }

    private func quickActionTile(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: RootsSpacing.m) {
                Image(systemName: systemImage)
                    .font(DesignSystem.Typography.body)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.white)
                    .background(
                        Circle()
                            .fill(RootsColor.accent.opacity(0.9))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .rootsBody()
                        .foregroundStyle(RootsColor.textPrimary)

                    Text(subtitle)
                        .rootsCaption()
                        .foregroundStyle(RootsColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(RootsLiquidButtonStyle(cornerRadius: 14, verticalPadding: RootsSpacing.m, horizontalPadding: RootsSpacing.m))
    }


    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DesignSystem.Typography.body)
    }

    private var cardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let index = max(1, min(weekday, symbols.count)) - 1
        return symbols[index]
    }

    private func timeRange(for meeting: CourseMeeting) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: meeting.startTime))–\(formatter.string(from: meeting.endTime))"
    }

    private func openCalendar(for meeting: CourseMeeting?) {
        #if os(macOS)
        guard let meeting = meeting else {
            // No meeting found, open Calendar app normally
            let calendarURL = URL(fileURLWithPath: "/Applications/Calendar.app")
            NSWorkspace.shared.open(calendarURL)
            return
        }

        // Calculate the next occurrence of this weekday
        let calendar = Calendar.current
        let now = Date()

        // Get the current weekday (1 = Sunday in Calendar, but meeting.weekday might be 0-indexed)
        // Assuming meeting.weekday is 1-7 where 1 = Sunday (matching Calendar.component)
        let targetWeekday = meeting.weekday
        let currentWeekday = calendar.component(.weekday, from: now)

        // Calculate days until next occurrence
        var daysUntil = targetWeekday - currentWeekday
        if daysUntil <= 0 {
            daysUntil += 7
        }

        // Get the target date
        guard let targetDate = calendar.date(byAdding: .day, value: daysUntil, to: now) else {
            // Fallback to opening Calendar normally
            let calendarURL = URL(fileURLWithPath: "/Applications/Calendar.app")
            NSWorkspace.shared.open(calendarURL)
            return
        }

        // Combine target date with meeting start time
        let meetingComponents = calendar.dateComponents([.hour, .minute], from: meeting.startTime)
        let targetComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)

        var finalComponents = DateComponents()
        finalComponents.year = targetComponents.year
        finalComponents.month = targetComponents.month
        finalComponents.day = targetComponents.day
        finalComponents.hour = meetingComponents.hour
        finalComponents.minute = meetingComponents.minute

        guard let finalDate = calendar.date(from: finalComponents) else {
            let calendarURL = URL(fileURLWithPath: "/Applications/Calendar.app")
            NSWorkspace.shared.open(calendarURL)
            return
        }

        // Open Calendar at the specific date
        let interval = finalDate.timeIntervalSinceReferenceDate
        if let calendarURL = URL(string: "calshow:\(interval)") {
            NSWorkspace.shared.open(calendarURL)
        }
        #endif
    }
}

// MARK: - Notifications for quick actions

extension Notification.Name {
    // Legacy Notification names removed — use PlannerCoordinator and Combine publishers instead
}

// MARK: - Grade chips/rings

struct GradeChip: View {
    var gradeInfo: CourseGradeInfo

    var body: some View {
        HStack(spacing: 6) {
            if let current = gradeInfo.currentPercentage {
                Text("\(Int(current))%")
                    .font(.caption.weight(.semibold))
                if let letter = gradeInfo.letterGrade {
                    Text(letter)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No grade yet")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
    }
}

struct GradeRing: View {
    var gradeInfo: CourseGradeInfo

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(nsColor: .separatorColor).opacity(0.08), lineWidth: 6)
                .frame(width: 64, height: 64)

            if let current = gradeInfo.currentPercentage {
                Circle()
                    .trim(from: 0, to: min(max(current / 100, 0), 1))
                    .stroke(AngularGradient(gradient: Gradient(colors: [.accentColor, .accentColor.opacity(0.5)]), center: .center), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 64, height: 64)

                VStack(spacing: 2) {
                    Text("\(Int(current))%")
                        .font(DesignSystem.Typography.body)
                    Text("Current")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 2) {
                    Text("—")
                        .font(DesignSystem.Typography.body)
                    Text("No grade")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Color tag picker

struct ColorTagPicker: View {
    @Binding var selected: ColorTag
    @EnvironmentObject private var appSettings: AppSettingsModel

    var body: some View {
        HStack(spacing: DesignSystem.Layout.spacing.small) {
            ForEach(ColorTag.allCases) { tag in
                Button {
                    selected = tag
                } label: {
                    Circle()
                        .fill(tag.color.opacity(0.95))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(selected == tag ? .accentColor : Color(nsColor: .separatorColor).opacity(0.12), lineWidth: selected == tag ? 3 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Editor Sheet (System Settings style)

struct CourseEditorSheet: View {
    @EnvironmentObject private var coursesStore: CoursesStore
    @Environment(\.dismiss) private var dismiss

    var course: CoursePageCourse?
    var onSave: (CoursePageCourse) -> Void

    @State private var code: String = ""
    @State private var title: String = ""
    @State private var instructor: String = ""
    @State private var instructorEmail: String = ""
    @State private var location: String = ""
    @State private var credits: Int = 3
    @State private var semesterId: UUID? = nil
    @State private var semesterName: String = ""
    @State private var colorTag: ColorTag = .blue

    private var isNew: Bool { course == nil }
    private var isSaveDisabled: Bool {
        code.trimmingCharacters(in: .whitespaces).isEmpty ||
        title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        RootsPopupContainer(
            title: isNew ? "New Course" : "Edit Course",
            subtitle: "Courses will sync with Planner, Assignments, and Grades."
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: RootsSpacing.l) {
                    courseSection
                    detailsSection
                }
            }
        } footer: {
            actionBar
        }
        .frame(maxWidth: 580, maxHeight: 420)
        .frame(minWidth: RootsWindowSizing.minPopupWidth, minHeight: RootsWindowSizing.minPopupHeight)
        .onAppear(perform: loadDraft)
        .onChange(of: semesterId) { _, newValue in
            if let id = newValue, let match = coursesStore.semesters.first(where: { $0.id == id }) {
                semesterName = match.name
            }
        }
    }

    private var courseSection: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            Text(NSLocalizedString("courses.section.course", comment: "Course")).rootsSectionHeader()
            RootsFormRow(label: "Code") {
                TextField("e.g. BIO 101", text: $code)
                    .frame(width: 120)
                    .textFieldStyle(.roundedBorder)
            }
            .validationHint(isInvalid: code.trimmingCharacters(in: .whitespaces).isEmpty, text: "Course code is required.")

            RootsFormRow(label: "Title") {
                TextField("Biology 101", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            .validationHint(isInvalid: title.trimmingCharacters(in: .whitespaces).isEmpty, text: "Course title is required.")

            RootsFormRow(label: "Instructor") {
                TextField("Dr. Smith", text: $instructor)
                    .textFieldStyle(.roundedBorder)
            }

            RootsFormRow(label: "Email") {
                TextField("name@university.edu", text: $instructorEmail)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
            }

            RootsFormRow(label: "Location") {
                TextField("Appleseed Hall 203", text: $location)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            Text(NSLocalizedString("courses.section.details", comment: "Details")).rootsSectionHeader()
            RootsFormRow(label: "Credits") {
                Stepper(value: $credits, in: 1...8) {
                    Text("\(credits)")
                }
                .frame(width: 120, alignment: .leading)
            }

            RootsFormRow(label: "Semester") {
                SemesterPicker(selectedSemesterId: $semesterId)
                    .frame(maxWidth: 260)
                    .environmentObject(coursesStore)
            }

            RootsFormRow(label: "Color") {
                ColorTagPicker(selected: $colorTag)
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Text(NSLocalizedString("courses.info.edit_later", comment: "Edit later"))
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
            Button("Cancel") { dismiss() }
            Button(isNew ? "Create" : "Save") {
                let resolvedSemesterName: String = {
                    if let id = semesterId, let match = coursesStore.semesters.first(where: { $0.id == id }) {
                        return match.name
                    }
                    return semesterName.isEmpty ? "Current Term" : semesterName
                }()

                let newCourse = CoursePageCourse(
                    id: course?.id ?? UUID(),
                    code: code,
                    title: title,
                    instructor: instructor.isEmpty ? "TBD" : instructor,
                    location: location.isEmpty ? "TBD" : location,
                    credits: credits,
                    colorTag: colorTag,
                    semesterId: semesterId,
                    semesterName: resolvedSemesterName,
                    isArchived: course?.isArchived ?? false,
                    meetingTimes: course?.meetingTimes ?? [],
                    gradeInfo: course?.gradeInfo ?? CourseGradeInfo(currentPercentage: nil, targetPercentage: 92, letterGrade: nil),
                    syllabus: course?.syllabus
                )
                onSave(newCourse)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isSaveDisabled)
        }
    }

    private func loadDraft() {
        if let course {
            code = course.code
            title = course.title
            instructor = course.instructor
            instructorEmail = "" // Populate when email is available in model
            location = course.location
            credits = course.credits
            semesterId = course.semesterId
            semesterName = course.semesterName
            colorTag = course.colorTag
        } else {
            if let current = coursesStore.currentSemesterId ?? coursesStore.semesters.first?.id,
               let match = coursesStore.semesters.first(where: { $0.id == current }) {
                semesterId = match.id
                semesterName = match.name
            }
        }
    }
}

private extension View {
    func validationHint(isInvalid: Bool, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            self
            if isInvalid {
                Text(text)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Sample Data

private extension CoursesPageView {}

// MARK: - Grade Entry Sheet

private extension CoursesPageView {
    var gradeEntrySheet: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            Text("Add Grade for \(currentSelection?.code ?? "Course")")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: RootsSpacing.s) {
                Text(NSLocalizedString("courses.grade.percentage", comment: "Percentage"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $gradePercentInput, in: 0...100, step: 1)
                HStack {
                    Text("\(Int(gradePercentInput))%")
                    Spacer()
                    TextField("Letter", text: $gradeLetterInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    showingGradeSheet = false
                }
                Button("Save") {
                    if let courseId = currentSelection?.id {
                        gradesStore.upsert(courseId: courseId, percent: gradePercentInput, letter: gradeLetterInput.isEmpty ? nil : gradeLetterInput)
                    }
                    showingGradeSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }
}
#endif
