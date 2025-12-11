import SwiftUI

extension DesignSystem {
    struct Motion {
        // Physics
        static let interactiveSpring: Animation = .spring(response: 0.3, dampingFraction: 0.7)
        static let layoutSpring: Animation = .spring(response: 0.5, dampingFraction: 0.8)
        static let wobblySpring: Animation = .spring(response: 0.4, dampingFraction: 0.5)

        // Durations
        static let short: TimeInterval = 0.2
        static let medium: TimeInterval = 0.4

        // Transitions
        static let listTransition: AnyTransition = .move(edge: .bottom).combined(with: .opacity)
    }
}
