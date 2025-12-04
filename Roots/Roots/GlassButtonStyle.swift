import SwiftUI

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GlassButton(configuration: configuration)
    }

    private struct GlassButton: View {
        let configuration: Configuration
        @EnvironmentObject private var settings: AppSettings
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            configuration.label
                .padding()
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial)
                .opacity(configuration.isPressed ? 0.6 : settings.glassOpacity(for: colorScheme))
                .clipShape(Circle())
                .shadow(color: Color(nsColor: .separatorColor).opacity(0.08), radius: 16, x: 0, y: 8)
                .symbolEffect(.bounce)
        }
    }
}

// Keep file for legacy GlassButtonStyle only.
