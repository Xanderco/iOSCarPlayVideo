import Foundation
import AVFoundation
import Combine

@MainActor
public final class SoundPlayerEngine: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = SoundPlayerEngine()

    @Published public private(set) var currentlyPlayingId: String?

    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?
    private var customAudioPlayer: AVAudioPlayer?

    public override init() {
        super.init()
        try? configureAudioSession()
    }

    /// Configures audio session category for in-car chime alerts with other audio ducked.
    public func configureAudioSession(duckOthers: Bool = true) throws {
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = []
        if duckOthers {
            options.insert(.duckOthers)
        }
        try session.setCategory(.playback, mode: .default, options: options)
        try session.setActive(true)
    }

    public func play(sound: SoundEffectItem) {
        stop()

        currentlyPlayingId = sound.id
        UsageMetricsManager.shared.recordSoundPlayed()

        // Check if custom audio file exists
        if sound.isCustom, let fileURL = sound.fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            playCustomAudioFile(url: fileURL, soundId: sound.id, gain: sound.normalizationGain)
        } else {
            // Synthesize acoustic automotive tone
            playTone(frequency: sound.frequencyHz, durationSeconds: 0.8, soundId: sound.id)
        }
    }

    public func playSound(id: String) {
        if let sound = SoundCatalogService.shared.sound(for: id) {
            play(sound: sound)
        }
    }

    /// Triggers the configured CarPlay connection chime with audio session ducking.
    public func triggerCarPlayConnectionSound() {
        let prefs = PersistenceController.shared.loadUserPreferences()
        let soundId = prefs.connectionSoundId ?? "jet_startup"
        if let sound = SoundCatalogService.shared.sound(for: soundId) {
            try? configureAudioSession(duckOthers: true)
            play(sound: sound)
        }
    }

    /// Triggers the configured CarPlay disconnection chime.
    public func triggerCarPlayDisconnectionSound() {
        let prefs = PersistenceController.shared.loadUserPreferences()
        let soundId = prefs.disconnectionSoundId ?? "airline_dingy"
        if let sound = SoundCatalogService.shared.sound(for: soundId) {
            try? configureAudioSession(duckOthers: true)
            play(sound: sound)
        }
    }

    public func stop() {
        tonePlayer?.stop()
        audioEngine?.stop()
        customAudioPlayer?.stop()
        customAudioPlayer = nil
        currentlyPlayingId = nil
    }

    // MARK: - Custom Audio File Playback

    private func playCustomAudioFile(url: URL, soundId: String, gain: Float) {
        do {
            try configureAudioSession(duckOthers: true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            // Apply volume normalization gain clamped between 0.15 and 1.0
            player.volume = min(1.0, max(0.15, gain))
            player.prepareToPlay()
            player.play()
            self.customAudioPlayer = player
        } catch {
            print("Failed to play custom audio file: \(error). Falling back to synthetic tone.")
            playTone(frequency: 440, durationSeconds: 0.8, soundId: soundId)
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.currentlyPlayingId = nil
            self.customAudioPlayer = nil
        }
    }

    nonisolated public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.currentlyPlayingId = nil
            self.customAudioPlayer = nil
        }
    }

    // MARK: - Synthetic Audio Tone

    private func playTone(frequency: Double, durationSeconds: Double, soundId: String) {
        try? configureAudioSession(duckOthers: true)

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

            // Reset state after duration
            Task {
                try? await Task.sleep(nanoseconds: UInt64((durationSeconds + 0.1) * 1_000_000_000))
                if self.currentlyPlayingId == soundId {
                    self.currentlyPlayingId = nil
                }
            }
        } catch {
            print("Audio engine failed: \(error)")
        }
    }
}
