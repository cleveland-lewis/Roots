#if os(iOS)
import SwiftUI
import Combine

enum IOSNavigationTarget: Hashable {
    case page(AppPage)
    case settings
}

final class IOSNavigationCoordinator: ObservableObject {
    @Published var path = NavigationPath()
    @Published var selectedTab: RootTab = .dashboard

    func open(page: AppPage, visibleTabs: [RootTab]) {
        if let tab = RootTab(rawValue: page.rawValue), visibleTabs.contains(tab) {
            path = NavigationPath()
            selectedTab = tab
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
        .calendar,
        .planner,
        .assignments,
        .courses,
        .practice
    ]

    static let defaultTabs: [RootTab] = [.timer, .dashboard, .calendar]

    static func tabs(from settings: AppSettingsModel) -> [RootTab] {
        let visible = settings.effectiveVisibleTabs
        let ordered = settings.tabOrder
        let filtered = ordered.filter { visible.contains($0) && tabCandidates.contains($0) }
        return filtered.isEmpty ? defaultTabs : filtered
    }
}

struct IOSNavigationChrome<TrailingContent: View>: ViewModifier {
    @EnvironmentObject private var settings: AppSettingsModel
    @EnvironmentObject private var navigation: IOSNavigationCoordinator
    @EnvironmentObject private var sheetRouter: IOSSheetRouter
    @EnvironmentObject private var filterState: IOSFilterState
    @EnvironmentObject private var coursesStore: CoursesStore

    let title: String
    let trailingContent: () -> TrailingContent

    init(title: String, @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }) {
        self.title = title
        self.trailingContent = trailingContent
    }

    func body(content: Content) -> some View {
        let visibleTabs = IOSTabConfiguration.tabs(from: settings)

        return content
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    pageMenu(visibleTabs: visibleTabs)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    quickActionsMenu(visibleTabs: visibleTabs)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    trailingContent()
                }
            }
    }

    private func pageMenu(visibleTabs: [RootTab]) -> some View {
        Menu {
            ForEach(menuPages, id: \.self) { page in
                Button {
                    navigation.open(page: page, visibleTabs: visibleTabs)
                } label: {
                    Label(page.title, systemImage: page.systemImage)
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

    private func quickActionsMenu(visibleTabs: [RootTab]) -> some View {
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
                type: .practiceHomework
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
                type: .practiceHomework
            )
            sheetRouter.activeSheet = .addAssignment(defaults)
        case .add_grade:
            sheetRouter.activeSheet = .addGrade(UUID())
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
