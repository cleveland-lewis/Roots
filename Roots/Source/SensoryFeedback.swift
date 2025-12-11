import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum SensoryFeedback {
    case success
    case warning
    case error
    case selection
}

struct SensoryFeedbackModifier: ViewModifier {
    let feedback: SensoryFeedback
    @Binding var trigger: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { newValue in
                guard newValue else { return }
                performFeedback()
            }
    }

    private func performFeedback() {
        #if os(iOS)
        switch feedback {
        case .success:
            let g = UINotificationFeedbackGenerator()
            g.notificationOccurred(.success)
        case .warning:
            let g = UINotificationFeedbackGenerator()
            g.notificationOccurred(.warning)
        case .error:
            let g = UINotificationFeedbackGenerator()
            g.notificationOccurred(.error)
        case .selection:
            let g = UISelectionFeedbackGenerator()
            g.selectionChanged()
        }
        #elseif os(macOS)
        // macOS doesn't have standard haptic generators in AppKit; use NSHapticFeedbackManager
        let manager = NSHapticFeedbackManager.defaultPerformer
        switch feedback {
        case .success, .selection:
            manager.perform(.generic, performanceTime: .now)
        case .warning, .error:
            // levelChange is the closest distinct feel for warnings/errors
            manager.perform(.levelChange, performanceTime: .now)
        }
        #endif
    }
}

extension View {
    func sensoryFeedback(_ feedback: SensoryFeedback, trigger: Binding<Bool>) -> some View {
        modifier(SensoryFeedbackModifier(feedback: feedback, trigger: trigger))
    }

    /// Triggers the provided binding when the pointer hovers over the view (useful to kick off sensory feedback)
    func hoverTrigger(_ trigger: Binding<Bool>) -> some View {
        modifier(HoverTriggerModifier(trigger: trigger))
    }
}

struct HoverTriggerModifier: ViewModifier {
    @Binding var trigger: Bool

    func body(content: Content) -> some View {
        #if os(macOS)
        content.onHover { hovering in
            // set true on enter, reset on exit so each enter triggers feedback
            if hovering {
                trigger = true
            } else {
                trigger = false
            }
        }
        #else
        content
        #endif
    }
}