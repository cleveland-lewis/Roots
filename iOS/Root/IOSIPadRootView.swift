#if os(iOS)
import SwiftUI

struct IOSIPadRootView: View {
    @State private var selection: AppPage = .dashboard

    private let sidebarPages: [AppPage] = [
        .dashboard,
        .calendar,
        .planner,
        .grades,
        .timer
    ]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(sidebarPages) { page in
                    Button {
                        selection = page
                    } label: {
                        Label(page.title, systemImage: page.systemImage)
                    }
                    .tag(page)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Menu")
        } detail: {
            detailView(for: selection)
        }
        .background(DesignSystem.Colors.appBackground)
    }

    @ViewBuilder
    private func detailView(for page: AppPage) -> some View {
        switch page {
        case .dashboard:
            IOSDashboardView()
        case .calendar:
            IOSCalendarView()
        case .planner:
            IOSPlannerView()
        case .grades:
            IOSPlaceholderView(title: page.title, subtitle: "Grade insights are available on macOS.")
        case .timer:
            IOSTimerPageView()
        default:
            IOSPlaceholderView(title: page.title, subtitle: "This view is not available on iPad yet.")
        }
    }
}
#endif
