import SwiftUI

// MARK: - Colors (semantic)
enum RootsColor {
    static var backgroundPrimary: Color { Color(nsColor: .windowBackgroundColor) }
    static var cardBackground: Color { Color(nsColor: .controlBackgroundColor) }
    static var glassBorder: Color { Color(nsColor: .separatorColor) }
    static var accent: Color { .accentColor }
    static var textPrimary: Color { .primary }
    static var textSecondary: Color { .secondary }
    static var label: Color { .primary }
    static var secondaryLabel: Color { .secondary }
    static var subtleFill: Color { Color.primary.opacity(0.06) }
}

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

// MARK: - Shadows
extension View {
    func rootsCardShadow() -> some View {
        shadow(color: Color.primary.opacity(0.08), radius: 18, y: 8)
    }

    func rootsFloatingShadow() -> some View {
        shadow(color: Color.primary.opacity(0.12), radius: 20, y: 10)
    }
}

// MARK: - Typography
extension Text {
    func rootsTitle() -> some View { font(.system(size: 22, weight: .semibold)).applyPopupTextAlignment() }
    func rootsSectionHeader() -> some View { font(.system(size: 14, weight: .semibold)).applyPopupTextAlignment() }
    func rootsBody() -> some View { font(.system(size: 13, weight: .regular)).applyPopupTextAlignment() }
    func rootsBodySecondary() -> some View { font(.system(size: 13)).foregroundColor(.secondary).applyPopupTextAlignment() }
    func rootsCaption() -> some View { font(.footnote).foregroundColor(.secondary).applyPopupTextAlignment() }
    func rootsMono() -> some View { font(.system(.body, design: .monospaced)).applyPopupTextAlignment() }
}

// MARK: - Glass / Background helpers
extension View {
    func rootsGlassBackground(opacity: Double = 0.2, radius: CGFloat = RootsRadius.card) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(opacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
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
}
