#if os(iOS)
import SwiftUI

struct IOSIPadRootView: View {
    enum IPadSection: String, CaseIterable, Identifiable {
        case core
        case planning
        case focus

        var id: String { rawValue }
        var title: String {
            switch self {
            case .core: return "Core"
            case .planning: return "Planning"
            case .focus: return "Focus"
            }
        }
    }

    @State private var selectedSection: IPadSection? = .core
    @State private var selectedPage: AppPage? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(IPadSection.allCases, selection: $selectedSection) { section in
                Text(section.title)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("Menu")
        } detail: {
            NavigationSplitView {
                List(sectionPages, selection: $selectedPage) { page in
                    Label(page.title, systemImage: page.systemImage)
                        .tag(page)
                }
                .listStyle(.sidebar)
                .navigationTitle("Pages")
            } detail: {
                if let page = selectedPage {
                    detailView(for: page)
                } else {
                    IOSPlaceholderView(title: "Select a page", subtitle: "Choose a page from the middle column.")
                }
            }
        }
        .background(DesignSystem.Colors.appBackground)
    }

    private var sectionPages: [AppPage] {
        switch selectedSection ?? .core {
        case .core:
            return [.dashboard, .calendar]
        case .planning:
            return [.planner, .grades]
        case .focus:
            return [.timer]
        }
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
