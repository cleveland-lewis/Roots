import SwiftUI

// Minimal Glass type and helper to support .glassEffect(...) usage in views
struct Glass {
    enum Style {
        case clear
        case frosted
    }

    var style: Style = .clear
    var tintColor: Color = .clear
    var isInteractive: Bool = false

    func tint(_ color: Color) -> Glass {
        var g = self
        g.tintColor = color
        return g
    }

    func interactive(_ enabled: Bool) -> Glass {
        var g = self
        g.isInteractive = enabled
        return g
    }
}

extension Glass {
    static let clear = Glass(style: .clear, tintColor: .clear, isInteractive: false)
}

enum GlassInsetShape {
    case rect(cornerRadius: CGFloat)
}

extension View {
    /// Applies a simple glass effect overlay. This is intentionally lightweight but can be extended.
    func glassEffect(_ glass: Glass, in shape: GlassInsetShape) -> some View {
        modifier(GlassEffectModifier(glass: glass, shape: shape))
    }
}

private struct GlassEffectModifier: ViewModifier {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.colorScheme) private var colorScheme
    var glass: Glass
    var shape: GlassInsetShape

    func body(content: Content) -> some View {
        content
            .overlay(overlayView)
            .clipShape(clipShape)
            .contentShape(Rectangle())
            .allowsHitTesting(glass.isInteractive)
    }

    @ViewBuilder
    private var overlayView: some View {
        let policy = MaterialPolicy(preferences: preferences)
        
        switch shape {
        case .rect(let cornerRadius):
            // Layer material, tint, highlights and subtle blur to resemble liquid glass
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(policy.cardMaterial(colorScheme: colorScheme))

                if glass.tintColor != .clear {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(glass.tintColor.opacity(0.12))
                }

                let neutral = DesignSystem.Colors.neutralLine(for: colorScheme)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                neutral.opacity(policy.borderOpacity * 5),
                                neutral.opacity(policy.borderOpacity * 0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: policy.borderWidth
                    )
                    .blendMode(.overlay)

                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(neutral.opacity(policy.borderOpacity * 0.33), lineWidth: policy.borderWidth * 0.5)
                    .blendMode(.multiply)
            }
        }
    }

    private var clipShape: some Shape {
        switch shape {
        case .rect(let r):
            return RoundedRectangle(cornerRadius: r)
        }
    }
}
