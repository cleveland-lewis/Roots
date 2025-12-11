import SwiftUI

struct CoursesDashboardRootView: View {
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var gradesStore: GradesStore

    @State private var courses: [CourseDashboard] = []
    @State private var selectedCourse: CourseDashboard?
    @State private var selectedTab: CoursesDashboardFloatingNav.DashboardTab = .courses
    @State private var semesters: [Semester] = []
    @State private var isLoading: Bool = true

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content
            HStack(spacing: 0) {
                // Left Sidebar
                CoursesDashboardSidebar(
                    courses: courses,
                    selectedCourse: $selectedCourse,
                    semesters: semesters,
                    onNewCourse: {
                        print("New Course tapped")
                    },
                    onEditCourses: {
                        print("Edit Courses tapped")
                    }
                )

                Divider()

                // Right Detail Panel
                Group {
                    if isLoading {
                        loadingState
                    } else if let selectedCourse = selectedCourse {
                        CoursesDashboardDetail(course: selectedCourse)
                    } else {
                        emptyDetailState
                    }
                }
            }
            .background(DesignSystem.Colors.appBackground)

            // Floating Navigation Bar
            CoursesDashboardFloatingNav(selectedTab: $selectedTab)
                .padding(.bottom, 16)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            refreshFromStores()
        }
        .onReceive(coursesStore.$courses) { _ in refreshFromStores() }
        .onReceive(assignmentsStore.$tasks) { _ in refreshFromStores() }
        .onReceive(gradesStore.$grades) { _ in refreshFromStores() }
    }

    private var emptyDetailState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.tertiary)

            Text("Select a Course")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Choose a course from the sidebar to view details")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.appBackground)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading course analytics…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension CoursesDashboardRootView {
    func refreshFromStores() {
        isLoading = true

        let activeCourses = coursesStore.activeCourses
        semesters = coursesStore.semesters

        courses = activeCourses.map { course in
            let matchingTasks = assignmentsStore.tasks.filter { $0.courseId == course.id }
            let completedCount = matchingTasks.filter { $0.isCompleted }.count
            let totalCount = matchingTasks.count
            let grade = gradesStore.grade(for: course.id)
            let analytics = CourseAnalytics(
                assignmentsCompleted: completedCount,
                assignmentsTotal: totalCount,
                averageScore: grade?.percent ?? 0,
                attendanceRate: 0,
                hoursStudied: 0
            )

            let progressValue = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
            let semesterName = semesters.first(where: { $0.id == course.semesterId })?.name ?? "Semester"

            return CourseDashboard(
                id: course.id,
                title: course.title,
                code: course.code,
                instructor: course.instructor ?? "Instructor",
                credits: course.credits ?? 0,
                currentGrade: grade?.percent ?? 0,
                progress: progressValue,
                colorHex: course.colorHex ?? "4A90E2",
                term: semesterName,
                location: course.location,
                meetings: [],
                syllabusWeights: SyllabusWeights(),
                analytics: analytics,
                instructorNotes: course.notes,
                upcomingDeadlines: []
            )
        }

        if selectedCourse == nil || !(courses.contains { $0.id == selectedCourse?.id }) {
            selectedCourse = courses.first
        }

        isLoading = false
    }
}

// MARK: - Preview

#if !DISABLE_PREVIEWS
#Preview {
    CoursesDashboardRootView()
        .environmentObject(CoursesStore())
        .environmentObject(AssignmentsStore.shared)
        .environmentObject(GradesStore.shared)
        .frame(width: 1200, height: 800)
}
#endif
