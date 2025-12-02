import SwiftUI

// Glass Prominent Blue Button Style
// Created: 2025-12-02T14:37:28.718Z

public struct GlassProminentBlueButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        GlassProminentBlueButton(configuration: configuration)
    }

    private struct GlassProminentBlueButton: View {
        let configuration: Configuration
        @Environment(\.colorScheme) private var colorScheme
        @State private var hovering: Bool = false

        private var baseBlue: Color { Color.accentColor }
        private var cornerRadius: CGFloat { 26 }
        private var strokeWidth: CGFloat { 1.4 }

        private var glassOpacity: Double {
            colorScheme == .dark ? 0.18 : 0.35
        }
        private var tintOpacity: Double {
            (colorScheme == .dark ? 0.33 : 0.22) + (hovering ? 0.06 : 0)
        }

        private var shadowOpacity: Double { colorScheme == .dark ? 0.25 : 0.18 }

        var body: some View {
            let isPressed = configuration.isPressed
            let scale: CGFloat = isPressed ? 0.96 : (hovering ? 1.03 : 1.0)
            let yOffset: CGFloat = hovering ? -1.5 : -0.5

            configuration.label
                .font(.headline) // Default typography (short labels look best)
                .foregroundColor(Color.white.opacity(colorScheme == .dark ? 0.92 : 0.84))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        // Material glass layer
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(glassOpacity)

                        // Blue tint overlay
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(baseBlue)
                            .opacity(tintOpacity)

                        // Soft inner glow under the material layer
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            .blur(radius: 6)
                            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)))
                    }
                )
                .overlay(
                    // Subtle stroke (white/blue blend approximation at 30% opacity)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.18).blendMode(.overlay), lineWidth: strokeWidth)
                )
                .overlay(
                    // Highlight ring on press
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(isPressed ? 0.28 : 0), lineWidth: isPressed ? 2.2 : 0)
                        .scaleEffect(isPressed ? 0.98 : 1.0)
                        .animation(.easeOut(duration: 0.18), value: isPressed)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: Color.black.opacity(shadowOpacity), radius: 20, x: 0, y: 10)
                .scaleEffect(scale)
                .offset(y: yOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hovering)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
                .onHover { hovering = $0 }
                .symbolEffect(.bounce, value: isPressed)
        }
    }
}

// Reusable API
extension ButtonStyle where Self == GlassProminentBlueButtonStyle {
    static var glassBlueProminent: GlassProminentBlueButtonStyle { .init() }
}
