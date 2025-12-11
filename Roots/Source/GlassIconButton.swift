import SwiftUI

/// Reusable glassy circular icon button used for top-level controls.
struct GlassIconButton: View {
    var systemName: String
    var accessibilityLabel: String?
    var action: () -> Void

    var body: some View {
        RootsHeaderButton(icon: systemName, size: 40) {
            action()
        }
        .accessibilityLabel(accessibilityLabel ?? systemName)
    }
}

/// Visual match for GlassIconButton when used as a Menu label.
struct GlassIconButtonLabel: View {
    var systemName: String
    var accessibilityLabel: String?

    var body: some View {
        // Render as a non-interactive label visually matching the icon button
        Image(systemName: systemName)
            .font(DesignSystem.Typography.body)
            .foregroundStyle(Color.primary)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DesignSystem.Materials.hud)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: Color.primary.opacity(0.12), radius: 12, y: 6)
            .contentShape(Circle())
            .accessibilityLabel(accessibilityLabel ?? systemName)
            .accessibilityAddTraits(.isButton)
    }
}
