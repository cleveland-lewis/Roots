import SwiftUI
import _Concurrency

struct SidebarView: View {
    @Binding var selectedTab: RootTab
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        let selectionBinding = Binding<RootTab?>(
            get: { selectedTab },
            set: { if let v = $0 { selectedTab = v; print("[Sidebar] selected tab: \(selectedTab)") } }
        )

        List(selection: selectionBinding) {
            Section("Navigation") {
                SidebarItemRow(tab: .dashboard, title: "Dashboard", systemImage: "square.grid.2x2", selectedTab: $selectedTab)
                SidebarItemRow(tab: .calendar, title: "Calendar", systemImage: "calendar", selectedTab: $selectedTab)
                SidebarItemRow(tab: .planner, title: "Planner", systemImage: "pencil.and.list.clipboard", selectedTab: $selectedTab)
                SidebarItemRow(tab: .assignments, title: "Assignments", systemImage: "slider.horizontal.3", selectedTab: $selectedTab)
                SidebarItemRow(tab: .courses, title: "Courses", systemImage: "book.closed", selectedTab: $selectedTab)
                SidebarItemRow(tab: .grades, title: "Grades", systemImage: "doc.text.magnifyingglass", selectedTab: $selectedTab)
                SidebarItemRow(tab: .decks, title: "Decks", systemImage: "rectangle.stack", selectedTab: $selectedTab)
            }

        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(makeSidebarBackground(colorScheme: colorScheme))
    }
}

private struct SidebarItemRow: View {
    let tab: RootTab
    let title: String
    let systemImage: String
    private var accessibilityID: String {
        switch tab {
        case .calendar: return "Sidebar.Calendar"
        case .dashboard: return "Sidebar.Dashboard"
        default: return ""
        }
    }

    @Binding var selectedTab: RootTab
    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        Toggle(isOn: Binding(get: { selectedTab == tab }, set: { newVal in
            if newVal { selectedTab = tab }
        })) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .symbolEffect(.bounce, value: isHovered)
            }
            .rootsStandardInteraction()
        }
        .accessibilityIdentifier(accessibilityID.isEmpty ? "" : accessibilityID)
        .toggleStyle(.rootsAccent)
        .tag(tab)
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
            if hovering { print("[Sidebar] hover over \(tab)") }
        }
        .animation(DesignSystem.Motion.interactiveSpring, value: isHovered)
        .animation(DesignSystem.Motion.interactiveSpring, value: selectedTab)
        .modifier(TabLabelStyleModifier(mode: preferences.tabBarMode))
        .modifier(SidebarTooltipModifier(text: title))
    }
}

// Local tooltip implementation to ensure sidebar builds regardless of target linkage.
private struct SidebarTooltipModifier: ViewModifier {
    let text: String
    @State private var isVisible = false
    @State private var workItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                handleHover(hovering)
            }
            .overlay(alignment: .top) {
                if isVisible {
                    Text(text)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignSystem.Layout.spacing.small)
                        .padding(.vertical, DesignSystem.Layout.spacing.small)
                        .background(DesignSystem.Materials.hud, in: Capsule())
                        .shadow(radius: 4, y: 2)
                        .offset(y: -40)
                        .transition(.scale.combined(with: .opacity))
                }
            }
    }

    private func handleHover(_ hovering: Bool) {
        if hovering {
            let item = DispatchWorkItem { withAnimation(.easeInOut(duration: 0.2)) { isVisible = true } }
            workItem?.cancel()
            workItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: item)
        } else {
            workItem?.cancel()
            workItem = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                isVisible = false
            }
        }
    }
}

private struct TabLabelStyleModifier: ViewModifier {
    var mode: TabBarMode

    @ViewBuilder
    func body(content: Content) -> some View {
        switch mode {
        case .iconsOnly:
            content.labelStyle(.iconOnly)
        case .textOnly:
            content.labelStyle(.titleOnly)
        case .iconsAndText:
            content.labelStyle(.titleAndIcon)
        }
    }
}
