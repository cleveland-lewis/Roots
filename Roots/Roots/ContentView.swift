import SwiftUI

enum AppPage: CaseIterable, Hashable {
    case dashboard, planner, courses

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .planner: return "Planner"
        case .courses: return "Courses"
        }
    }

    var icon: Image {
        switch self {
        case .dashboard: return Image(systemName: "rectangle.grid.2x2.fill")
        case .planner: return Image(systemName: "calendar.circle")
        case .courses: return Image(systemName: "books.vertical")
        }
    }
}

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @State private var currentPage: AppPage = .dashboard
    @State private var isMenuPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topBar
                currentPageView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            floatingTabBar
        }
        .environmentObject(settings)
        .overlay(menuOverlay)
    }

    private var topBar: some View {
        HStack {
            Button {
                isMenuPresented.toggle()
                UILogger.log(.dashboard, "Tapped: menu_button")
            } label: {
                Image(systemName: "line.horizontal.3")
                    .font(.title2)
            }
            .buttonStyle(GlassButtonStyle())

            Spacer()

            Button {
                UILogger.log(.dashboard, "Tapped: settings_button")
            } label: {
                Image(systemName: "gear")
                    .font(.title2)
            }
            .buttonStyle(GlassButtonStyle())
        }
        .padding()
        .background(.ultraThinMaterial)
        .contentTransition(.opacity.combined(with: .scale))
    }

    @ViewBuilder
    private var currentPageView: some View {
        switch currentPage {
        case .dashboard:
            DashboardView()
        case .planner:
            Text("Planner placeholder")
        case .courses:
            Text("Courses placeholder")
        }
    }

    private var floatingTabBar: some View {
        HStack(spacing: 30) {
            ForEach(AppPage.allCases, id: \.self) { page in
                Button {
                    currentPage = page
                    UILogger.log(.dashboard, "Tapped: \(page.label.lowercased())_tab")
                } label: {
                    if settings.iconLabelMode != .textOnly {
                        page.icon
                            .font(.title2)
                            .symbolEffect(.bounce)
                    }
                    if settings.iconLabelMode != .iconsOnly {
                        Text(page.label)
                            .font(settings.font(for: .body))
                    }
                }
                .buttonStyle(.glassBlueProminent)
                .onLongPressGesture {
                    settings.cycleIconLabelMode()
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 24)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 10)
        .padding(.bottom, 16)
    }

    private var menuOverlay: some View {
        Group {
            if isMenuPresented {
                GlassPopupContainer(onDismiss: { isMenuPresented = false }) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(AppPage.allCases, id: \.self) { page in
                            Button {
                                currentPage = page
                                isMenuPresented = false
                                UILogger.log(.dashboard, "Tapped: menu_\(page.label.lowercased())")
                            } label: {
                                HStack {
                                    page.icon
                                        .symbolEffect(.bounce)
                                    Text(page.label)
                                        .font(settings.font(for: .body))
                                }
                            }
                            .buttonStyle(GlassButtonStyle())
                        }
                    }
                }
            }
        }
    }
}
