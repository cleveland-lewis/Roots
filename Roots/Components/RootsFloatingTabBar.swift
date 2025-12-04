import SwiftUI

/// Lightweight wrapper that mirrors the app's floating tab bar behavior with full pill hit areas.
struct RootsFloatingTabBar: View {
    var items: [RootTab]
    @Binding var selected: RootTab
    var mode: TabBarMode
    var onSelect: (RootTab) -> Void

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let effectiveMode = resolvedTabBarMode(
                userMode: mode,
                availableWidth: availableWidth,
                tabCount: items.count
            )
            HStack(spacing: 8) {
                ForEach(items) { tab in
                    let isSelected = tab == selected
                    RootTabBarItem(
                        icon: tab.systemImage,
                        title: tab.title,
                        isSelected: isSelected,
                        displayMode: effectiveMode
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selected = tab
                            onSelect(tab)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(RootsColor.glassBorder, lineWidth: 1)
                    )
            )
            .frame(maxWidth: min(availableWidth - 32, 640))
            .frame(maxWidth: .infinity)
        }
        .frame(height: 72)
    }
}

// MARK: - Responsive mode resolver

func resolvedTabBarMode(
    userMode: TabBarMode,
    availableWidth: CGFloat,
    tabCount: Int
) -> TabBarMode {
    switch userMode {
    case .iconsOnly:
        return .iconsOnly
    case .textOnly, .iconsAndText:
        let perTabNeeded: CGFloat = userMode == .textOnly ? 80 : 110
        let totalNeeded = perTabNeeded * CGFloat(tabCount) + 16 * CGFloat(tabCount - 1) + 40
        if totalNeeded > availableWidth {
            return .iconsOnly
        } else {
            return userMode
        }
    }
}

// MARK: - Tab Item (full pill hit area)

struct RootTabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let displayMode: TabBarMode
    let action: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: displayMode == .iconsOnly ? 0 : 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))

                if displayMode != .iconsOnly {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minWidth: 44, minHeight: 32)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.09))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.primary.opacity(isSelected ? 0 : 0.12), lineWidth: 0.5)
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .scaleEffect(isHovering ? 1.03 : 1.0)
            .contentShape(Capsule(style: .continuous)) // full pill tappable
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering }
        }
        .accessibilityLabel(title)
    }
}
