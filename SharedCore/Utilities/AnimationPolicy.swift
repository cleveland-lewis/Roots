import SwiftUI
import Combine

/// Centralized animation policy that respects system accessibility settings
/// Use this instead of direct `withAnimation` or `.animation` calls to ensure
/// proper Reduce Motion support throughout the app
@MainActor
public final class AnimationPolicy: ObservableObject {
    
    /// Shared singleton instance
    public static let shared = AnimationPolicy()
    
    /// Whether reduce motion is currently enabled
    @Published public private(set) var isReduceMotionEnabled: Bool = false
    
    private init() {
        updateReduceMotionStatus()
        
        // Listen for accessibility changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateReduceMotionStatus()
            }
        }
    }
    
    /// Update the reduce motion status from system preferences
    private func updateReduceMotionStatus() {
        #if os(macOS)
        isReduceMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        #endif
    }
    
    // MARK: - Animation Contexts
    
    /// Animation context defines the purpose/type of animation
    public enum AnimationContext {
        /// Essential UI state changes (selection, focus)
        case essential
        /// Non-essential UI embellishments (hover effects, springs)
        case decorative
        /// Chart animations (drawing, transitions)
        case chart
        /// Continuous animations (shimmer, pulsing, floating)
        case continuous
        /// Navigation transitions
        case navigation
        /// List item transitions
        case listTransition
    }
    
    // MARK: - Animation Policy Methods
    
    /// Get the appropriate animation for the given context
    /// Returns nil if animations should be disabled for this context
    public func animation(for context: AnimationContext) -> Animation? {
        guard !isReduceMotionEnabled else {
            // When reduce motion is enabled, only allow essential animations
            // and make them much shorter
            switch context {
            case .essential:
                return .linear(duration: 0.1)
            case .decorative, .chart, .continuous, .navigation, .listTransition:
                return nil
            }
        }
        
        // Normal animation behavior
        switch context {
        case .essential:
            return .easeInOut(duration: 0.25)
        case .decorative:
            return .spring(response: 0.35, dampingFraction: 0.7)
        case .chart:
            return .easeInOut(duration: 0.8)
        case .continuous:
            return .linear(duration: 1.5).repeatForever(autoreverses: true)
        case .navigation:
            return .easeInOut(duration: 0.3)
        case .listTransition:
            return .spring(response: 0.4, dampingFraction: 0.8)
        }
    }
    
    /// Execute a block with animation appropriate for the context
    public func withAnimation<Result>(
        _ context: AnimationContext,
        _ body: () throws -> Result
    ) rethrows -> Result {
        if let animation = animation(for: context) {
            return try SwiftUI.withAnimation(animation, body)
        } else {
            return try body()
        }
    }
    
    /// Get animation duration for the context (useful for custom animations)
    public func duration(for context: AnimationContext) -> Double {
        guard !isReduceMotionEnabled else {
            return context == .essential ? 0.1 : 0
        }
        
        switch context {
        case .essential:
            return 0.25
        case .decorative:
            return 0.35
        case .chart:
            return 0.8
        case .continuous:
            return 1.5
        case .navigation:
            return 0.3
        case .listTransition:
            return 0.4
        }
    }
    
    /// Whether animations should be shown for this context
    public func shouldAnimate(for context: AnimationContext) -> Bool {
        guard !isReduceMotionEnabled else {
            return context == .essential
        }
        return true
    }
}

// MARK: - View Extensions

extension View {
    /// Apply animation using the centralized animation policy
    public func animationPolicy(_ context: AnimationPolicy.AnimationContext, value: some Equatable) -> some View {
        if let animation = AnimationPolicy.shared.animation(for: context) {
            return self.animation(animation, value: value)
        } else {
            return self.animation(nil, value: value)
        }
    }
    
    /// Apply transition using the centralized animation policy
    public func transitionPolicy(_ context: AnimationPolicy.AnimationContext) -> some View {
        let policy = AnimationPolicy.shared
        
        if policy.isReduceMotionEnabled {
            // Use instant or fade transitions when reduce motion is enabled
            if context == .essential {
                return AnyView(self.transition(.opacity))
            } else {
                return AnyView(self.transition(.identity))
            }
        } else {
            // Use appropriate transitions for context
            switch context {
            case .essential, .navigation:
                return AnyView(self.transition(.opacity))
            case .decorative, .listTransition:
                return AnyView(self.transition(.scale.combined(with: .opacity)))
            case .chart:
                return AnyView(self.transition(.opacity))
            case .continuous:
                return AnyView(self.transition(.identity))
            }
        }
    }
}

// MARK: - Environment Key

@MainActor
private struct AnimationPolicyKey: EnvironmentKey {
    static let defaultValue = AnimationPolicy.shared
}

extension EnvironmentValues {
    public var animationPolicy: AnimationPolicy {
        get { self[AnimationPolicyKey.self] }
        set { self[AnimationPolicyKey.self] = newValue }
    }
}
