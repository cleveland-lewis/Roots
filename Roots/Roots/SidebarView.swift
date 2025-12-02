import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: RootTab
    @Environment(\.colorScheme) private var colorScheme

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
            }

            Section("App") {
                SidebarItemRow(tab: .settings, title: "Settings", systemImage: "gearshape", selectedTab: $selectedTab)
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

    @Binding var selectedTab: RootTab
    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .symbolEffect(.bounce, value: isHovered)
        }
        .tag(tab)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTab = tab
            print("[Sidebar] navigate -> \(tab)")
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering { print("[Sidebar] hover over \(tab)") }
        }
        .labelStyle(.titleAndIcon)
        .listRowBackground(makeSidebarRowBackground(isSelected: selectedTab == tab, colorScheme: colorScheme))
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}
