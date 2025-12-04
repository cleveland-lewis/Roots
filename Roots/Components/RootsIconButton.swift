import SwiftUI

enum RootsIconButtonRole { case primaryAccent, secondary, destructive }

struct RootsIconButton: View {
    var iconName: String
    var role: RootsIconButtonRole = .primaryAccent
    var size: CGFloat = 44
    var action: () -> Void

    @State private var hover = false
    @State private var press = false

    private var background: Color {
        switch role {
        case .primaryAccent: return RootsColor.accent
        case .secondary: return RootsColor.subtleFill
        case .destructive: return Color.red.opacity(0.85)
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(role == .secondary ? .primary : .white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(background.opacity(role == .secondary ? 0.1 : 0.8))
                        .background(Circle().fill(.ultraThinMaterial))
                )
                .overlay(
                    Circle().stroke(.white.opacity(0.12), lineWidth: 0.75)
                )
                .shadow(color: background.opacity(0.25), radius: 14, y: 8)
                .scaleEffect(press ? 0.96 : (hover ? 1.03 : 1.0))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in press = true }
                .onEnded { _ in press = false }
        )
        .contentShape(Circle())
    }
}

