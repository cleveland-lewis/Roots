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
        let overlayView: AnyView = {
            switch shape {
            case .rect(let cornerRadius):
                // Layer material, tint, highlights and subtle blur to resemble liquid glass
                return AnyView(
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(DesignSystem.Materials.card)

                        // Tint overlay
                        if glass.tintColor != .clear {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(glass.tintColor.opacity(0.12))
                        }

                        // Glow/highlight
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(LinearGradient(colors: [Color(nsColor: .separatorColor).opacity(0.6), Color(nsColor: .separatorColor).opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            .blendMode(.overlay)

                        // Inner subtle shadow
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.04), lineWidth: 0.5)
                            .blendMode(.multiply)
                    }
                )
            }
        }()

        return self
            .overlay(overlayView)
            .clipShape(RoundedRectangle(cornerRadius: {
                switch shape {
                case .rect(let r): return r
                }
            }()))
            .contentShape(Rectangle())
            .allowsHitTesting(glass.isInteractive)
    }
}
