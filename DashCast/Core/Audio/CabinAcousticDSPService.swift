import Foundation
import SwiftUI
import Combine

/// Automotive Cabin Acoustic DSP Service that dynamically compensates for highway road noise,
/// tire roar, and wind shear by modulating multi-band equalization in proportion to vehicle speed.
@MainActor
public final class CabinAcousticDSPService: ObservableObject {
    public static let shared = CabinAcousticDSPService()

    // MARK: - Cabin Profile Definitions

    public enum CabinProfile: String, CaseIterable, Identifiable, Codable {
        case sedan = "Sedan"
        case suv = "SUV / Crossover"
        case sports = "Convertible / Sports"
        case custom = "Custom EQ"

        public var id: String { rawValue }

        public var localizedTitle: LocalizedStringKey {
            switch self {
            case .sedan: return "Sedan (Quiet)"
            case .suv: return "SUV / Crossover (Mid-Cabin)"
            case .sports: return "Convertible / Sports (High Noise)"
            case .custom: return "Custom 5-Band EQ"
            }
        }

        public var baseNoiseDBA: Double {
            switch self {
            case .sedan: return 48.0
            case .suv: return 54.0
            case .sports: return 62.0
            case .custom: return 52.0
            }
        }

        public var iconName: String {
            switch self {
            case .sedan: return "car.fill"
            case .suv: return "car.side.fill"
            case .sports: return "car.side.rear.open.fill"
            case .custom: return "slider.vertical.3"
            }
        }

        /// Base gain profile (in dB) for each of the 5 frequency bands: [60Hz, 250Hz, 1kHz, 2.5kHz, 6kHz]
        public var defaultBandGains: [Double] {
            switch self {
            case .sedan: return [0.0, 0.5, 1.0, 1.5, 0.5]
            case .suv: return [-0.5, 0.0, 1.5, 2.5, 1.0]
            case .sports: return [-1.5, -0.5, 2.0, 4.0, 2.0]
            case .custom: return [0.0, 0.0, 0.0, 0.0, 0.0]
            }
        }
    }

    // MARK: - Frequency Bands

    public enum EQBand: Int, CaseIterable, Identifiable, Codable {
        case subBass = 0       // 60 Hz: High-pass / road rumble damping
        case lowMid = 1        // 250 Hz: Engine hum and tire cavity resonance
        case mid = 2           // 1000 Hz: Vocal fundamental body
        case vocalClarity = 3  // 2500 Hz: Primary speech intelligibility formants
        case presence = 4      // 6000 Hz: Consonants, sibilance, and high-frequency air

        public var id: Int { rawValue }

        public var label: String {
            switch self {
            case .subBass: return "60 Hz"
            case .lowMid: return "250 Hz"
            case .mid: return "1.0 kHz"
            case .vocalClarity: return "2.5 kHz"
            case .presence: return "6.0 kHz"
            }
        }

        public var roleDescription: String {
            switch self {
            case .subBass: return "Rumble Cut"
            case .lowMid: return "Cabin Resonance"
            case .mid: return "Vocal Core"
            case .vocalClarity: return "Speech Clarity"
            case .presence: return "Air / Consonants"
            }
        }
    }

    // MARK: - Published Properties

    @Published public var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published public var speedCompensationEnabled: Bool {
        didSet { UserDefaults.standard.set(speedCompensationEnabled, forKey: Keys.speedCompensationEnabled) }
    }

    @Published public var selectedProfile: CabinProfile {
        didSet { UserDefaults.standard.set(selectedProfile.rawValue, forKey: Keys.selectedProfile) }
    }

    @Published public var speechEnhancerIntensity: Double {
        didSet { UserDefaults.standard.set(speechEnhancerIntensity, forKey: Keys.speechEnhancerIntensity) }
    }

    @Published public var customBandGains: [Double] {
        didSet { UserDefaults.standard.set(customBandGains, forKey: Keys.customBandGains) }
    }

    /// Simulated speed override for testing or manual preview (nil = live vehicle telemetry)
    @Published public var simulatedSpeedMph: Double? = nil

    // MARK: - Storage Keys

    private enum Keys {
        static let isEnabled = "dashcast_dsp_enabled"
        static let speedCompensationEnabled = "dashcast_dsp_speed_comp_enabled"
        static let selectedProfile = "dashcast_dsp_selected_profile"
        static let speechEnhancerIntensity = "dashcast_dsp_intensity"
        static let customBandGains = "dashcast_dsp_custom_gains"
    }

    // MARK: - Initialization

    public init() {
        let defaults = UserDefaults.standard
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        self.speedCompensationEnabled = defaults.object(forKey: Keys.speedCompensationEnabled) as? Bool ?? true
        
        if let rawProfile = defaults.string(forKey: Keys.selectedProfile),
           let profile = CabinProfile(rawValue: rawProfile) {
            self.selectedProfile = profile
        } else {
            self.selectedProfile = .suv
        }

        self.speechEnhancerIntensity = defaults.object(forKey: Keys.speechEnhancerIntensity) as? Double ?? 0.85

        if let gains = defaults.array(forKey: Keys.customBandGains) as? [Double], gains.count == 5 {
            self.customBandGains = gains
        } else {
            self.customBandGains = [0.0, 0.0, 0.0, 0.0, 0.0]
        }
    }

    // MARK: - Velocity Calculations

    /// Current effective vehicle speed in mph (simulated or live telemetry)
    public var effectiveSpeedMph: Double {
        if let sim = simulatedSpeedMph {
            return max(0, sim)
        }
        let kmh = DriveLocationService.shared.currentSpeedKmh
        return max(0, kmh * 0.621371)
    }

    /// Estimates current cabin ambient noise level in dBA using standard automotive acoustic power curve:
    /// `L_cabin = L_base + (v / 70)^1.75 * 20.0`
    public func estimatedAmbientNoiseDBA(atSpeedMph speed: Double? = nil) -> Double {
        let v = speed ?? effectiveSpeedMph
        let base = selectedProfile.baseNoiseDBA
        guard v > 2.0 else { return base }
        let factor = pow(min(v, 110.0) / 70.0, 1.75)
        return min(86.0, base + factor * 21.0)
    }

    /// Calculates speed-induced dynamic boost or attenuation for a specific band (in dB).
    ///
    /// - Vocal Clarity (2.5 kHz) scales up to +5.5 dB at 75 mph.
    /// - Presence (6.0 kHz) scales up to +2.5 dB.
    /// - Sub-bass (60 Hz) rolls off up to -3.5 dB to prevent door panel rattling from road vibrations.
    public func speedOffset(for band: EQBand, atSpeedMph speed: Double) -> Double {
        guard speedCompensationEnabled else { return 0.0 }
        let v = max(0, min(speed, 90.0))
        guard v > 5.0 else { return 0.0 }

        let normalizedSpeed = (v - 5.0) / 80.0 // 0.0 at 5 mph to 1.0 at 85 mph
        let intensity = max(0.1, min(speechEnhancerIntensity, 1.0))

        switch band {
        case .subBass:
            // High-pass dynamic roll-off: reduce muddy rumble as road noise rises
            return -3.5 * normalizedSpeed * intensity
        case .lowMid:
            // Slight attenuation to clear mid-bass clutter
            return -1.0 * normalizedSpeed * intensity
        case .mid:
            // Modest vocal body lift
            return 1.8 * normalizedSpeed * intensity
        case .vocalClarity:
            // Aggressive speech intelligibility lift directly counteracting road noise mask
            return 5.5 * normalizedSpeed * intensity
        case .presence:
            // High-frequency air for crisp speech consonants
            return 2.5 * normalizedSpeed * intensity
        }
    }

    /// Total active gain (base profile gain + dynamic speed offset) in decibels.
    public func computedGain(for band: EQBand, atSpeedMph speed: Double? = nil) -> Double {
        guard isEnabled else { return 0.0 }
        let v = speed ?? effectiveSpeedMph
        let baseGains = selectedProfile == .custom ? customBandGains : selectedProfile.defaultBandGains
        let base = baseGains.indices.contains(band.rawValue) ? baseGains[band.rawValue] : 0.0
        let offset = speedOffset(for: band, atSpeedMph: v)
        let total = base + offset
        // Clamp to safe digital audio limits (-12 dB to +12 dB)
        return max(-12.0, min(total, 12.0))
    }

    /// Returns all 5 computed gains formatted as an array
    public func allComputedGains(atSpeedMph speed: Double? = nil) -> [Double] {
        EQBand.allCases.map { computedGain(for: $0, atSpeedMph: speed) }
    }

    // MARK: - Actions

    public func setCustomGain(band: EQBand, gain: Double) {
        guard band.rawValue < customBandGains.count else { return }
        customBandGains[band.rawValue] = max(-12.0, min(gain, 12.0))
        if selectedProfile != .custom {
            selectedProfile = .custom
        }
    }

    public func resetToProfileDefaults() {
        if selectedProfile == .custom {
            customBandGains = [0.0, 0.0, 0.0, 0.0, 0.0]
        }
    }
}
