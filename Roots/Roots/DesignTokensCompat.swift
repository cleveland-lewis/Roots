import SwiftUI

// Compatibility shim for legacy helpers. The canonical definitions live in
// DesignSystem/DesignTokens.swift and Components/. This file now only hosts
// helpers that are not defined elsewhere to avoid redeclaration errors.

// MARK: - Spacing
enum RootsSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Radius
enum RootsRadius {
    static let card: CGFloat = 24
    static let popup: CGFloat = 20
    static let chip: CGFloat = 12
}

// MARK: - Colors
enum RootsColor {
    static var glassBorder: Color { Color(nsColor: .separatorColor) }
    static var textPrimary: Color { .primary }
    static var textSecondary: Color { .secondary }
    static var cardBackground: Color { Color(nsColor: .controlBackgroundColor) }
    static var subtleFill: Color { Color(nsColor: .controlBackgroundColor).opacity(0.4) }
    static var accent: Color { .accentColor }
}

// MARK: - Typography
extension Text {
    func rootsSectionHeader() -> some View {
        font(.system(size: 14, weight: .semibold))
    }

    func rootsBody() -> some View {
        font(.system(size: 13, weight: .regular))
    }

    func rootsBodySecondary() -> some View {
        font(.system(size: 13)).foregroundColor(.secondary)
    }

    func rootsCaption() -> some View {
        font(.footnote).foregroundColor(.secondary)
    }
}

extension View {
    func rootsSystemBackground() -> some View {
        background(Color(nsColor: .windowBackgroundColor))
    }

    func rootsCardBackground(radius: CGFloat = RootsRadius.card) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(RootsColor.glassBorder, lineWidth: 1)
        )
    }

    func rootsGlassBackground(opacity: Double = 0.2, radius: CGFloat = RootsRadius.card) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(opacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    func rootsFloatingShadow() -> some View {
        shadow(color: Color.primary.opacity(0.12), radius: 20, y: 10)
    }

    func rootsCardShadow() -> some View {
        shadow(color: Color.primary.opacity(0.08), radius: 18, y: 8)
    }
}

// MARK: - Components

struct RootsPopupContainer<Content: View, Footer: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: RootsSpacing.l) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).rootsSectionHeader()
                if let subtitle { Text(subtitle).rootsCaption() }
            }
            Divider()
            content
            Divider()
            footer
        }
        .padding(.horizontal, RootsSpacing.xl)
        .padding(.vertical, RootsSpacing.l)
        .frame(maxWidth: 560)
        .rootsGlassBackground(opacity: 0.20, radius: RootsRadius.popup)
        .rootsFloatingShadow()
        .popupTextAlignedLeft()
    }
}

struct RootsFormRow<Control: View, Helper: View>: View {
    var label: String
    @ViewBuilder var control: Control
    @ViewBuilder var helper: Helper

    init(label: String, @ViewBuilder control: () -> Control, @ViewBuilder helper: () -> Helper = { EmptyView() }) {
        self.label = label
        self.control = control()
        self.helper = helper()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: RootsSpacing.m) {
                Text(label)
                    .rootsBodySecondary()
                    .frame(width: 110, alignment: Alignment.leading)
                control
            }
            helper
        }
    }
}

struct RootsCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    var icon: String?
    var footer: AnyView?
    var compact: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? RootsSpacing.m : RootsSpacing.l) {
            if title != nil || icon != nil || subtitle != nil {
                HStack(spacing: RootsSpacing.s) {
                    if let icon { Image(systemName: icon) }
                    VStack(alignment: .leading, spacing: 2) {
                        if let title { Text(title).rootsSectionHeader() }
                        if let subtitle { Text(subtitle).rootsCaption() }
                    }
                    Spacer()
                }
            }

            content

            if let footer {
                Divider()
                footer
            }
        }
        .padding(compact ? RootsSpacing.m : RootsSpacing.l)
        .rootsCardBackground()
        .rootsCardShadow()
    }
}

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
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering }
        }
        .accessibilityLabel(title)
    }
}
