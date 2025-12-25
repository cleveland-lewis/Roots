#if os(iOS)
import SwiftUI

struct IOSRootView: View {
    @EnvironmentObject private var settings: AppSettingsModel
    @EnvironmentObject private var sheetRouter: IOSSheetRouter
    @EnvironmentObject private var toastRouter: IOSToastRouter
    @EnvironmentObject private var coursesStore: CoursesStore
    @EnvironmentObject private var assignmentsStore: AssignmentsStore
    @EnvironmentObject private var gradesStore: GradesStore
    @EnvironmentObject private var plannerCoordinator: PlannerCoordinator
    @StateObject private var navigation = IOSNavigationCoordinator()
    @StateObject private var tabBarPrefs: TabBarPreferencesStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedTab: RootTab = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    init() {
        _tabBarPrefs = StateObject(wrappedValue: TabBarPreferencesStore(settings: AppSettingsModel.shared))
    }
    
    private var layoutMetrics: LayoutMetrics {
        LayoutMetrics(
            compactMode: settings.compactModeStorage,
            largeTapTargets: settings.largeTapTargetsStorage
        )
    }

    private var starredTabs: [RootTab] {
        var tabs = settings.starredTabs
        
        // Remove Practice tab on iPhone (compact width)
        if horizontalSizeClass == .compact {
            tabs.removeAll { $0 == .practice }
        }
        
        // Ensure at least Dashboard is present
        if tabs.isEmpty {
            tabs = [.dashboard]
        }
        
        // Validate current selection
        if !tabs.contains(selectedTab) {
            selectedTab = tabs.first ?? .dashboard
        }
        
        return tabs
    }
    
    private var isPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        ZStack {
            if isPad && settings.showSidebarByDefault {
                // iPad with sidebar
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    sidebarContent
                } detail: {
                    detailContent
                }
                .onAppear {
                    columnVisibility = .all
                }
            } else {
                // iPhone or iPad without sidebar
                NavigationStack(path: $navigation.path) {
                    TabView(selection: $selectedTab) {
                        ForEach(starredTabs, id: \.self) { tab in
                            IOSAppShell {
                                tabView(for: tab)
                            }
                            .tag(tab)
                            .tabItem {
                                if let def = TabRegistry.definition(for: tab) {
                                    Label(def.title, systemImage: def.icon)
                                }
                            }
                        }
                    }
                    .navigationDestination(for: IOSNavigationTarget.self) { destination in
                        IOSAppShell(hideNavigationButtons: destination == .settings) {
                            switch destination {
                            case .page(let page):
                                pageView(for: page)
                            case .settings:
                                settingsContent
                            }
                        }
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
        .background(DesignSystem.Colors.appBackground)
        .environmentObject(navigation)
        .environmentObject(tabBarPrefs)
        .layoutMetrics(layoutMetrics)
        .overlay(alignment: .top) {
            if let message = toastRouter.message {
                toastView(message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.2), value: toastRouter.message)
            }
        }
        .sheet(item: $sheetRouter.activeSheet) { sheet in
            switch sheet {
            case .addAssignment(let defaults):
                IOSTaskEditorView(
                    task: nil,
                    courses: coursesStore.activeCourses,
                    defaults: .init(
                        title: defaults.title,
                        courseId: defaults.courseId,
                        dueDate: defaults.dueDate,
                        type: defaults.type
                    ),
                    itemLabel: defaults.itemLabel,
                    onSave: { draft in
                        let task = draft.makeTask(existing: nil)
                        assignmentsStore.addTask(task)
                        toastRouter.show(String(format: NSLocalizedString("ios.toast.assignment_added", comment: "Assignment added"), defaults.itemLabel))
                    }
                )
            case .addCourse(let defaults):
                IOSCourseEditorView(
                    semesters: coursesStore.activeSemesters,
                    currentSemesterId: defaults.semesterId ?? coursesStore.currentSemesterId,
                    defaults: .init(title: defaults.title, code: defaults.code, semesterId: defaults.semesterId),
                    onSave: { draft in
                        guard let semester = coursesStore.activeSemesters.first(where: { $0.id == draft.semesterId }) else { return }
                        coursesStore.addCourse(title: draft.title, code: draft.code, to: semester)
                        toastRouter.show(NSLocalizedString("ios.toast.course_added", comment: "Course added"))
                    }
                )
            case .addGrade:
                AddGradeSheet(
                    assignments: assignmentsStore.tasks,
                    courses: gradeCourseSummaries(),
                    onSave: { updatedTask in
                        assignmentsStore.updateTask(updatedTask)
                        if let courseId = updatedTask.courseId {
                            gradesStore.upsert(courseId: courseId, percent: updatedTask.gradeWeightPercent, letter: nil)
                        }
                        toastRouter.show(NSLocalizedString("ios.toast.grade_added", comment: "Grade added"))
                    }
                )
            }
        }
        .onChange(of: plannerCoordinator.requestedDate) { _, date in
            guard date != nil else { return }
            openPlannerPage()
            plannerCoordinator.requestedDate = nil
        }
        .onChange(of: plannerCoordinator.requestedCourseId) { _, _ in
            openPlannerPage()
        }
    }
    
    // MARK: - iPad Sidebar Navigation
    
    @ViewBuilder
    private var sidebarContent: some View {
        List {
            ForEach(starredTabs, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    if let def = TabRegistry.definition(for: tab) {
                        Label(def.title, systemImage: def.icon)
                    }
                }
                .listRowBackground(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
            }
            
            Section("Other Pages") {
                ForEach(nonStarredTabs, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        if let def = TabRegistry.definition(for: tab) {
                            Label(def.title, systemImage: def.icon)
                        }
                    }
                }
            }
        }
        .navigationTitle("Roots")
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    private var detailContent: some View {
        NavigationStack(path: $navigation.path) {
            tabView(for: selectedTab)
                .navigationDestination(for: IOSNavigationTarget.self) { destination in
                    switch destination {
                    case .page(let page):
                        pageView(for: page)
                    case .settings:
                        settingsContent
                    }
                }
        }
    }
    
    private var nonStarredTabs: [RootTab] {
        TabRegistry.allTabs.map { $0.id }.filter { !starredTabs.contains($0) }
    }

    private func toastView(_ message: String) -> some View {
        VStack {
            Text(message)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .shadow(radius: 6, y: 3)
                )
            Spacer()
        }
        .padding(.top, 18)
        .padding(.horizontal, 16)
    }

    private func openPlannerPage() {
        if starredTabs.contains(.planner) {
            selectedTab = .planner
            navigation.path = NavigationPath()
        } else {
            navigation.open(page: .planner, starredTabs: starredTabs)
        }
    }

    private func gradeCourseSummaries() -> [GradeCourseSummary] {
        coursesStore.activeCourses.map { course in
            GradeCourseSummary(id: course.id, title: course.code.isEmpty ? course.title : course.code)
        }
    }

    @ViewBuilder
    private func tabView(for tab: RootTab) -> some View {
        switch tab {
        case .dashboard:
            IOSDashboardView()
        case .calendar:
            IOSCalendarView()
        case .planner:
            IOSPlannerView()
        case .assignments:
            IOSAssignmentsView()
        case .courses:
            IOSCoursesView()
        case .timer:
            IOSTimerPageView()
        case .flashcards:
            IOSFlashcardsView()
        case .practice:
            IOSPracticeView()
        case .settings:
            SettingsRootView()
        default:
            IOSPlaceholderView(title: tab.title, subtitle: "This page is not available on iOS yet.")
        }
    }

    @ViewBuilder
    private func pageView(for page: AppPage) -> some View {
        switch page {
        case .dashboard:
            IOSDashboardView()
        case .calendar:
            IOSCalendarView()
        case .planner:
            IOSPlannerView()
        case .assignments:
            IOSAssignmentsView()
        case .courses:
            IOSCoursesView()
        case .timer:
            IOSTimerPageView()
        case .flashcards:
            IOSFlashcardsView()
        case .practice:
            IOSPracticeView()
        default:
            IOSPlaceholderView(title: page.title, subtitle: "This view is coming soon.")
        }
    }
    
    private var settingsContent: some View {
        List {
            ForEach(SettingsCategory.allCases) { category in
                NavigationLink(destination: category.destinationView()) {
                    Label {
                        Text(category.title)
                    } icon: {
                        Image(systemName: category.systemImage)
                            .foregroundColor(.accentColor)
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("ios.settings.title", comment: "Settings"))
        .navigationBarTitleDisplayMode(.large)
    }
}
#endif
