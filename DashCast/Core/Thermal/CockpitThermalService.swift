import Foundation
import SwiftUI
import Combine

/// Cockpit Thermal Protection Service that observes device thermal states, automatically
/// throttles rendering frame rates, dims local phone displays to low-power OLED black canvas,
/// and safeguards hardware against extreme windshield solar heat in automotive environments.
@MainActor
public final class CockpitThermalService: ObservableObject {
    public static let shared = CockpitThermalService()

    // MARK: - Published Properties

    /// Current physical hardware thermal state reported by iOS.
    @Published public private(set) var systemThermalState: ProcessInfo.ThermalState

    /// Optional debug/simulation thermal state override.
    @Published public var simulatedThermalState: ProcessInfo.ThermalState? = nil {
        didSet {
            evaluateThermalPolicy()
        }
    }

    /// User preference: Cap frame rates to 30 FPS even in nominal conditions to reduce heat generation.
    @Published public var isEcoModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEcoModeEnabled, forKey: Keys.ecoMode)
            evaluateThermalPolicy()
        }
    }

    /// User preference: Automatically engage OLED pure black canvas when thermal state reaches .serious or .critical.
    @Published public var autoDimOnSerious: Bool {
        didSet {
            UserDefaults.standard.set(autoDimOnSerious, forKey: Keys.autoDim)
        }
    }

    /// User preference: Sound an acoustic chime alert when device reaches .critical.
    @Published public var audioAlertOnCritical: Bool {
        didSet {
            UserDefaults.standard.set(audioAlertOnCritical, forKey: Keys.audioAlert)
        }
    }

    /// Whether the low-power OLED black canvas screen saver is currently active on the handset.
    @Published public var isScreenDimmed: Bool = false

    /// Indicates if video playback was paused automatically to avert thermal device shutdown.
    @Published public private(set) var isPlaybackPausedByThermal: Bool = false

    /// Timestamp of the last serious or critical thermal warning event.
    @Published public private(set) var lastThermalAlertTimestamp: Date? = nil

    // MARK: - Constants & Keys

    public enum Keys {
        public static let ecoMode = "dashcast_thermal_eco_mode_v1"
        public static let autoDim = "dashcast_thermal_auto_dim_v1"
        public static let audioAlert = "dashcast_thermal_audio_alert_v1"
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(defaults: UserDefaults = .standard) {
        self.systemThermalState = ProcessInfo.processInfo.thermalState

        defaults.register(defaults: [
            Keys.ecoMode: false,
            Keys.autoDim: true,
            Keys.audioAlert: true
        ])

        self.isEcoModeEnabled = defaults.bool(forKey: Keys.ecoMode)
        self.autoDimOnSerious = defaults.bool(forKey: Keys.autoDim)
        self.audioAlertOnCritical = defaults.bool(forKey: Keys.audioAlert)

        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.systemThermalState = ProcessInfo.processInfo.thermalState
                self.evaluateThermalPolicy()
            }
            .store(in: &cancellables)

        evaluateThermalPolicy()
    }

    // MARK: - Computed Properties

    public var effectiveThermalState: ProcessInfo.ThermalState {
        simulatedThermalState ?? systemThermalState
    }

    public var targetFrameRate: Int {
        switch effectiveThermalState {
        case .critical:
            return 15
        case .serious:
            return 30
        case .fair, .nominal:
            return isEcoModeEnabled ? 30 : 60
        @unknown default:
            return 60
        }
    }

    public var isThrottlingActive: Bool {
        effectiveThermalState == .serious || effectiveThermalState == .critical || isEcoModeEnabled
    }

    public var localizedStateTitle: LocalizedStringKey {
        switch effectiveThermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    public var localizedStatusSummary: LocalizedStringKey {
        switch effectiveThermalState {
        case .nominal:
            return isEcoModeEnabled ? "Eco Mode Active • 30 FPS Cap" : "Optimal Temperature • 60 FPS"
        case .fair:
            return isEcoModeEnabled ? "Eco Mode Active • 30 FPS Cap" : "Elevated Cockpit Heat • 60 FPS"
        case .serious:
            return "Thermal Protection Active • 30 FPS Cap • OLED Dimmer"
        case .critical:
            return "Critical Limit • Video Paused • Emergency Cooling"
        @unknown default:
            return "Optimal Temperature"
        }
    }

    public var statusColor: Color {
        switch effectiveThermalState {
        case .nominal: return .dcSuccess
        case .fair: return .dcInfo
        case .serious: return .dcWarning
        case .critical: return .dcDanger
        @unknown default: return .dcSuccess
        }
    }

    public var statusIconName: String {
        switch effectiveThermalState {
        case .nominal: return "thermometer.sun.fill"
        case .fair: return "thermometer.high"
        case .serious: return "flame.fill"
        case .critical: return "exclamationmark.triangle.fill"
        @unknown default: return "thermometer.sun.fill"
        }
    }

    // MARK: - Policy Evaluation

    public func evaluateThermalPolicy() {
        let state = effectiveThermalState

        switch state {
        case .nominal, .fair:
            isPlaybackPausedByThermal = false

        case .serious:
            lastThermalAlertTimestamp = Date()
            if autoDimOnSerious && !isScreenDimmed {
                isScreenDimmed = true
            }

        case .critical:
            lastThermalAlertTimestamp = Date()
            if autoDimOnSerious && !isScreenDimmed {
                isScreenDimmed = true
            }

            if VideoPlayerService.shared.isPlaying {
                VideoPlayerService.shared.pause()
                isPlaybackPausedByThermal = true
            }

            if audioAlertOnCritical {
                playThermalWarningChime()
            }

        @unknown default:
            break
        }
    }

    // MARK: - Actions & Toggles

    public func toggleEcoMode() {
        isEcoModeEnabled.toggle()
    }

    public func toggleScreenDimming() {
        isScreenDimmed.toggle()
    }

    public func wakeScreen() {
        isScreenDimmed = false
    }

    public func simulateThermalState(_ state: ProcessInfo.ThermalState?) {
        simulatedThermalState = state
    }

    public func resetDefaults() {
        simulatedThermalState = nil
        isEcoModeEnabled = false
        autoDimOnSerious = true
        audioAlertOnCritical = true
        isScreenDimmed = false
        isPlaybackPausedByThermal = false
        evaluateThermalPolicy()
    }

    private func playThermalWarningChime() {
        let chime = SoundEffectItem(
            id: "cockpit_thermal_alert",
            title: "Thermal Warning",
            category: .chimes,
            durationString: "0:02",
            frequencyHz: 880,
            color: .dashRed
        )
        SoundPlayerEngine.shared.play(sound: chime)
    }
}
