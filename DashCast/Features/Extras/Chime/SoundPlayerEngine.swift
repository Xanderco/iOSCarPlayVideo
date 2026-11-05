import Foundation
import AVFoundation

/// Synthesizes and plays car chimes on device.
@MainActor
public final class SoundPlayerEngine: ObservableObject {
    public static let shared = SoundPlayerEngine()

    @Published public private(set) var currentlyPlayingId: String?

    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?

    public init() {}

    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Mix with whatever is already playing in the car and only duck it briefly.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    public func play(sound: SoundEffectItem) {
        stop()
        activateAudioSession()

        currentlyPlayingId = sound.id
        UsageMetricsManager.shared.recordSoundPlayed()

        playNotes(sound.notes)

        let soundId = sound.id
        let nanoseconds = UInt64(sound.duration * 1_000_000_000)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard let self, self.currentlyPlayingId == soundId else { return }
            self.stop()
        }
    }

    /// Plays the chime selected in Settings › Car Chime. Used by the Shortcuts action.
    public func playSelectedChime() {
        play(sound: SoundCatalogService.shared.selectedSound())
    }

    public func stop() {
        tonePlayer?.stop()
        audioEngine?.stop()
        tonePlayer = nil
        audioEngine = nil
        if currentlyPlayingId != nil {
            currentlyPlayingId = nil
            deactivateAudioSession()
        }
    }

    /// Renders the note sequence into one buffer: each note is a sine with a soft
    /// attack, an exponential decay and a quieter octave overtone.
    private func playNotes(_ notes: [Double]) {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let sampleRate = 44_100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        engine.connect(player, to: engine.mainMixerNode, format: format)

        let noteSamples = Int(sampleRate * SoundEffectItem.noteLength)
        let tailSamples = Int(sampleRate * 0.35)
        let totalSamples = noteSamples * notes.count + tailSamples
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalSamples)),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(totalSamples)

        for i in 0..<totalSamples { channel[i] = 0 }

        let ringSamples = noteSamples + tailSamples
        for (index, frequency) in notes.enumerated() {
            let start = index * noteSamples
            for n in 0..<ringSamples where start + n < totalSamples {
                let t = Double(n) / sampleRate
                let attack = min(t / 0.01, 1.0)
                let decay = exp(-5.0 * t)
                let phase = 2.0 * Double.pi * frequency * t
                let sample = (sin(phase) + 0.25 * sin(2.0 * phase)) * attack * decay * 0.3
                channel[start + n] += Float(sample)
            }
        }

        do {
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
            player.play()
            audioEngine = engine
            tonePlayer = player
        } catch {
            print("Audio engine failed: \(error)")
        }
    }
}
