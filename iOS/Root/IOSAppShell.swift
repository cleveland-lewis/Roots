#if os(iOS)
import SwiftUI

/// Global app shell that provides consistent top bar across all pages
struct IOSAppShell<Content: View>: View {
    @EnvironmentObject private var settings: AppSettingsModel
    @EnvironmentObject private var navigation: IOSNavigationCoordinator
    @EnvironmentObject private var sheetRouter: IOSSheetRouter
    @EnvironmentObject private var toastRouter: IOSToastRouter
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var plannerStore: PlannerStore
    @EnvironmentObject private var filterState: IOSFilterState
    @State private var tabBarPrefs: TabBarPreferencesStore?
    @State private var showingHamburgerMenu = false
    @State private var showingQuickAddMenu = false
    
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                topBar
            }
        .onAppear {
            if tabBarPrefs == nil {
                tabBarPrefs = TabBarPreferencesStore(settings: settings)
            }
        }
    }
    
    private var topBar: some View {
        ZStack(alignment: .top) {
            // Top bar with buttons
            HStack(spacing: 16) {
                // Hamburger menu button
                Button {
                    showingHamburgerMenu.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Open menu")
                
                Spacer()
                
                // Quick add (+) button
                Button {
                    showingQuickAddMenu.toggle()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Quick add")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            
            // Hamburger menu overlay
            if showingHamburgerMenu {
                HStack {
                    FloatingMenuPanel(isPresented: $showingHamburgerMenu, width: 280, maxHeight: 500) {
                        hamburgerMenuContent
                    }
                    .offset(x: 16, y: 60)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingHamburgerMenu)
                    Spacer()
                }
            }
            
            // Quick add menu overlay
            if showingQuickAddMenu {
                HStack {
                    Spacer()
                    FloatingMenuPanel(isPresented: $showingQuickAddMenu, width: 280) {
                        quickAddMenu
                    }
                    .offset(x: -16, y: 60)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingQuickAddMenu)
                }
            }
        }
    }
    
    private var hamburgerMenuContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Navigation pages
                ForEach(Array(allMenuPages.enumerated()), id: \.element) { index, page in
                    FloatingMenuRow(
                        title: menuTitle(for: page),
                        icon: page.systemImage,
                        showSeparator: index < allMenuPages.count - 1
                    ) {
                        if tabBarPrefs != nil {
                            let starred = settings.starredTabs
                            navigation.open(page: page, starredTabs: starred)
                        }
                        showingHamburgerMenu = false
                    }
                }
                
                // Section divider
                FloatingMenuSectionDivider()
                
                // Settings
                FloatingMenuRow(
                    title: "Settings",
                    icon: "gearshape",
                    showSeparator: false
                ) {
                    navigation.openSettings()
                    showingHamburgerMenu = false
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var quickAddMenu: some View {
        VStack(spacing: 0) {
            FloatingMenuRow(
                title: "Add Assignment",
                icon: "plus.square.on.square"
            ) {
                handleQuickAction(.add_assignment)
                showingQuickAddMenu = false
            }
            
            FloatingMenuRow(
                title: "Add Grade",
                icon: "number.circle"
            ) {
                handleQuickAction(.add_grade)
                showingQuickAddMenu = false
            }
            
            FloatingMenuRow(
                title: "Auto Schedule",
                icon: "calendar.badge.clock",
                showSeparator: false
            ) {
                handleQuickAction(.auto_schedule)
                showingQuickAddMenu = false
            }
        }
        .padding(.vertical, 8)
    }
    
    private var allMenuPages: [AppPage] {
        [
            .dashboard,
            .calendar,
            .planner,
            .assignments,
            .courses,
            .timer,
            .practice
        ]
    }
    
    private func menuTitle(for page: AppPage) -> String {
        switch page {
        case .assignments:
            return "Tasks"
        default:
            return page.title
        }
    }
    
    private func handleQuickAction(_ action: QuickAction) {
        switch action {
        case .add_assignment:
            let defaults = IOSSheetRouter.TaskDefaults(
                courseId: filterState.selectedCourseId,
                dueDate: Date(),
                title: "",
                type: .practiceHomework,
                itemLabel: "Assignment"
            )
            sheetRouter.activeSheet = .addAssignment(defaults)
        case .add_grade:
            sheetRouter.activeSheet = .addGrade(UUID())
        case .auto_schedule:
            autoSchedule()
        default:
            break
        }
    }
    
    private func autoSchedule() {
        let assignments = assignmentsForPlanning()
        guard !assignments.isEmpty else {
            toastRouter.show("No tasks to schedule")
            return
        }
        let settings = StudyPlanSettings()
        let sessions = assignments.flatMap { PlannerEngine.generateSessions(for: $0, settings: settings) }
        let result = PlannerEngine.scheduleSessions(sessions, settings: settings, energyProfile: defaultEnergyProfile())
        plannerStore.persist(scheduled: result.scheduled, overflow: result.overflow)
        toastRouter.show("Schedule updated")
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
}
#endif
