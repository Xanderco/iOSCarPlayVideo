import Foundation
import AVFoundation

@MainActor
public final class SoundPlayerEngine: ObservableObject {
    public static let shared = SoundPlayerEngine()

    @Published public private(set) var currentlyPlayingId: String?

    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?

    public init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    public func play(sound: SoundEffectItem) {
        stop()

        currentlyPlayingId = sound.id
        UsageMetricsManager.shared.recordSoundPlayed()

        // Synthesize acoustic automotive tone
        playTone(frequency: sound.frequencyHz, durationSeconds: 0.8)

        // Reset state after duration
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            if self.currentlyPlayingId == sound.id {
                self.currentlyPlayingId = nil
            }
        }
    }

    public func stop() {
        tonePlayer?.stop()
        audioEngine?.stop()
        currentlyPlayingId = nil
    }

    private func playTone(frequency: Double, durationSeconds: Double) {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        engine.attach(player)

        let sampleRate = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }

        engine.connect(player, to: engine.mainMixerNode, format: format)

        let sampleCount = UInt32(sampleRate * durationSeconds)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: sampleCount) else { return }
        buffer.frameLength = sampleCount

        guard let channelData = buffer.floatChannelData?[0] else { return }

        let angularFrequency = 2.0 * .pi * frequency / sampleRate

        for i in 0..<Int(sampleCount) {
            // Envelope attack and decay for smooth organic chime
            let t = Double(i) / sampleRate
            let envelope = exp(-3.0 * t / durationSeconds) * sin(Double(i) * angularFrequency)
            channelData[i] = Float(envelope * 0.4)
        }

        do {
            try engine.start()
            player.play()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts) {
                // Buffer finished
            }
            self.audioEngine = engine
            self.tonePlayer = player
        } catch {
            print("Audio engine failed: \(error)")
        }
    }
}
