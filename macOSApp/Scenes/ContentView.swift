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
    @State private var selectedTab: RootTab = .dashboard
    @State private var settingsRotation: Double = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

                // LAYER 1: Main content
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    currentPageView
                        .accessibilityIdentifier("Page.\(selectedTab.rawValue)")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        // Keep content flowing behind the floating tab bar; only respect safe area.
                        .padding(.bottom, proxy.safeAreaInsets.bottom + 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // LAYER 2: Floating quick actions menu
                RootsFanOutMenu(items: [
                    FanOutMenuItem(icon: "doc.badge.plus", label: "Add Assignment") {
                        performQuickAction(.add_assignment)
                    },
                    FanOutMenuItem(icon: "calendar.badge.plus", label: "Add Event") {
                        _Concurrency.Task { await CalendarManager.shared.quickAddEvent() }
                    },
                    FanOutMenuItem(icon: "graduationcap", label: "Add Course") {
                        performQuickAction(.add_course)
                    }
                ])
                .opacity(0.9)
                .padding(.leading, 24)
                .padding(.top, 16)
                .zIndex(1)

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
            RootsFanOutMenu(items: [
                FanOutMenuItem(icon: "doc.badge.plus", label: "Add Assignment") {
                    performQuickAction(.add_assignment)
                },
                FanOutMenuItem(icon: "calendar.badge.plus", label: "Add Event") {
                    // Integrate with calendar flow as needed
                },
                FanOutMenuItem(icon: "graduationcap", label: "Add Course") {
                    performQuickAction(.add_course)
                }
            ])
            .opacity(0.9)

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
            }
            .buttonStyle(.plain)
            .rootsStandardInteraction()
            .accessibilityIdentifier("Header.Settings")
        }
        .contentTransition(.opacity)
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

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: .navigateToTab, object: nil, queue: .main) { notification in
            if let tabString = notification.userInfo?["tab"] as? String,
               let tab = RootTab(rawValue: tabString) {
                selectedTab = tab
            }
        }
        
        NotificationCenter.default.addObserver(forName: .addAssignmentRequested, object: nil, queue: .main) { _ in
            performQuickAction(.add_assignment)
        }
        
        NotificationCenter.default.addObserver(forName: .addGradeRequested, object: nil, queue: .main) { _ in
            // TODO: Implement add grade flow
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
