import SwiftUI

struct GlassAccentIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.8))
                        .background(Circle().fill(.ultraThinMaterial))
                )
                .overlay(
                    Circle().stroke(.white.opacity(0.12), lineWidth: 0.75)
                )
                .shadow(color: Color.accentColor.opacity(0.25), radius: 14, y: 8)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

struct GlassSecondaryIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                        .background(Circle().fill(.ultraThinMaterial))
                )
                .overlay(
                    Circle().stroke(.white.opacity(0.12), lineWidth: 0.75)
                )
                .shadow(color: Color.primary.opacity(0.12), radius: 14, y: 8)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

