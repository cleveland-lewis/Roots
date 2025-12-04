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

    enum ColorTag: String, CaseIterable, Identifiable {
        case blue, green, purple, orange, pink, yellow, gray
        var id: String { rawValue }

        var color: Color {
            switch self {
            case .blue: return .blue
            case .green: return .green
            case .purple: return .purple
            case .orange: return .orange
            case .pink: return .pink
            case .yellow: return .yellow
            case .gray: return .gray
            }
        }
    }
}

// Short aliases for readability inside this file
typealias CoursePageCourse = CoursesPageModel.Course
typealias CourseMeeting = CoursesPageModel.CourseMeeting
typealias CourseGradeInfo = CoursesPageModel.CourseGradeInfo
typealias CourseSyllabus = CoursesPageModel.CourseSyllabus
typealias SyllabusCategory = CoursesPageModel.SyllabusCategory
typealias ColorTag = CoursesPageModel.ColorTag

// MARK: - Root Page

struct CoursesPageView: View {
    @EnvironmentObject private var settings: AppSettingsModel
    @EnvironmentObject private var settingsCoordinator: SettingsCoordinator

    @State private var courses: [CoursePageCourse] = CoursesPageView.sampleCourses
    @State private var selectedCourse: CoursePageCourse? = nil
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
        .accentColor(settings.activeAccentColor)
        .sheet(isPresented: $showNewCourseSheet) {
            CourseEditorSheet(course: editingCourse) { updated in
                upsertCourse(updated)
                selectedCourse = updated
            }
        }
        .onAppear {
            if selectedCourse == nil { selectedCourse = filteredCourses.first }
        }
    }

    private var sidebarView: some View {
        CoursesSidebarView(
            courses: filteredCourses,
            selectedCourse: $selectedCourse,
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
            if let course = selectedCourse ?? filteredCourses.first {
                CoursesPageDetailView(
                    course: binding(for: course),
                    onEdit: {
                        editingCourse = course
                        showNewCourseSheet = true
                    }
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                emptyDetailState
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            RootsCard(title: "Courses Secondary Panel") {
                VStack(alignment: .leading, spacing: RootsSpacing.m) {
                    Text("Coming soon")
                        .rootsBodySecondary()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: RootsSpacing.m)], spacing: RootsSpacing.m) {
                        placeholderModule(title: "Course Analytics", detail: "Future visualizations for grades, attendance, and engagement.")
                        placeholderModule(title: "Instructor Notes", detail: "Pin office hours, email templates, and recurring tasks.")
                        placeholderModule(title: "Upcoming Deadlines", detail: "Sync from Assignments and Planner to surface risks.")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
        let active = courses.filter { !$0.isArchived }
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return active }
        let query = searchText.lowercased()
        return active.filter { course in
            course.code.lowercased().contains(query) ||
            course.title.lowercased().contains(query) ||
            course.instructor.lowercased().contains(query)
        }
    }

    private func binding(for course: CoursePageCourse) -> Binding<CoursePageCourse> {
        guard let index = courses.firstIndex(of: course) else {
            return .constant(course)
        }
        return $courses[index]
    }

    private func upsertCourse(_ course: CoursePageCourse) {
        if let idx = courses.firstIndex(where: { $0.id == course.id }) {
            courses[idx] = course
        } else {
            courses.append(course)
        }
    }

    private var emptyDetailState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Select or create a course")
                .font(.headline)
            Text("Your course overview will appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar

struct CoursesSidebarView: View {
    @EnvironmentObject private var settingsCoordinator: SettingsCoordinator

    var courses: [CoursePageCourse]
    @Binding var selectedCourse: CoursePageCourse?
    @Binding var searchText: String
    var onNewCourse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Courses")
                    .font(.system(size: 22, weight: .semibold))
                Text(currentTerm)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            TextField("Search courses", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(courses) { course in
                        CourseSidebarRow(course: course, isSelected: course == selectedCourse) {
                            selectedCourse = course
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }

            HStack(spacing: RootsSpacing.s) {
                Button {
                    onNewCourse()
                } label: {
                    Label("New Course", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Button {
                    settingsCoordinator.show(selecting: .courses)
                } label: {
                    Label("Edit Courses", systemImage: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, RootsSpacing.m)
            .padding(.bottom, RootsSpacing.m)
        }
        .padding(.vertical, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
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
            HStack(spacing: 10) {
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
                    .fill(isSelected ? Color(nsColor: NSColor.alternatingContentBackgroundColors[0]).opacity(0.08) : Color(nsColor: NSColor.alternatingContentBackgroundColors[0]).opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(isSelected ? 0.14 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel("\(course.code), \(course.title)")
    }
}

// MARK: - Detail

struct CoursesPageDetailView: View {
    @Binding var course: CoursePageCourse
    var onEdit: () -> Void

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
                        .font(.headline)
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
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                Label(course.instructor, systemImage: "person")
                Label(course.location, systemImage: "mappin.and.ellipse")
                Label("\(course.credits) credits", systemImage: "number")
                Label(course.semesterName, systemImage: "calendar")
            }
            .font(.caption)
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
                    Text("No meetings added yet.")
                        .rootsBodySecondary()

                    Button("View Device's Calendar") {
                        openCalendar(for: nil)
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentColor)
                }
            } else {
                VStack(alignment: .leading, spacing: RootsSpacing.s) {
                    ForEach(course.meetingTimes) { meeting in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(weekdayName(meeting.weekday)) · \(timeRange(for: meeting))")
                                .font(.system(size: 13.5, weight: .semibold))
                            Text(meeting.type)
                                .rootsCaption()
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("View Device's Calendar") {
                        openCalendar(for: course.meetingTimes.first)
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentColor)
                    .padding(.top, RootsSpacing.xs)
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
                VStack(spacing: 10) {
                    ForEach(syllabus.categories) { category in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(category.name)
                                    .font(.system(size: 13.5, weight: .semibold))
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No syllabus added yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("You’ll eventually be able to import this from a syllabus parser.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
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
                    action: addAssignment
                )

                quickActionTile(
                    title: "Add Exam",
                    subtitle: "Schedule an exam or quiz",
                    systemImage: "calendar.badge.clock",
                    action: addExam
                )

                quickActionTile(
                    title: "Add Grade",
                    subtitle: "Log a grade for this course",
                    systemImage: "checkmark.seal",
                    action: addGrade
                )

                quickActionTile(
                    title: "View Plan for Course",
                    subtitle: "Open Planner with this course filtered",
                    systemImage: "list.bullet.rectangle",
                    action: viewPlanner
                )
            }
        }
    }

    private func quickActionTile(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: RootsSpacing.m) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
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
            .padding(RootsSpacing.m)
            .rootsCardBackground(radius: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick action handlers

    private func addAssignment() {
        NotificationCenter.default.post(
            name: .coursesRequestedAddAssignment,
            object: nil,
            userInfo: ["courseId": course.id, "courseCode": course.code, "courseTitle": course.title]
        )
    }

    private func addExam() {
        NotificationCenter.default.post(
            name: .coursesRequestedAddExam,
            object: nil,
            userInfo: ["courseId": course.id, "courseCode": course.code, "courseTitle": course.title]
        )
    }

    private func addGrade() {
        NotificationCenter.default.post(
            name: .coursesRequestedAddGrade,
            object: nil,
            userInfo: ["courseId": course.id, "courseCode": course.code, "courseTitle": course.title]
        )
    }

    private func viewPlanner() {
        NotificationCenter.default.post(
            name: .coursesRequestedOpenPlanner,
            object: nil,
            userInfo: ["courseId": course.id, "courseCode": course.code, "courseTitle": course.title]
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
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
    static let coursesRequestedAddAssignment = Notification.Name("coursesRequestedAddAssignment")
    static let coursesRequestedAddExam = Notification.Name("coursesRequestedAddExam")
    static let coursesRequestedAddGrade = Notification.Name("coursesRequestedAddGrade")
    static let coursesRequestedOpenPlanner = Notification.Name("coursesRequestedOpenPlanner")
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                        .font(.system(size: 14, weight: .semibold))
                    Text("Current")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 2) {
                    Text("—")
                        .font(.system(size: 16, weight: .semibold))
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
        HStack(spacing: 8) {
            ForEach(ColorTag.allCases) { tag in
                Button {
                    selected = tag
                } label: {
                    Circle()
                        .fill(tag.color.opacity(0.95))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(selected == tag ? appSettings.activeAccentColor : Color(nsColor: .separatorColor).opacity(0.12), lineWidth: selected == tag ? 3 : 1)
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
        .onChange(of: semesterId) { newValue in
            if let id = newValue, let match = coursesStore.semesters.first(where: { $0.id == id }) {
                semesterName = match.name
            }
        }
    }

    private var courseSection: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.m) {
            Text("Course").rootsSectionHeader()
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
                TextField("Instructor", text: $instructor)
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
            Text("Details").rootsSectionHeader()
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
            Text("You can edit course details later from the Courses page.")
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

private extension CoursesPageView {
    static var sampleCourses: [CoursePageCourse] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        func time(_ string: String) -> Date {
            formatter.date(from: string) ?? Date()
        }

        let mathMeetings = [
            CourseMeeting(id: UUID(), weekday: 2, startTime: time("09:35"), endTime: time("10:25"), type: "Lecture"),
            CourseMeeting(id: UUID(), weekday: 4, startTime: time("09:35"), endTime: time("10:25"), type: "Lecture")
        ]

        let csMeetings = [
            CourseMeeting(id: UUID(), weekday: 3, startTime: time("13:00"), endTime: time("14:15"), type: "Lecture"),
            CourseMeeting(id: UUID(), weekday: 5, startTime: time("13:00"), endTime: time("14:15"), type: "Recitation")
        ]

        let syllabus = CourseSyllabus(
            categories: [
                SyllabusCategory(id: UUID(), name: "Homework", weight: 25),
                SyllabusCategory(id: UUID(), name: "Projects", weight: 35),
                SyllabusCategory(id: UUID(), name: "Exams", weight: 40)
            ],
            notes: "Review the rubric each week. Major project checkpoints at weeks 5 and 9."
        )

        let fall2025 = UUID()

        let math = CoursePageCourse(
            id: UUID(),
            code: "MA 231",
            title: "Calculus II",
            instructor: "Prof. Lane",
            location: "SAS 2104",
            credits: 4,
            colorTag: .blue,
            semesterId: fall2025,
            semesterName: "Fall 2025",
            isArchived: false,
            meetingTimes: mathMeetings,
            gradeInfo: CourseGradeInfo(currentPercentage: 92, targetPercentage: 95, letterGrade: "A-"),
            syllabus: syllabus
        )

        let cs = CoursePageCourse(
            id: UUID(),
            code: "CS 240",
            title: "Data Structures",
            instructor: "Dr. Kim",
            location: "EB2 1230",
            credits: 3,
            colorTag: .purple,
            semesterId: fall2025,
            semesterName: "Fall 2025",
            isArchived: false,
            meetingTimes: csMeetings,
            gradeInfo: CourseGradeInfo(currentPercentage: 88, targetPercentage: 93, letterGrade: "B+"),
            syllabus: syllabus
        )

        let hist = CoursePageCourse(
            id: UUID(),
            code: "HIS 120",
            title: "Modern World History",
            instructor: "Dr. Alvarez",
            location: "Tompkins 112",
            credits: 3,
            colorTag: .orange,
            semesterId: fall2025,
            semesterName: "Fall 2025",
            isArchived: false,
            meetingTimes: [
                CourseMeeting(id: UUID(), weekday: 2, startTime: time("11:15"), endTime: time("12:30"), type: "Lecture")
            ],
            gradeInfo: CourseGradeInfo(currentPercentage: nil, targetPercentage: 90, letterGrade: nil),
            syllabus: nil
        )

        return [math, cs, hist]
    }
}
