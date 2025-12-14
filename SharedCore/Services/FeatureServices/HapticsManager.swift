#if os(macOS)
import Foundation
import CoreHaptics
#if os(macOS)
import AppKit
#endif

enum HapticEventKind {
    case warning
    case error
}

final class HapticsManager {
    static let shared = HapticsManager()

    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false

    private init() {
        prepareEngineIfNeeded()
    }

    private func prepareEngineIfNeeded() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            supportsHaptics = false
            return
        }

        supportsHaptics = true
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            #if DEBUG
            print("Haptics engine failed to start: \(error)")
            #endif
            engine = nil
            supportsHaptics = false
        }
    }

    /// Plays haptic feedback respecting user preferences and accessibility settings
    /// - Parameter kind: The type of haptic feedback to play
    func play(_ kind: HapticEventKind) {
        // Respect user preferences via UserDefaults
        let enableHaptics = UserDefaults.standard.bool(forKey: "preferences.enableHaptics")
        guard enableHaptics || !UserDefaults.standard.dictionaryRepresentation().keys.contains("preferences.enableHaptics") else { return }
        
        // Respect Reduce Motion accessibility setting
        let reduceMotion = UserDefaults.standard.bool(forKey: "preferences.reduceMotion")
        guard !reduceMotion else { return }
        
        if supportsHaptics {
            switch kind {
            case .warning: playWarningPattern()
            case .error: playErrorPattern()
            }
        } else {
            // fallback
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }

    private func playWarningPattern() {
        guard supportsHaptics, let engine = engine else { return }

        // Short transient + soft continuous
        let events: [CHHapticEvent] = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4), CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.18), CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)], relativeTime: 0.03, duration: 0.12)
        ]

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            #if DEBUG
            print("Failed to play warning haptic: \(error)")
            #endif
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }

    private func playErrorPattern() {
        guard supportsHaptics, let engine = engine else { return }

        // Two strong transients (thud)
        let events: [CHHapticEvent] = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0), CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9), CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)], relativeTime: 0.12)
        ]

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            #if DEBUG
            print("Failed to play error haptic: \(error)")
            #endif
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }
}

#endif