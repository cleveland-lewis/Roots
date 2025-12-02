import SwiftUI

struct GlassButtonStyle: ButtonStyle {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(width: 48, height: 48)
            .background(.ultraThinMaterial)
            .opacity(configuration.isPressed ? 0.6 : settings.glassOpacity(for: colorScheme))
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
            .symbolEffect(.bounce)
    }
}

// The app previously used a custom GlassProminentButtonStyle here; switch usages to GlassProminentBlueButtonStyle via the global extension. Keep this file for legacy GlassButtonStyle only.

