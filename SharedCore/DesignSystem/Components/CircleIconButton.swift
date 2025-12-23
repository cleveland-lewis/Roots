import SwiftUI

struct CircleIconButton: View {
    let icon: String
    let iconColor: Color
    let size: CGFloat
    var backgroundMaterial: Material = DesignSystem.Materials.hud
    var backgroundOpacity: Double = 1
    var showsBorder: Bool = false
    var borderColor: Color = Color.primary.opacity(0.06)
    var borderWidth: CGFloat = 1
    var iconRotation: Angle = .zero
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(iconColor)
                .rotationEffect(iconRotation)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(backgroundMaterial)
                        .opacity(backgroundOpacity)
                )
                .overlay {
                    if showsBorder {
                        Circle()
                            .strokeBorder(borderColor, lineWidth: borderWidth)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .rootsStandardInteraction()
        .focusEffectDisabled(true)
    }
}
