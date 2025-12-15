#if os(macOS)
import SwiftUI
import Combine

// MARK: - Models

struct GradeCourseSummary: Identifiable, Hashable {
    let id: UUID
    var courseCode: String
    var courseTitle: String
    var currentPercentage: Double?
    var targetPercentage: Double?
    var letterGrade: String?
    var creditHours: Int
    var colorTag: Color
}

struct GradeComponent: Identifiable, Hashable {
    let id: UUID
    var name: String
    var weightPercent: Double
    var earnedPercent: Double?
}

struct CourseGradeDetail: Identifiable, Hashable {
    let id: UUID
    var course: GradeCourseSummary
    var components: [GradeComponent]
    var notes: String
}

// MARK: - Root View

struct GradesPageView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var gradesStore: GradesStore

    @State private var allCourses: [GradeCourseSummary] = []
    @State private var courseDetails: [CourseGradeDetail] = []
    @State private var selectedCourseDetail: CourseGradeDetail? = nil
    @State private var searchText: String = ""
    @AppStorage("grades.gpaScale") private var gpaScale: Double = 4.0
    @State private var showEditTargetSheet: Bool = false
    @State private var courseToEditTarget: GradeCourseSummary? = nil
    @State private var whatIfSlider: Double = 90
    @State private var showAddGradeSheet: Bool = false
    @State private var gradeAnalyticsWindowOpen: Bool = false
    @State private var showNewCourseSheet: Bool = false
    @State private var editingCourse: Course? = nil
    @State private var courseDeletedCancellable: AnyCancellable? = nil

    private let cardCorner: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    header

                    adaptiveColumns(width: proxy.size.width)
                }
                .padding(16)
            }
            .rootsSystemBackground()
        }
        .sheet(isPresented: $showEditTargetSheet) {
            if let course = courseToEditTarget, let detail = courseDetails.first(where: { $0.id == course.id }) {
                EditTargetGradeSheet(course: course, detail: detail) { updatedTarget, letter, components in
                    updateTarget(for: course, to: updatedTarget, letter: letter, components: components)
                }
            }
        }
        .sheet(isPresented: $showNewCourseSheet) {
            let editorModel = editingCourse.flatMap(courseEditorModel(from:))
            CourseEditorSheet(course: editorModel) { updated in
                persistCourseEditorModel(updated)
                editingCourse = nil
                refreshCourses()
            }
        }
        .sheet(isPresented: $showAddGradeSheet) {
            AddGradeSheet(
                assignments: assignmentsStore.tasks,
                courses: allCourses,
                onSave: { updatedTask in
                    assignmentsStore.updateTask(updatedTask)
                    persistGrade(for: updatedTask)
                }
            )
        }
        .sheet(isPresented: $gradeAnalyticsWindowOpen) {
            VStack(spacing: 16) {
                Text("Grade Analytics")
                    .font(.title2.weight(.semibold))
                Text("Placeholder window. Integrate analytics dashboard here.")
                    .foregroundStyle(.secondary)
                Button("Close") { gradeAnalyticsWindowOpen = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(minWidth: 360, minHeight: 240)
        }
        .onAppear {
            refreshCourses()
            requestGPARecalc()

            // Subscribe to course deletions
            courseDeletedCancellable = CoursesStore.courseDeletedPublisher
                .receive(on: DispatchQueue.main)
                .sink { deletedId in
                    gradesStore.remove(courseId: deletedId)
                    refreshCourses()
                    if let selected = selectedCourseDetail, selected.id == deletedId {
                        selectedCourseDetail = nil
                    }
                }
        }
        .onReceive(assignmentsStore.$tasks) { _ in
            requestGPARecalc()
        }
        .onReceive(coursesStore.$courses) { _ in
            refreshCourses()
        }
        .onReceive(gradesStore.$grades) { _ in
            refreshCourses()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Grades")
                .font(.title2.weight(.semibold))

            Spacer()


            TextField("Search courses", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)

            Button {
                // stub export/share functionality
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Share or export grades")
        }
    }

    // MARK: Columns

    @ViewBuilder
    private func adaptiveColumns(width: CGFloat) -> some View {
        let isCompact = width < 1100

        if isCompact {
            VStack(spacing: 16) {
                overallColumn
                courseListCard
                detailCard
            }
        } else {
            let spacing: CGFloat = 22
            let overallWidth = max(280, width * 0.22)
            let courseWidth = max(340, width * 0.34)

            HStack(alignment: .top, spacing: spacing) {
                overallColumn
                    .frame(width: overallWidth)
                courseListCard
                    .frame(width: courseWidth)
                detailCard
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var overallColumn: some View {
        VStack(spacing: 12) {
            GPABreakdownCard(
                currentGPA: coursesStore.currentGPA,
                academicYearGPA: coursesStore.currentGPA,
                cumulativeGPA: coursesStore.currentGPA,
                isLoading: gradesStore.isLoading,
                courseCount: coursesStore.activeCourses.count
            )
            HStack(spacing: 12) {
                Button {
                    showAddGradeSheet = true
                } label: {
                    Label("Add Grade", systemImage: "plus.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    gradeAnalyticsWindowOpen = true
                    // Placeholder: open analytics window
                    print("Analytics tapped")
                } label: {
                    Label("Analytics", systemImage: "chart.bar.xaxis")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var courseListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Courses")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Picker("Sort", selection: .constant(0)) {
                    Text("Course").tag(0)
                    Text("Grade").tag(1)
                    Text("Credits").tag(2)
                }
                .pickerStyle(.menu)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(filteredCourses) { course in
                        CourseGradeRow(
                            course: course,
                            isSelected: course.id == selectedCourseDetail?.course.id,
                            isScenarioHighlight: false,
                            onSelect: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    selectedCourseDetail = courseDetails.first(where: { $0.course.id == course.id })
                                }
                            },
                            onEditTarget: {
                                courseToEditTarget = course
                                showEditTargetSheet = true
                            },
                            onEditCourse: {
                                // find full Course model and present editor
                                if let full = coursesStore.courses.first(where: { $0.id == course.id }) {
                                    editingCourse = full
                                    showNewCourseSheet = true
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardStroke)
    }

    private var detailCard: some View {
        VStack(spacing: 16) {
            GradeDetailCard(
                detail: Binding(
                    get: { selectedCourseDetail },
                    set: { selectedCourseDetail = $0 }
                ),
                whatIfInput: $whatIfSlider,
                gpaScale: gpaScale,
                onEditTarget: { course in
                    courseToEditTarget = course
                    showEditTargetSheet = true
                },
                onUpdateNotes: { updated in
                    if let idx = courseDetails.firstIndex(where: { $0.id == updated.id }) {
                        courseDetails[idx] = updated
                        if selectedCourseDetail?.id == updated.id {
                            selectedCourseDetail = updated
                        }
                    }
                }
            )
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardStroke)
    }



    // MARK: Helpers

    private var filteredCourses: [GradeCourseSummary] {
        let hydrated = allCourses.map { course -> GradeCourseSummary in
            var updated = course
            if let pct = GradeCalculator.calculateCourseGrade(courseID: course.id, tasks: assignmentsStore.tasks) {
                updated.currentPercentage = pct
            }
            return updated
        }

        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return hydrated }
        let q = searchText.lowercased()
        return hydrated.filter { course in
            course.courseCode.lowercased().contains(q) || course.courseTitle.lowercased().contains(q)
        }
    }

    private func isNearThreshold(_ course: GradeCourseSummary) -> Bool {
        guard let percent = course.currentPercentage else { return false }
        let fractional = percent.truncatingRemainder(dividingBy: 10)
        return fractional >= 7
    }

    private func updateTarget(for course: GradeCourseSummary, to target: Double?, letter: String?, components: [GradeComponent]) {
        // Update course summary
        if let idx = allCourses.firstIndex(where: { $0.id == course.id }) {
            allCourses[idx].targetPercentage = target
            allCourses[idx].letterGrade = letter ?? allCourses[idx].letterGrade
        }
        // Update detail and components
        if let detailIdx = courseDetails.firstIndex(where: { $0.course.id == course.id }) {
            courseDetails[detailIdx].course.targetPercentage = target
            courseDetails[detailIdx].course.letterGrade = letter ?? courseDetails[detailIdx].course.letterGrade
            courseDetails[detailIdx].components = components
            selectedCourseDetail = courseDetails[detailIdx]
        }
    }

    private func refreshCourses() {
        let summaries = coursesStore.activeCourses.map { course in
            let grade = gradesStore.grade(for: course.id)
            return GradeCourseSummary(
                id: course.id,
                courseCode: course.code,
                courseTitle: course.title,
                currentPercentage: grade?.percent,
                targetPercentage: nil,
                letterGrade: grade?.letter,
                creditHours: Int(course.credits ?? 0),
                colorTag: colorTag(for: course.colorHex)
            )
        }
        allCourses = summaries
        courseDetails = summaries.map { summary in
            return CourseGradeDetail(
                id: summary.id,
                course: summary,
                components: [],
                notes: "Add grade components to see breakdown."
            )
        }
        if selectedCourseDetail == nil {
            selectedCourseDetail = courseDetails.first
        } else if let current = selectedCourseDetail, !courseDetails.contains(where: { $0.id == current.id }) {
            selectedCourseDetail = courseDetails.first
        }
    }

    private func requestGPARecalc() {
        Task { @MainActor in
            coursesStore.recalcGPA(tasks: assignmentsStore.tasks)
        }
    }

    private func persistGrade(for task: AppTask) {
        guard let courseId = task.courseId,
              let earned = task.gradeEarnedPoints,
              let possible = task.gradePossiblePoints,
              possible > 0 else { return }

        let percent = (earned / possible) * 100
        let letter = GradeCalculator.letterGrade(for: percent)
        gradesStore.upsert(courseId: courseId, percent: percent, letter: letter)
        requestGPARecalc()
    }

    private func colorTag(for hex: String?) -> Color {
        (ColorTag.fromHex(hex) ?? .blue).color
    }

    private func courseEditorModel(from course: Course) -> CoursesPageModel.Course {
        let semesterName = coursesStore.semesters.first(where: { $0.id == course.semesterId })?.name ?? "Current Term"
        let colorTag = ColorTag.fromHex(course.colorHex) ?? .blue
        let gradeEntry = gradesStore.grade(for: course.id)
        let gradeInfo = CoursesPageModel.CourseGradeInfo(
            currentPercentage: gradeEntry?.percent,
            targetPercentage: nil,
            letterGrade: gradeEntry?.letter
        )

        return CoursesPageModel.Course(
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

    private func persistCourseEditorModel(_ course: CoursesPageModel.Course) {
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
        if let current = coursesStore.currentSemesterId { return current }
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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cardCorner, style: .continuous).fill(.thinMaterial)
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
    }
}

// MARK: - Overall Status

struct OverallStatusCard: View {
    var courses: [GradeCourseSummary]
    var gpaScale: Double
    var emphasize: Bool

    var body: some View {
        let overallPercent = weightedOverallPercent
        let gpa = gpaValue(overallPercent: overallPercent)
        VStack(alignment: .leading, spacing: 10) {
            Text("Overall Status")
                .font(.system(size: 14, weight: .semibold))

            Text("GPA \(String(format: "%.2f", gpa)) / \(String(format: "%.1f", gpaScale))")
                .font(.system(size: emphasize ? 28 : 24, weight: .bold))

            Text("Weighted \(String(format: "%.1f", overallPercent))% • \(courses.count) courses")
                .font(.footnote)
                .foregroundColor(.secondary)

            ProgressView(value: overallPercent / 100)
                .progressViewStyle(.linear)

            HStack {
                if let maxCourse = courses.max(by: { ($0.currentPercentage ?? 0) < ($1.currentPercentage ?? 0) }) {
                    Text("Highest: \(maxCourse.courseCode) \(Int(maxCourse.currentPercentage ?? 0))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let minCourse = courses.min(by: { ($0.currentPercentage ?? 0) < ($1.currentPercentage ?? 0) }) {
                    Text("Lowest: \(minCourse.courseCode) \(Int(minCourse.currentPercentage ?? 0))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private var weightedOverallPercent: Double {
        let totalCredits = courses.reduce(0) { $0 + $1.creditHours }
        guard totalCredits > 0 else { return 0 }
        let weighted = courses.reduce(0.0) { partial, course in
            let pct = course.currentPercentage ?? 0
            return partial + pct * Double(course.creditHours)
        }
        return weighted / Double(totalCredits)
    }

    private func gpaValue(overallPercent: Double) -> Double {
        // Simple linear mapping: 90-100 -> 4.0, 80-89 -> 3.0, etc.
        let scaled = (overallPercent / 100) * gpaScale
        return min(gpaScale, max(0, scaled))
    }
}

// MARK: - Course Row

struct CourseGradeRow: View {
    var course: GradeCourseSummary
    var isSelected: Bool
    var isScenarioHighlight: Bool
    var onSelect: () -> Void
    var onEditTarget: () -> Void
    var onEditCourse: (() -> Void)? = nil

    private var ringColor: Color { course.colorTag }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(ringColor)
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(course.courseCode) · \(course.courseTitle)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let pct = course.currentPercentage {
                            Text("\(String(format: "%.1f", pct))%")
                        } else {
                            Text("No grade yet")
                        }
                        if let letter = course.letterGrade { Text("· \(letter)") }
                        Text("· \(course.creditHours) credits")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    ring
                    if let target = course.targetPercentage {
                        Text("Target \(Int(target))%")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color(nsColor: .controlAccentColor).opacity(0.12) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isScenarioHighlight ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit Target") { onEditTarget() }
            if let onEditCourse = onEditCourse {
                Button("Edit Course") { onEditCourse() }
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                .frame(width: 44, height: 44)
            if let pct = course.currentPercentage {
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(pct / 100, 0), 1)))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                Text("\(Int(pct))%")
                    .font(.caption2.weight(.semibold))
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Detail Card

struct GradeDetailCard: View {
    @Binding var detail: CourseGradeDetail?
    @Binding var whatIfInput: Double
    var gpaScale: Double
    var onEditTarget: (GradeCourseSummary) -> Void
    var onUpdateNotes: (CourseGradeDetail) -> Void

    var body: some View {
        if let detail {
            VStack(alignment: .leading, spacing: 12) {
                header(detail.course)
                components(detail.components)
                notes(detail)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Select a course from the center panel to see its grade breakdown.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func header(_ course: GradeCourseSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Grade Components – \(course.courseCode)")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("GPA Scale: \(String(format: "%.1f", gpaScale))")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            Text(course.courseTitle)
                .font(.headline)
            HStack(spacing: 8) {
                if let current = course.currentPercentage {
                    Text("Current: \(String(format: "%.1f", current))%")
                } else { Text("Current: —") }
                if let target = course.targetPercentage {
                    Text("· Target: \(Int(target))%")
                }
                if let letter = course.letterGrade { Text("· \(letter)") }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Button("Edit target") {
                onEditTarget(course)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private func components(_ components: [GradeComponent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(components) { comp in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comp.name)
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        if let earned = comp.earnedPercent {
                            Text("\(Int(earned))%")
                                .font(.caption.weight(.semibold))
                        } else {
                            Text("No data yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("Weight: \(Int(comp.weightPercent))%")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let earned = comp.earnedPercent {
                        ProgressView(value: min(max(earned / 100, 0), 1))
                            .tint(progressColor(earned))
                    }
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    private func progressColor(_ percent: Double) -> Color {
        switch percent {
        case ..<70: return .red
        case 70..<85: return .yellow
        default: return .green
        }
    }

    private func whatIf(_ detail: CourseGradeDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What-If Scenario")
                .font(.system(size: 14, weight: .semibold))
            Slider(value: $whatIfInput, in: 50...100, step: 1) {
                Text("Expected average on remaining work")
            }
            Text("If you score \(Int(whatIfInput))% on remaining work, your projected final grade is \(String(format: "%.1f", projectedGrade(detail)))%.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private func projectedGrade(_ detail: CourseGradeDetail) -> Double {
        // Simplistic blend: average known earnedPercent weighted, remaining weight uses whatIfInput
        let knownWeight = detail.components.reduce(0) { $0 + ($1.earnedPercent == nil ? 0 : $1.weightPercent) }
        let knownScore = detail.components.reduce(0) { partial, comp in
            guard let earned = comp.earnedPercent else { return partial }
            return partial + earned * (comp.weightPercent / 100)
        }
        let remainingWeight = max(0, 100 - knownWeight)
        let projected = knownScore + whatIfInput * (remainingWeight / 100)
        return projected
    }

    private func notes(_ detail: CourseGradeDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(.system(size: 14, weight: .semibold))
            TextEditor(text: Binding(
                get: { detail.notes },
                set: { newValue in
                    var updated = detail
                    updated.notes = newValue
                    onUpdateNotes(updated)
                    self.detail = updated
                }
            ))
            .frame(minHeight: 120)
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
}

// MARK: - Edit Target Sheet

struct EditTargetGradeSheet: View {
    var course: GradeCourseSummary
    var detail: CourseGradeDetail
    var onSave: (Double?, String?, [GradeComponent]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var targetPercent: Double = 90
    @State private var letter: String = "A"
    @State private var components: [GradeComponent] = []

    private let letters = ["A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D", "F"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Target") {
                    Slider(value: $targetPercent, in: 0...100, step: 1) {
                        Text("Target %")
                    }
                    Text("\(Int(targetPercent))%")
                        .font(.headline)
                }

                Section("Components") {
                    VStack(spacing: 8) {
                        ForEach($components) { $comp in
                            HStack(spacing: 8) {
                                TextField("Name", text: Binding(get: { comp.name }, set: { comp.name = $0 }))
                                    .frame(width: 140)
                                Stepper(value: Binding(get: { Int(comp.weightPercent) }, set: { comp.weightPercent = Double($0) }), in: 0...100) {
                                    Text("\(Int(comp.weightPercent))%")
                                }
                                Slider(value: Binding(get: { comp.earnedPercent ?? 0 }, set: { comp.earnedPercent = $0 }), in: 0...100)
                                    .frame(maxWidth: 160)
                                TextField("\(Int(comp.earnedPercent ?? 0))%", text: Binding(get: { String(Int(comp.earnedPercent ?? 0)) }, set: { comp.earnedPercent = Double($0) ?? comp.earnedPercent }))
                                    .frame(width: 50)
                                Button(role: .destructive) { components.removeAll(where: { $0.id == comp.id }) } label: { Image(systemName: "trash") }
                            }
                        }

                        Button { components.append(GradeComponent(id: UUID(), name: "New", weightPercent: 0, earnedPercent: nil)) } label: {
                            Label("Add Component", systemImage: "plus")
                        }
                    }
                }

                Section("Letter") {
                    Picker("Letter", selection: $letter) {
                        ForEach(letters, id: \.self) { l in
                            Text(l).tag(l)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text("Targets help scenario calculations and visual indicators. This does not affect official grades.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Target for \(course.courseCode)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(targetPercent, letter, components)
                        dismiss()
                    }
                }
            }
            .onAppear {
                targetPercent = course.targetPercentage ?? 90
                letter = course.letterGrade ?? "A"
                components = detail.components
            }
        }
    }
}

// MARK: - Samples

private extension GradesPageView {
    static var sampleCourses: [GradeCourseSummary] { [] }

    static var sampleCourseDetails: [CourseGradeDetail] { [] }
}
#endif
