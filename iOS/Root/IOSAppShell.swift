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
        HStack(spacing: 16) {
            // Hamburger menu button
            Button {
                showingHamburgerMenu.toggle()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Open menu")
            .popover(isPresented: $showingHamburgerMenu) {
                hamburgerMenuContent
                    .presentationBackground(.ultraThinMaterial)
            }
            
            Spacer()
            
            // Quick add (+) button
            Button {
                showingQuickAddMenu.toggle()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Quick add")
            .popover(isPresented: $showingQuickAddMenu) {
                quickAddMenu
                    .presentationBackground(.ultraThinMaterial)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    private var hamburgerMenuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Menu")
                    .font(.title2.weight(.bold))
                Spacer()
                Button {
                    showingHamburgerMenu = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(allMenuPages, id: \.self) { page in
                        Button {
                            if let prefs = tabBarPrefs {
                                let starred = settings.starredTabs
                                navigation.open(page: page, starredTabs: starred)
                            }
                            showingHamburgerMenu = false
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: page.systemImage)
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                    .frame(width: 28)
                                Text(menuTitle(for: page))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.leading, 60)
                    }

                    Button {
                        navigation.openSettings()
                        showingHamburgerMenu = false
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 28)
                            Text("Settings")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 280, height: 460, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(0.9))
        )
        .padding(8)
    }
    
    private var quickAddMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Quick Add")
                    .font(.title2.weight(.bold))
                Spacer()
                Button {
                    showingQuickAddMenu = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            Divider()
            
            // Quick action buttons
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    handleQuickAction(.add_assignment)
                    showingQuickAddMenu = false
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "plus.square.on.square")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 28)
                        Text("Add Assignment")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.leading, 60)
                
                Button {
                    handleQuickAction(.add_grade)
                    showingQuickAddMenu = false
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "number.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 28)
                        Text("Add Grade")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.leading, 60)
                
                Button {
                    handleQuickAction(.auto_schedule)
                    showingQuickAddMenu = false
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 28)
                        Text("Auto Schedule")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 280, height: 280, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(0.9))
        )
        .padding(8)
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
