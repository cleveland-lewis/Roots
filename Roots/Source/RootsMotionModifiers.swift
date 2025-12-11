import SwiftUI

struct RootsHoverEffect: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.02 : 1)
            .animation(DesignSystem.Motion.interactiveSpring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct RootsPressEffect: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.92 : 1)
            .animation(DesignSystem.Motion.interactiveSpring, value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

extension View {
    func rootsStandardInteraction() -> some View {
        modifier(RootsHoverEffect())
            .modifier(RootsPressEffect())
    }
}
