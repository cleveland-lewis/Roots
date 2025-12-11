import SwiftUI

struct RootsHeaderButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void

    @State private var isHovering: Bool = false

    init(icon: String, size: CGFloat = 36, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.body)
                .foregroundColor(.primary)
                .frame(width: size, height: size)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Circle()
                .fill(DesignSystem.Materials.hud)
                .opacity(isHovering ? 1.0 : 0.9)
                .shadow(color: Color.black.opacity(isHovering ? 0.08 : 0.03), radius: isHovering ? 6 : 3, x: 0, y: 2)
        )
        .contentShape(Circle())
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(DesignSystem.Motion.interactiveSpring, value: isHovering)
        .animation(DesignSystem.Motion.interactiveSpring, value: icon)
        .onHover { hover in
            withAnimation(DesignSystem.Motion.interactiveSpring) { isHovering = hover }
        }
    }
}
