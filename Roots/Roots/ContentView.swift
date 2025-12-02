import SwiftUI

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
        .contentTransition(.opacity)
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
                    UILogger.log(.dashboard, "Tapped: \(page.title.lowercased())_tab")
                } label: {
                    if settings.iconLabelMode != .textOnly {
                        Image(systemName: page.systemImage)
                            .font(.title2)
                            .symbolEffect(.bounce)
                    }
                    if settings.iconLabelMode != .iconsOnly {
                        Text(page.title)
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
                                UILogger.log(.dashboard, "Tapped: menu_\(page.title.lowercased())")
                            } label: {
                                HStack {
                                    Image(systemName: page.systemImage)
                                        .symbolEffect(.bounce)
                                    Text(page.title)
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
