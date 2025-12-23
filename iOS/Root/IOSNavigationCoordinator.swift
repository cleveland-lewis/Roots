#if os(iOS)
import SwiftUI
import Combine

enum IOSNavigationTarget: Hashable {
    case page(AppPage)
    case settings
}

final class IOSNavigationCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    func open(page: AppPage, starredTabs: [RootTab]) {
        if let tab = RootTab(rawValue: page.rawValue), starredTabs.contains(tab) {
            // Tab is starred, will be switched to via selectedTab binding
            path = NavigationPath()
        } else {
            // Tab not starred, push as navigation destination
            path.append(IOSNavigationTarget.page(page))
        }
    }

    func openSettings() {
        path.append(IOSNavigationTarget.settings)
    }
}

// MARK: - iOS Tab Configuration (Uses Shared TabRegistry)

/// iOS-specific tab configuration helper
/// Delegates to shared TabRegistry for platform-agnostic logic
struct IOSTabConfiguration {
    
    /// Get tabs for iOS display (uses shared registry)
    static func tabs(from tabPrefs: TabBarPreferencesStore) -> [RootTab] {
        return tabPrefs.effectiveTabsInOrder()
    }
    
    /// Available tabs for iOS (from registry)
    static var availableTabs: [TabDefinition] {
        return TabRegistry.allTabs
    }
}

struct IOSNavigationChrome<TrailingContent: View>: ViewModifier {
    let title: String
    let trailingContent: () -> TrailingContent
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(title: String, @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }) {
        self.title = title
        self.trailingContent = trailingContent
    }

    func body(content: Content) -> some View {
        return content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                // On iPad (regular width), show trailing content in toolbar
                // On iPhone (compact width), show in toolbar
                ToolbarItem(placement: .topBarTrailing) {
                    trailingContent()
                }
            }
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
}
#endif
