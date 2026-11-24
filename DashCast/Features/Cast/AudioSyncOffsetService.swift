import Foundation
import AVFoundation
import Combine
import SwiftUI

/// Preset latency profiles for common automotive audio output configurations.
public enum AudioSyncPreset: String, CaseIterable, Identifiable, Codable {
    case wired
    case carplayWireless
    case bluetoothInDash
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wired:
            return "Wired (Lightning/USB-C)"
        case .carplayWireless:
            return "Wireless CarPlay"
        case .bluetoothInDash:
            return "Bluetooth In-Dash"
        case .custom:
            return "Custom Calibration"
        }
    }

    public var defaultOffsetMs: Double {
        switch self {
        case .wired:
            return 0.0
        case .carplayWireless:
            return 180.0
        case .bluetoothInDash:
            return 350.0
        case .custom:
            return 0.0
        }
    }

    public var iconName: String {
        switch self {
        case .wired:
            return "cable.connector"
        case .carplayWireless:
            return "car.fill"
        case .bluetoothInDash:
            return "wave.3.forward"
        case .custom:
            return "slider.horizontal.3"
        }
    }

    public var subtitle: String {
        switch self {
        case .wired:
            return "0 ms · Zero-latency direct cable"
        case .carplayWireless:
            return "+180 ms · Wi-Fi buffer compensation"
        case .bluetoothInDash:
            return "+350 ms · Headunit codec buffer compensation"
        case .custom:
            return "Manual microsecond adjustment"
        }
    }
}

/// Central service managing audio-to-video latency drift compensation.
/// Eliminates lip-sync delays over Bluetooth car audio systems and wireless CarPlay links.
@MainActor
public final class AudioSyncOffsetService: ObservableObject {
    public static let shared = AudioSyncOffsetService()

    public static let minOffsetMs: Double = -1500.0
    public static let maxOffsetMs: Double = 1500.0
    public static let stepMs: Double = 25.0

    private static let kOffsetKey = "dashcast.audioSyncOffsetMs"
    private static let kPresetKey = "dashcast.audioSyncPresetId"
    private static let kAutoRouteKey = "dashcast.audioSyncAutoRoute"

    @Published public var offsetMilliseconds: Double {
        didSet {
            let clamped = Self.clamp(offsetMilliseconds)
            if clamped != offsetMilliseconds {
                offsetMilliseconds = clamped
                return
            }
            savePreferences()
            updateActivePreset()
        }
    }

    @Published public private(set) var selectedPreset: AudioSyncPreset
    @Published public var autoRouteSyncEnabled: Bool {
        didSet {
            savePreferences()
            if autoRouteSyncEnabled {
                detectCurrentAudioRoute()
            }
        }
    }

    @Published public private(set) var detectedRouteName: String = "Built-in Speaker"
    @Published public private(set) var detectedHardwareLatencyMs: Double = 0.0
    @Published public private(set) var recommendedPreset: AudioSyncPreset = .wired

    private var routeObserver: NSObjectProtocol?
    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?

    public var offsetSeconds: Double {
        offsetMilliseconds / 1000.0
    }

    public var offsetMicroseconds: Int64 {
        Int64(offsetMilliseconds * 1000.0)
    }

    public var isOffsetActive: Bool {
        abs(offsetMilliseconds) > 0.001
    }

    public var formattedOffset: String {
        if abs(offsetMilliseconds) < 0.5 {
            return "0 ms"
        } else if offsetMilliseconds > 0 {
            return String(format: "+%.0f ms", offsetMilliseconds)
        } else {
            return String(format: "%.0f ms", offsetMilliseconds)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        let storedOffset = defaults.object(forKey: Self.kOffsetKey) as? Double ?? 0.0
        let storedPresetStr = defaults.string(forKey: Self.kPresetKey) ?? AudioSyncPreset.wired.rawValue
        let storedAutoRoute = defaults.object(forKey: Self.kAutoRouteKey) as? Bool ?? true

        self.offsetMilliseconds = Self.clamp(storedOffset)
        self.selectedPreset = AudioSyncPreset(rawValue: storedPresetStr) ?? .wired
        self.autoRouteSyncEnabled = storedAutoRoute

        detectCurrentAudioRoute()
        setupRouteObserver()
    }

    deinit {
        if let observer = routeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public static func clamp(_ val: Double) -> Double {
        min(max(val, minOffsetMs), maxOffsetMs)
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(offsetMilliseconds, forKey: Self.kOffsetKey)
        defaults.set(selectedPreset.rawValue, forKey: Self.kPresetKey)
        defaults.set(autoRouteSyncEnabled, forKey: Self.kAutoRouteKey)
    }

    private func updateActivePreset() {
        for preset in [AudioSyncPreset.wired, .carplayWireless, .bluetoothInDash] {
            if abs(offsetMilliseconds - preset.defaultOffsetMs) < 1.0 {
                if selectedPreset != preset {
                    selectedPreset = preset
                }
                return
            }
        }
        if selectedPreset != .custom {
            selectedPreset = .custom
        }
    }

    // MARK: - Public API

    public func applyPreset(_ preset: AudioSyncPreset) {
        selectedPreset = preset
        if preset != .custom {
            offsetMilliseconds = preset.defaultOffsetMs
        }
    }

    public func adjustOffset(by deltaMs: Double) {
        offsetMilliseconds = Self.clamp(offsetMilliseconds + deltaMs)
    }

    public func setOffset(_ ms: Double) {
        offsetMilliseconds = Self.clamp(ms)
    }

    public func reset() {
        applyPreset(.wired)
    }

    /// Inspects the active AVAudioSession output route to determine likely connection type
    public func detectCurrentAudioRoute() {
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute

        var routeName = "Built-in Speaker"
        var bestPreset: AudioSyncPreset = .wired
        let hardwareLatency = session.outputLatency * 1000.0
        detectedHardwareLatencyMs = hardwareLatency

        if let output = currentRoute.outputs.first {
            routeName = output.portName
            switch output.portType {
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                bestPreset = .bluetoothInDash
            case .carAudio, .airPlay:
                bestPreset = .carplayWireless
            case .headphones, .lineOut, .usbAudio:
                bestPreset = .wired
            default:
                bestPreset = .wired
            }
        }

        detectedRouteName = routeName
        recommendedPreset = bestPreset

        if autoRouteSyncEnabled && selectedPreset != .custom {
            applyPreset(bestPreset)
        }
    }

    private func setupRouteObserver() {
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeConfigurationChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.detectCurrentAudioRoute()
            }
        }
    }

    /// Applies audio sync configuration and time pitch algorithms to the target player item.
    public func apply(to playerItem: AVPlayerItem?) {
        guard let item = playerItem else { return }
        item.audioTimePitchAlgorithm = .timeDomain
    }

    /// Plays a short test pulse (beep + visual cue) allowing drivers to calibrate lip-sync accuracy by ear and eye.
    public func playSyncPulse() {
        stopTone()

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        engine.attach(player)

        let sampleRate = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        engine.connect(player, to: engine.mainMixerNode, format: format)

        let durationSeconds = 0.08
        let sampleCount = AVAudioFrameCount(sampleRate * durationSeconds)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: sampleCount) else { return }
        buffer.frameLength = sampleCount

        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frequency = 1200.0

        for i in 0..<Int(sampleCount) {
            let t = Double(i) / sampleRate
            let envelope = sin(Double.pi * t / durationSeconds)
            let sample = Float(sin(2.0 * Double.pi * frequency * t) * envelope * 0.7)
            channelData[i] = sample
        }

        do {
            try engine.start()
            player.play()
            player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.stopTone()
                }
            }
            self.audioEngine = engine
            self.tonePlayer = player
        } catch {
            print("Failed to play sync pulse: \(error)")
        }
    }

    private func stopTone() {
        tonePlayer?.stop()
        audioEngine?.stop()
        audioEngine = nil
        tonePlayer = nil
    }
}
