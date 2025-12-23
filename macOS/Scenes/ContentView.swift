#if os(macOS)
import SwiftUI
import AppKit
import Combine

struct ContentView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @EnvironmentObject var coursesStore: CoursesStore
    @EnvironmentObject var settingsCoordinator: SettingsCoordinator
    @EnvironmentObject var plannerCoordinator: PlannerCoordinator
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var modalRouter: AppModalRouter
    @State private var selectedTab: RootTab = .dashboard
    @State private var settingsRotation: Double = 0
    @State private var isQuickActionsExpanded = false
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isSettingsFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

                // LAYER 1: Main content
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .zIndex(1)

                    currentPageView
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        // Keep content flowing behind the floating tab bar; only respect safe area.
                        .padding(.bottom, proxy.safeAreaInsets.bottom + 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                QuickActionsDismissLayer(isExpanded: isQuickActionsExpanded) {
                    collapseQuickActions()
                }
                .zIndex(0.5)

                // Floating tab bar stays at bottom; keep above content
                VStack {
                    Spacer()
                    RootsFloatingTabBar(
                        items: RootTab.allCases,
                        selected: $selectedTab,
                        mode: settings.tabBarMode,
                        onSelect: handleTabSelection
                    )
                    .frame(height: 72)
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 16)
                    .padding(.bottom, proxy.safeAreaInsets.bottom == 0 ? 16 : proxy.safeAreaInsets.bottom)
                    .frame(maxWidth: .infinity)
                }
                .zIndex(1)
            }
        }
        .frame(minWidth: RootsWindowSizing.minMainWidth, minHeight: RootsWindowSizing.minMainHeight)
        .globalContextMenu()
        .onAppear {
            setupNotificationObservers()
            DispatchQueue.main.async {
                if let win = NSApp.keyWindow ?? NSApp.windows.first {
                    win.title = ""
                    win.titleVisibility = .hidden
                    win.titlebarAppearsTransparent = true
                }
            }
            if let initialTab = RootTab(rawValue: appModel.selectedPage.rawValue) {
                selectedTab = initialTab
            }
        }
        .onChange(of: plannerCoordinator.requestedCourseId) { _, courseId in
            selectedTab = .planner
            plannerCoordinator.selectedCourseFilter = courseId
        }
        .onReceive(appModel.$selectedPage) { page in
            if let tab = RootTab(rawValue: page.rawValue), selectedTab != tab {
                selectedTab = tab
            }
        }
        .onChange(of: modalRouter.route) { _, route in
            guard let route else { return }
            switch route {
            case .planner:
                selectedTab = .planner
                appModel.selectedPage = .planner
                modalRouter.clear()
            case .addAssignment:
                selectedTab = .assignments
                appModel.selectedPage = .assignments
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: .addAssignmentRequested, object: nil)
                    modalRouter.clear()
                }
            case .addGrade:
                selectedTab = .grades
                appModel.selectedPage = .grades
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: .addGradeRequested, object: nil)
                    modalRouter.clear()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addAssignment)) { _ in
            guard selectedTab != .assignments else { return }
            selectedTab = .assignments
            appModel.selectedPage = .assignments
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .addAssignmentRequested, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addCourse)) { _ in
            guard selectedTab != .courses else { return }
            selectedTab = .courses
            appModel.selectedPage = .courses
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .addCourseRequested, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addEvent)) { _ in
            guard selectedTab != .calendar else { return }
            selectedTab = .calendar
            appModel.selectedPage = .calendar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .addEventRequested, object: nil)
            }
        }
        #if os(macOS)
        .onKeyDown { event in
            switch event.keyCode {
            case 125: // down arrow
                scrollActiveView(by: 120)
            case 126: // up arrow
                scrollActiveView(by: -120)
            default:
                break
            }
        }
        #endif
    }

    private var topBar: some View {
        HStack {
            QuickActionsLauncher(isExpanded: $isQuickActionsExpanded, actions: settings.quickActions) { action in
                performQuickAction(action)
            }

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: DesignSystem.Motion.deliberate)) {
                    settingsRotation += 360
                }
                settingsCoordinator.show()
            }) {
                Image(systemName: "gearshape")
                    .font(DesignSystem.Typography.body)
                    .rotationEffect(.degrees(settingsRotation))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(DesignSystem.Materials.hud.opacity(0.75), in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                            .opacity(isSettingsFocused ? 0.7 : 0)
                    )
            }
            .buttonStyle(.plain)
            .focusable(true)
            .focused($isSettingsFocused)
            .rootsStandardInteraction()
            .accessibilityIdentifier("Header.Settings")
        }
        .contentTransition(.opacity)
        .onExitCommand {
            collapseQuickActions()
        }
    }

    @ViewBuilder
    private var currentPageView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView()
        case .calendar:
            CalendarPageView()
        case .planner:
            PlannerPageView()
        case .assignments:
            AssignmentsPageView()
        case .courses:
            CoursesPageView()
        case .grades:
            GradesPageView()
        case .timer:
            TimerPageView()
        case .decks:
            if settings.enableFlashcards {
                FlashcardDashboard()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.person.crop")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Flashcards are turned off")
                        .font(DesignSystem.Typography.subHeader)
                    Text("Enable flashcards in Settings → Flashcards to study decks.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .practice:
            PracticeTestPageView()
        }
    }

    private func performQuickAction(_ action: QuickAction) {
        switch action {
        case .add_assignment:
            // open add assignment flow
            LOG_UI(.info, "QuickAction", "Add Assignment")
            // placeholder: open AddAssignment sheet if implemented
            break
        case .add_course:
            LOG_UI(.info, "QuickAction", "Add Course")
            break
        case .add_task:
            LOG_UI(.info, "QuickAction", "Add Task")
            break
        case .add_grade:
            LOG_UI(.info, "QuickAction", "Add Grade")
            break
        case .auto_schedule:
            LOG_UI(.info, "QuickAction", "Auto Schedule")
            break
        case .quick_note:
            LOG_UI(.info, "QuickAction", "Quick Note")
            break
        case .open_new_note:
            LOG_UI(.info, "QuickAction", "Open New Note")
            break
        }
    }

    private func handleTabSelection(_ tab: RootTab) {
        LOG_NAVIGATION(.info, "TabSelection", "User navigated to tab: \(tab.rawValue)")
        selectedTab = tab
        if let page = AppPage(rawValue: tab.rawValue), appModel.selectedPage != page {
            appModel.selectedPage = page
        }
    }

    private func collapseQuickActions() {
        if isQuickActionsExpanded {
            isQuickActionsExpanded = false
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: .navigateToTab, object: nil, queue: .main) { notification in
            if let tabString = notification.userInfo?["tab"] as? String,
               let tab = RootTab(rawValue: tabString) {
                selectedTab = tab
            }
        }
        
        NotificationCenter.default.addObserver(forName: .addAssignmentRequested, object: nil, queue: .main) { _ in
            LOG_UI(.info, "ContextMenu", "Add Assignment requested")
        }
        
        NotificationCenter.default.addObserver(forName: .addGradeRequested, object: nil, queue: .main) { _ in
            LOG_UI(.info, "ContextMenu", "Add Grade requested")
        }
        
        NotificationCenter.default.addObserver(forName: .refreshRequested, object: nil, queue: .main) { _ in
            // Trigger refresh for current view
            LOG_UI(.info, "ContextMenu", "Refresh requested")
        }
    }

    #if os(macOS)
    /// Scrolls the currently focused scroll view (if any) by the given delta.
    private func scrollActiveView(by deltaY: CGFloat) {
        guard let responder = NSApp.keyWindow?.firstResponder as? NSView else { return }
        let targetScrollView = responder.enclosingScrollView ?? responder.superview?.enclosingScrollView
        guard let scrollView = targetScrollView, let documentView = scrollView.documentView else { return }

        let clipView = scrollView.contentView
        var newOrigin = clipView.bounds.origin
        let maxY = max(0, documentView.bounds.height - clipView.bounds.height)
        newOrigin.y = min(max(newOrigin.y + deltaY, 0), maxY)
        clipView.setBoundsOrigin(newOrigin)
        scrollView.reflectScrolledClipView(clipView)
    }
    #endif
}
#endif
