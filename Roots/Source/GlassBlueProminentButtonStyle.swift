import SwiftUI

struct GlassBlueProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.subHeader)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Cards.cardCornerRadius, style: .continuous)
                        .fill(LinearGradient(colors: [Color.blue.opacity(0.85), Color.blue], startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: DesignSystem.Cards.cardCornerRadius, style: .continuous)
                        .fill(DesignSystem.Materials.card)
                        .opacity(0.15)
                    RoundedRectangle(cornerRadius: DesignSystem.Cards.cardCornerRadius, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 0.5)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Cards.cardCornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.12))
                    .blendMode(.softLight)
                    .opacity(configuration.isPressed ? 0.25 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(Rectangle())
            .onHover { hovering in
                #if canImport(AppKit)
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                #endif
            }
    }
}

extension ButtonStyle where Self == GlassBlueProminentButtonStyle {
    static var glassBlueProminent: GlassBlueProminentButtonStyle { GlassBlueProminentButtonStyle() }
}
