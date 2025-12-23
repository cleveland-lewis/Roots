import Foundation
import AVFoundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Feedback Types

enum FeedbackType {
    case taskCompleted
    case taskCreated
    case timerStart
    case timerStop
    case success
    case warning
    case error
    case selection
}

// MARK: - Feedback Service

@MainActor
class Feedback {
    static let shared = Feedback()
    
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var settings: AppSettingsModel { AppSettingsModel.shared }
    
    private init() {
        // Preload audio files
        Task {
            await preloadSounds()
        }
    }
    
    // MARK: - Public API
    
    func play(_ type: FeedbackType) {
        // Play sound if enabled
        if shouldPlaySound() {
            playSound(for: type)
        }
        
        // Play haptic if enabled
        if shouldPlayHaptic() {
            playHaptic(for: type)
        }
        
        // Log for debugging
        LOG_UI(.debug, "Feedback", "Played feedback", metadata: ["type": "\(type)"])
    }
    
    // MARK: - Sound Playback
    
    private func playSound(for type: FeedbackType) {
        let soundName = soundFileName(for: type)
        
        // Try to play from preloaded cache
        if let player = audioPlayers[soundName] {
            player.currentTime = 0
            player.play()
            return
        }
        
        // Load and play if not cached
        guard let url = soundURL(for: soundName) else {
            LOG_UI(.warn, "Feedback", "Sound file not found", metadata: ["sound": soundName])
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            audioPlayers[soundName] = player
        } catch {
            LOG_UI(.error, "Feedback", "Failed to play sound", metadata: ["sound": soundName, "error": error.localizedDescription])
        }
    }
    
    private func soundFileName(for type: FeedbackType) -> String {
        switch type {
        case .taskCompleted:
            return "task_complete"
        case .taskCreated:
            return "task_created"
        case .timerStart:
            return "timer_start"
        case .timerStop:
            return "timer_stop"
        case .success:
            return "success"
        case .warning:
            return "warning"
        case .error:
            return "error"
        case .selection:
            return "selection"
        }
    }
    
    private func soundURL(for name: String) -> URL? {
        // Check for custom sound file
        if let url = Bundle.main.url(forResource: name, withExtension: "aiff") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "mp3") {
            return url
        }
        
        // Fall back to system sound for now
        // In production, you would bundle actual sound files
        return nil
    }
    
    private func preloadSounds() async {
        // Preload commonly used sounds
        let commonSounds = ["task_complete", "success"]
        
        for soundName in commonSounds {
            guard let url = soundURL(for: soundName) else { continue }
            
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                audioPlayers[soundName] = player
            } catch {
                // Silently fail preload - will try on demand
            }
        }
    }
    
    // MARK: - Haptic Playback
    
    private func playHaptic(for type: FeedbackType) {
        #if os(iOS)
        switch type {
        case .taskCompleted, .success, .taskCreated, .timerStop:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .timerStart:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
        #elseif os(macOS)
        let manager = NSHapticFeedbackManager.defaultPerformer
        switch type {
        case .taskCompleted, .success, .selection, .taskCreated, .timerStart, .timerStop:
            manager.perform(.generic, performanceTime: .now)
        case .warning, .error:
            manager.perform(.levelChange, performanceTime: .now)
        }
        #endif
    }
    
    // MARK: - Settings Check
    
    private func shouldPlaySound() -> Bool {
        // Check if sounds are enabled in system
        #if os(iOS)
        // On iOS, respect system sound settings
        return true // AVAudioSession will handle mute switch automatically
        #elseif os(macOS)
        // On macOS, always allow (user can control volume)
        return true
        #else
        return true
        #endif
    }
    
    private func shouldPlayHaptic() -> Bool {
        // Check user preference for haptics
        guard settings.enableHaptics else { return false }
        
        // Respect Reduce Motion accessibility setting
        guard !settings.reduceMotion else { return false }
        
        return true
    }
}

// MARK: - Convenience Methods

extension Feedback {
    /// Play task completion feedback (sound + haptic)
    func taskCompleted() {
        play(.taskCompleted)
    }
    
    /// Play task creation feedback (sound + haptic)
    func taskCreated() {
        play(.taskCreated)
    }
    
    /// Play timer start feedback (sound + haptic)
    func timerStart() {
        play(.timerStart)
    }
    
    /// Play timer stop feedback (sound + haptic)
    func timerStop() {
        play(.timerStop)
    }
    
    /// Play success feedback (sound + haptic)
    func success() {
        play(.success)
    }
    
    /// Play error feedback (sound + haptic)
    func error() {
        play(.error)
    }
}
