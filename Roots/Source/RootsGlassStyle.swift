import SwiftUI

enum RootsGlassStyle {
    static var cardCornerRadius: CGFloat { 16 }
    static var chromeCornerRadius: CGFloat { 12 }

    static var cardShadow: Color { Color.black.opacity(0.18) }
    static var chromeShadow: Color { Color.black.opacity(0.12) }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            )
            .shadow(color: RootsGlassStyle.cardShadow, radius: 8, x: 0, y: 4)
    }
}

extension View {
    /// Glass card surface (for Dashboard cards, metrics, panels, popups).
    func glassCard(cornerRadius: CGFloat = RootsGlassStyle.cardCornerRadius) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    /// Glass chrome surface (for tab bars, chips, navigation chrome).
    func glassChrome(cornerRadius: CGFloat = RootsGlassStyle.chromeCornerRadius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignSystem.Materials.hud)
            )
            .shadow(color: RootsGlassStyle.chromeShadow, radius: 6, x: 0, y: 2)
    }
}
