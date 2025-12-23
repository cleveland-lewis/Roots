import Foundation
import AVFoundation

/// Manages audio feedback for timer events
@MainActor
final class AudioFeedbackService {
    static let shared = AudioFeedbackService()
    
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private let settings = AppSettingsModel.shared
    
    private init() {
        setupAudio()
    }
    
    private func setupAudio() {
        // Configure audio session for ambient audio (doesn't interrupt other audio)
        #if os(macOS)
        // macOS doesn't need audio session configuration
        #else
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        #endif
    }
    
    /// Play timer start sound (pleasant upward tone)
    func playTimerStart() {
        guard settings.timerAlertsEnabled else { return }
        // Pleasant C major chord arpeggio (C5 -> E5 -> G5)
        playPleasantTone(frequencies: [523.25, 659.25, 783.99], duration: 0.5, volume: 0.25)
    }
    
    /// Play timer pause sound (gentle descending tone)
    func playTimerPause() {
        guard settings.timerAlertsEnabled else { return }
        // Gentle G5 -> E5 descent
        playPleasantTone(frequencies: [783.99, 659.25], duration: 0.4, volume: 0.22)
    }
    
    /// Play timer end sound (complete resolution)
    func playTimerEnd() {
        guard settings.timerAlertsEnabled else { return }
        // Satisfying C major chord: C5 + E5 + G5 together
        playChord(frequencies: [523.25, 659.25, 783.99], duration: 0.6, volume: 0.28)
    }
    
    /// Generate and play a simple sine wave tone
    private nonisolated func playSound(frequency: Double, duration: TimeInterval, volume: Float) {
        // Generate audio buffer with sine wave
        let sampleRate: Double = 44100
        let frameCount = Int(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(format.channelCount))
        guard let channel = channels.first else { return }
        
        // Generate sine wave with fade in/out envelope
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let sine = sin(2.0 * .pi * frequency * time)
            
            // Apply envelope (fade in/out)
            let fadeLength = min(frameCount / 10, 1000) // 10% fade or max 1000 samples
            var envelope: Float = 1.0
            
            if frame < fadeLength {
                envelope = Float(frame) / Float(fadeLength)
            } else if frame > frameCount - fadeLength {
                envelope = Float(frameCount - frame) / Float(fadeLength)
            }
            
            channel[frame] = Float(sine) * volume * envelope
        }
        
        // Play the buffer
        let player = AVAudioPlayerNode()
        let engine = AVAudioEngine()
        
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts) {
                // Cleanup after playing
                DispatchQueue.main.async {
                    engine.stop()
                }
            }
            player.play()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    /// Play a pleasant tone sequence (arpeggio)
    private nonisolated func playPleasantTone(frequencies: [Double], duration: TimeInterval, volume: Float) {
        let sampleRate: Double = 44100
        let totalDuration = duration
        let segmentDuration = totalDuration / Double(frequencies.count)
        let frameCount = Int(sampleRate * totalDuration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(format.channelCount))
        guard let channel = channels.first else { return }
        
        let segmentFrames = Int(sampleRate * segmentDuration)
        
        for (index, frequency) in frequencies.enumerated() {
            let startFrame = index * segmentFrames
            let endFrame = min(startFrame + segmentFrames, frameCount)
            
            for frame in startFrame..<endFrame {
                let time = Double(frame) / sampleRate
                
                // Richer tone with harmonics (fundamental + 2nd + 3rd harmonic)
                let fundamental = sin(2.0 * .pi * frequency * time)
                let harmonic2 = sin(2.0 * .pi * frequency * 2.0 * time) * 0.3
                let harmonic3 = sin(2.0 * .pi * frequency * 3.0 * time) * 0.15
                let richTone = fundamental + harmonic2 + harmonic3
                
                // Smooth envelope for each segment
                let localFrame = frame - startFrame
                let segmentProgress = Double(localFrame) / Double(segmentFrames)
                let fadeInLength = min(segmentFrames / 8, 500)
                let fadeOutLength = min(segmentFrames / 6, 800)
                
                var envelope: Float = 1.0
                if localFrame < fadeInLength {
                    envelope = Float(localFrame) / Float(fadeInLength)
                } else if localFrame > segmentFrames - fadeOutLength {
                    envelope = Float(segmentFrames - localFrame) / Float(fadeOutLength)
                }
                
                channel[frame] = Float(richTone) * volume * envelope * 0.7 // Normalize for harmonics
            }
        }
        
        playBuffer(buffer, format: format)
    }
    
    /// Play a chord (multiple frequencies simultaneously)
    private nonisolated func playChord(frequencies: [Double], duration: TimeInterval, volume: Float) {
        let sampleRate: Double = 44100
        let frameCount = Int(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(format.channelCount))
        guard let channel = channels.first else { return }
        
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            var sample: Double = 0
            
            // Blend all frequencies with harmonics
            for frequency in frequencies {
                let fundamental = sin(2.0 * .pi * frequency * time)
                let harmonic2 = sin(2.0 * .pi * frequency * 2.0 * time) * 0.2
                sample += (fundamental + harmonic2) / Double(frequencies.count)
            }
            
            // Smooth ADSR envelope (Attack, Decay, Sustain, Release)
            let attackTime = 0.05
            let releaseTime = 0.2
            let attackFrames = Int(sampleRate * attackTime)
            let releaseFrames = Int(sampleRate * releaseTime)
            
            var envelope: Float = 1.0
            if frame < attackFrames {
                // Attack: smooth cubic curve up
                let progress = Double(frame) / Double(attackFrames)
                envelope = Float(progress * progress)
            } else if frame > frameCount - releaseFrames {
                // Release: smooth exponential decay
                let progress = Double(frameCount - frame) / Double(releaseFrames)
                envelope = Float(progress * progress)
            }
            
            channel[frame] = Float(sample) * volume * envelope
        }
        
        playBuffer(buffer, format: format)
    }
    
    /// Helper to play an audio buffer
    private nonisolated func playBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) {
        let player = AVAudioPlayerNode()
        let engine = AVAudioEngine()
        
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts) {
                // Cleanup after playing
                DispatchQueue.main.async {
                    engine.stop()
                }
            }
            player.play()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    /// Alternative: Play system sounds (fallback if synthesis doesn't work)
    func playSystemSound(_ soundID: SystemSoundID) {
        guard settings.timerAlertsEnabled else { return }
        #if os(macOS)
        AudioServicesPlaySystemSound(soundID)
        #endif
    }
}

// MARK: - System Sound IDs (macOS)
extension AudioFeedbackService {
    /// Common macOS system sounds
    enum SystemSound {
        static let ping: SystemSoundID = 1103
        static let pop: SystemSoundID = 1104
        static let submarine: SystemSoundID = 1105
        static let tink: SystemSoundID = 1106
        static let funky: SystemSoundID = 1110
    }
}
