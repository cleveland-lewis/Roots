import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @State private var selectedTab: RootTab = .dashboard
    @State private var isMenuOpen = false
    @State private var menuButtonFrame: CGRect = .zero
    @Environment(\.colorScheme) private var colorScheme

    private let menuCardWidth: CGFloat = 248
    private let menuCornerRadius: CGFloat = DesignSystem.Cards.cardCornerRadius

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                currentPageView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 88)
            }

            VStack {
                Spacer()
                GlassTabBar(selected: $selectedTab)
            }
        }
        .overlay(menuOverlay)
        .onPreferenceChange(MenuButtonFramePreferenceKey.self) { menuButtonFrame = $0 }
        .onExitCommand {
            if isMenuOpen { setMenu(open: false) }
        }
    }

    private var topBar: some View {
        HStack {
            Menu {
                ForEach(AppSettingsModel.shared.quickActions, id: \.self) { action in
                    Button {
                        performQuickAction(action)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.glassCircularProminent)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: MenuButtonFramePreferenceKey.self, value: proxy.frame(in: .global))
                        .allowsHitTesting(false)
                }
            )

            Spacer()

            Button {
                UILogger.log(.dashboard, "Tapped: settings_button")
            } label: {
                Image(systemName: "gearshape")
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
        switch selectedTab {
        case .dashboard:
            DashboardView()
        case .calendar:
            CalendarView()
        case .planner:
            Text("Planner placeholder")
        case .assignments:
            AssignmentsView()
        case .courses:
            CoursesView()
        case .grades:
            GradesView()
        case .timer:
            TimerView()
        case .settings:
            SettingsRootView(initialPane: .general) { _ in }
        }
    }

    private var menuOverlay: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if isMenuOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { setMenu(open: false) }
                        .transition(.opacity)
                        .contentTransition(.opacity)
                        .zIndex(0)

                    menuCard
                        .frame(width: menuCardWidth)
                        .offset(x: menuCardXOffset(in: proxy), y: menuCardYOffset(in: proxy))
                        .transition(.menuDrop)
                        .contentTransition(.opacity)
                        .zIndex(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(isMenuOpen)
        .animation(menuAnimation, value: isMenuOpen)
    }

    private var menuCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                MenuRow(tab: tab) {
                    navigate(to: tab)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .glassEffect(
            Glass(style: .frosted, tintColor: Color.primary.opacity(0.1)),
            in: .rect(cornerRadius: menuCornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: menuCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.06), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.2), radius: colorScheme == .dark ? 28 : 20, x: 0, y: 12)
        .contentTransition(.opacity)
    }

    private func toggleMenu() {
        setMenu(open: !isMenuOpen)
    }

    private func setMenu(open: Bool) {
        withAnimation(menuAnimation) {
            isMenuOpen = open
        }
        print("[NavMenu] open = \(open)")
    }

    private func navigate(to tab: RootTab) {
        selectedTab = tab
        print("[NavMenu] navigate -> \(tab.title)")
        setMenu(open: false)
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

    private func menuCardXOffset(in proxy: GeometryProxy) -> CGFloat {
        let safeLeading: CGFloat = proxy.safeAreaInsets.leading + 12
        let referenceX = menuButtonFrame.width > 0
            ? menuButtonFrame.midX - proxy.frame(in: .global).minX - (menuCardWidth / 2)
            : safeLeading
        let minX = safeLeading
        let maxX = proxy.size.width - menuCardWidth - 16
        return min(max(referenceX, minX), maxX)
    }

    private func menuCardYOffset(in proxy: GeometryProxy) -> CGFloat {
        let safeTop = proxy.safeAreaInsets.top + 12
        let referenceY = menuButtonFrame.height > 0
            ? menuButtonFrame.maxY - proxy.frame(in: .global).minY + 6
            : safeTop + 44
        return max(referenceY, safeTop)
    }

    private var menuAnimation: Animation {
        .spring(response: 0.32, dampingFraction: 0.82)
    }
}

private struct MenuRow: View {
    let tab: RootTab
    let action: () -> Void
    @State private var isHovered = false
    @State private var iconBounceToggle = false

    var body: some View {
        Button {
            iconBounceToggle.toggle()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolEffect(.bounce, value: iconBounceToggle)
                    .frame(width: 24)
                Text(tab.title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.12 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

private struct MenuButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private extension AnyTransition {
    static var menuDrop: AnyTransition {
        let scale = AnyTransition.scale(scale: 0.95, anchor: .topLeading)
        let opacity = AnyTransition.opacity
        return .asymmetric(insertion: scale.combined(with: opacity), removal: scale.combined(with: opacity))
    }
}

private struct GlassCircularProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 52, height: 52)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.6)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .contentShape(Circle())
    }
}

extension ButtonStyle where Self == GlassCircularProminentButtonStyle {
    static var glassCircularProminent: GlassCircularProminentButtonStyle { GlassCircularProminentButtonStyle() }
}
