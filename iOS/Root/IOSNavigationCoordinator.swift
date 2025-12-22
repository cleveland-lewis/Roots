#if os(iOS)
import SwiftUI
import Combine

enum IOSNavigationTarget: Hashable {
    case page(AppPage)
    case settings
}

final class IOSNavigationCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    func open(page: AppPage, tabBarPrefs: TabBarPreferencesStore) {
        let visibleTabs = tabBarPrefs.effectiveTabsInOrder()
        if let tab = RootTab(rawValue: page.rawValue), visibleTabs.contains(tab) {
            path = NavigationPath()
            tabBarPrefs.selectedTab = tab
        } else {
            path.append(IOSNavigationTarget.page(page))
        }
    }

    func openSettings() {
        path.append(IOSNavigationTarget.settings)
    }
}

struct IOSTabConfiguration {
    static let tabCandidates: [RootTab] = [
        .timer,
        .dashboard,
        .planner,
        .assignments,
        .courses,
        .practice,
        .settings
    ]

    static let defaultTabs: [RootTab] = [.timer, .dashboard, .settings]

    static func tabs(from settings: AppSettingsModel) -> [RootTab] {
        let visible = settings.effectiveVisibleTabs
        let ordered = settings.tabOrder
        var filtered = ordered.filter { visible.contains($0) && tabCandidates.contains($0) }
        
        // Always ensure settings is included if it's not already
        if !filtered.contains(.settings) {
            filtered.append(.settings)
        }
        
        return filtered.isEmpty ? defaultTabs : filtered
    }
}

struct IOSNavigationChrome<TrailingContent: View>: ViewModifier {
    @EnvironmentObject private var settings: AppSettingsModel
    @EnvironmentObject private var navigation: IOSNavigationCoordinator
    @EnvironmentObject private var tabBarPrefs: TabBarPreferencesStore
    @EnvironmentObject private var sheetRouter: IOSSheetRouter
    @EnvironmentObject private var toastRouter: IOSToastRouter
    @EnvironmentObject private var filterState: IOSFilterState
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var plannerStore: PlannerStore

    let title: String
    let trailingContent: () -> TrailingContent

    init(title: String, @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }) {
        self.title = title
        self.trailingContent = trailingContent
    }

    func body(content: Content) -> some View {
        return content
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    pageMenu()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    quickActionsMenu()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    trailingContent()
                }
            }
    }

    private func pageMenu() -> some View {
        Menu {
            Section("Quick Actions") {
                Button {
                    handleQuickAction(.add_assignment)
                } label: {
                    Label(QuickAction.add_assignment.title, systemImage: QuickAction.add_assignment.systemImage)
                }
                Button {
                    handleQuickAction(.add_grade)
                } label: {
                    Label(QuickAction.add_grade.title, systemImage: QuickAction.add_grade.systemImage)
                }
                Button {
                    handleQuickAction(.auto_schedule)
                } label: {
                    Label(QuickAction.auto_schedule.title, systemImage: QuickAction.auto_schedule.systemImage)
                }
            }

            ForEach(menuPages, id: \.self) { page in
                Button {
                    navigation.open(page: page, tabBarPrefs: tabBarPrefs)
                } label: {
                    Label(menuTitle(for: page), systemImage: page.systemImage)
                }
            }

            Divider()

            Button {
                navigation.openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
        }
        .accessibilityLabel("Open menu")
    }

    private func quickActionsMenu() -> some View {
        Menu {
            ForEach(quickActions, id: \.self) { action in
                Button {
                    handleQuickAction(action)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Quick actions")
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
        case .add_course:
            let defaults = IOSSheetRouter.CourseDefaults(
                semesterId: filterState.selectedSemesterId ?? coursesStore.currentSemesterId,
                title: "",
                code: ""
            )
            sheetRouter.activeSheet = .addCourse(defaults)
        case .add_task:
            let defaults = IOSSheetRouter.TaskDefaults(
                courseId: filterState.selectedCourseId,
                dueDate: Date(),
                title: "",
                type: .practiceHomework,
                itemLabel: "Task"
            )
            sheetRouter.activeSheet = .addAssignment(defaults)
        case .add_grade:
            sheetRouter.activeSheet = .addGrade(UUID())
        case .auto_schedule:
            autoSchedule()
        case .quick_note, .open_new_note:
            break
        }
    }

    private var menuPages: [AppPage] {
        IOSNavigationChromeData.menuPages
    }

    private var quickActions: [QuickAction] {
        IOSNavigationChromeData.quickActions
    }

    private func menuTitle(for page: AppPage) -> String {
        switch page {
        case .assignments:
            return "Tasks"
        default:
            return page.title
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

private enum IOSNavigationChromeData {
    static let menuPages: [AppPage] = [
        .dashboard,
        .planner,
        .assignments,
        .courses,
        .calendar,
        .timer,
        .practice
    ]

    static let quickActions: [QuickAction] = [
        .add_assignment,
        .add_task,
        .add_course,
        .add_grade
    ]
}
#endif
