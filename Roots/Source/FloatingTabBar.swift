import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: RootTab
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var settingsCoordinator: SettingsCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @State private var bounceTab: RootTab?
    @State private var hoveredTab: RootTab?

    private var showIcons: Bool { settings.iconLabelMode != .textOnly }
    private var showText: Bool { settings.iconLabelMode != .iconsOnly }

    var body: some View {
        HStack(spacing: 12) {
            let tabs = settings.tabOrder.filter { settings.effectiveVisibleTabs.contains($0) }
            ForEach(tabs) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(DesignSystem.Materials.hud.opacity(0.28))
        )
        .overlay(
            Capsule()
                .stroke(Color(nsColor: .separatorColor).opacity(colorScheme == .dark ? 0.08 : 0.12), lineWidth: 0.6)
        )
        .shadow(color: Color(nsColor: .separatorColor).opacity(colorScheme == .dark ? 0.12 : 0.08), radius: 24, x: 0, y: 12)
        .fixedSize(horizontal: true, vertical: true)
        .padding(.bottom, 26)
        .contextMenu {
            ForEach(IconLabelMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        settings.iconLabelMode = mode
                    }
                } label: {
                    Label(mode.label, systemImage: settings.iconLabelMode == mode ? "checkmark.circle.fill" : "circle")
                }
                .disabled(settings.iconLabelMode == mode)
            }
        }
    }

    private func tabLabel(for tab: RootTab) -> some View {
        let isSelected = (tab == selectedTab)
        return HStack(spacing: 6) {
            if showIcons {
                Image(systemName: tab.systemImage)
                    .font(DesignSystem.Typography.body)
                    .symbolEffect(.bounce, value: bounceTab == tab)
            }

            if showText {
                Text(tab.title)
                    .font(DesignSystem.Typography.body)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, showText ? 8 : 0)
        .scaleEffect(hoveredTab == tab ? 1.02 : 1)
        .foregroundColor(isSelected ? settings.activeAccentColor : Color.secondary)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
    }

    private func tabButton(for tab: RootTab) -> some View {
        Button {
            select(tab)
        } label: {
            tabLabel(for: tab)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredTab = hovering ? tab : nil
        }
        .buttonStyle(FloatingTabButtonStyle(isSelected: tab == selectedTab))
        .animation(.easeInOut(duration: 0.25), value: hoveredTab)
    }

    private func select(_ tab: RootTab) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            selectedTab = tab
        }
        bounceTab = tab
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            bounceTab = nil
        }
        print("[TabBar] selected = \(tab.logKey)")
    }
}

private struct FloatingTabButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, isSelected ? 12 : 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DesignSystem.Materials.hud.opacity(isSelected ? 0.95 : (colorScheme == .dark ? 0.6 : 0.7)))
                    .background(
                        isSelected ?
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.accentColor)
                        : nil
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(isSelected ? 0.25 : (colorScheme == .dark ? 0.04 : 0.12)), lineWidth: 0.6)
                    )
            )
                        .scaleEffect(configuration.isPressed ? (isSelected ? 0.96 : 0.97) : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
