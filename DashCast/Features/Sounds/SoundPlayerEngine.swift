import Foundation
import AVFoundation

public protocol SoundAudioSessionControlling: AnyObject {
    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

public final class SystemSoundAudioSession: SoundAudioSessionControlling {
    private let session: AVAudioSession

    public init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    public func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        try session.setCategory(category, mode: mode, options: options)
    }

    public func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        try session.setActive(active, options: options)
    }
}

@MainActor
public final class SoundPlayerEngine: ObservableObject {
    public static let shared = SoundPlayerEngine()

    @Published public private(set) var currentlyPlayingId: String?
    public private(set) var isAudioSessionActive: Bool = false

    private let audioSession: SoundAudioSessionControlling
    private let durationSeconds: Double
    private let completionDelayNanoseconds: UInt64
    private let sleepHandler: @Sendable (UInt64) async throws -> Void
    private let toneSynthesizer: ((Double, Double) -> Void)?
    private let recordPlaybackMetric: () -> Void

    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?
    private var completionTask: Task<Void, Never>?
    private var activePlaybackToken: UUID?

    public init(
        audioSession: SoundAudioSessionControlling? = nil,
        durationSeconds: Double = 0.8,
        completionDelayNanoseconds: UInt64 = 900_000_000,
        sleepHandler: (@Sendable (UInt64) async throws -> Void)? = nil,
        toneSynthesizer: ((Double, Double) -> Void)? = nil,
        recordPlaybackMetric: (() -> Void)? = nil
    ) {
        self.audioSession = audioSession ?? SystemSoundAudioSession()
        self.durationSeconds = durationSeconds
        self.completionDelayNanoseconds = completionDelayNanoseconds
        self.sleepHandler = sleepHandler ?? { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
        self.toneSynthesizer = toneSynthesizer
        self.recordPlaybackMetric = recordPlaybackMetric ?? {
            UsageMetricsManager.shared.recordSoundPlayed()
        }
    }

    public func play(sound: SoundEffectItem) {
        cancelActivePlayback(deactivateSession: false)
        activateAudioSessionIfNeeded()

        let token = UUID()
        activePlaybackToken = token
        currentlyPlayingId = sound.id
        recordPlaybackMetric()

        if let toneSynthesizer {
            toneSynthesizer(sound.frequencyHz, durationSeconds)
        } else {
            playTone(frequency: sound.frequencyHz, durationSeconds: durationSeconds)
        }

        let delay = completionDelayNanoseconds
        let sleep = sleepHandler
        completionTask = Task { [weak self] in
            do {
                try await sleep(delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.finishPlaybackIfMatching(token: token)
        }
    }

    public func stop() {
        cancelActivePlayback(deactivateSession: true)
        currentlyPlayingId = nil
    }

    private func finishPlaybackIfMatching(token: UUID) {
        guard activePlaybackToken == token else { return }
        stop()
    }

    private func cancelActivePlayback(deactivateSession: Bool) {
        activePlaybackToken = nil
        completionTask?.cancel()
        completionTask = nil
        tonePlayer?.stop()
        audioEngine?.stop()
        tonePlayer = nil
        audioEngine = nil
        if deactivateSession {
            deactivateAudioSessionIfNeeded()
        }
    }

    private func activateAudioSessionIfNeeded() {
        guard !isAudioSessionActive else { return }
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true, options: [])
            isAudioSessionActive = true
        } catch {
            print("Audio session activation error: \(error)")
        }
    }

    private func deactivateAudioSessionIfNeeded() {
        guard isAudioSessionActive else { return }
        isAudioSessionActive = false
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session deactivation error: \(error)")
        }
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
