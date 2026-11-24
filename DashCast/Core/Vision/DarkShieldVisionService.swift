import Foundation
import SwiftUI
import Combine
import CoreLocation

/// Preset photopic night vision color filters engineered to preserve dark adaptation,
/// minimize dashboard windshield glare, and prevent rhodopsin bleaching during nighttime driving.
public enum DarkShieldFilterPreset: String, CaseIterable, Codable {
    case off = "off"
    case photopicAmber = "photopic_amber"
    case aviationRed = "aviation_red"
    case oledDeepBlack = "oled_deep_black"

    public var title: String {
        switch self {
        case .off: return "Off"
        case .photopicAmber: return "Photopic Amber"
        case .aviationRed: return "Aviation Red"
        case .oledDeepBlack: return "OLED Deep Black"
        }
    }

    public var localizedTitle: LocalizedStringKey {
        switch self {
        case .off: return "Off"
        case .photopicAmber: return "Photopic Amber"
        case .aviationRed: return "Aviation Red"
        case .oledDeepBlack: return "OLED Deep Black"
        }
    }

    public var wavelengthDescription: String {
        switch self {
        case .off: return "Standard passthrough"
        case .photopicAmber: return "589nm Contrast Booster"
        case .aviationRed: return "650nm Rhodopsin Saver"
        case .oledDeepBlack: return "0-Nit Glare Killer"
        }
    }

    public var systemIconName: String {
        switch self {
        case .off: return "sun.max"
        case .photopicAmber: return "eyeglasses"
        case .aviationRed: return "moon.stars.fill"
        case .oledDeepBlack: return "shield.lefthalf.filled"
        }
    }

    public var accentColor: Color {
        switch self {
        case .off: return Color.gray
        case .photopicAmber: return Color(red: 1.0, green: 0.75, blue: 0.1)
        case .aviationRed: return Color(red: 1.0, green: 0.2, blue: 0.2)
        case .oledDeepBlack: return Color(red: 0.4, green: 0.6, blue: 1.0)
        }
    }
}

/// DarkShield Vision Service: Manages real-time photopic color filtering, ambient glare reduction,
/// and automated highway tunnel night-vision triggers.
@MainActor
public final class DarkShieldVisionService: ObservableObject {
    public static let shared = DarkShieldVisionService()

    // MARK: - Keys for Persistence
    public struct Keys {
        public static let selectedPreset = "dashcast_darkshield_preset"
        public static let autoTunnel = "dashcast_darkshield_auto_tunnel"
        public static let glareLevel = "dashcast_darkshield_glare_level"
        public static let windshieldSuppression = "dashcast_darkshield_windshield_suppress"
        public static let invertWeb = "dashcast_darkshield_invert_web"
        public static let defaultTunnelPreset = "dashcast_darkshield_tunnel_preset"
    }

    // MARK: - Published Properties

    /// Currently selected base filter preset.
    @Published public var selectedPreset: DarkShieldFilterPreset {
        didSet {
            UserDefaults.standard.set(selectedPreset.rawValue, forKey: Keys.selectedPreset)
        }
    }

    /// Default filter applied automatically when a tunnel or sudden dark zone is detected.
    @Published public var tunnelDefaultPreset: DarkShieldFilterPreset {
        didSet {
            UserDefaults.standard.set(tunnelDefaultPreset.rawValue, forKey: Keys.defaultTunnelPreset)
        }
    }

    /// User preference: Automatically engage DarkShield when entering road tunnels or underground passages.
    @Published public var isAutoTunnelEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoTunnelEnabled, forKey: Keys.autoTunnel)
            evaluateTunnelState()
        }
    }

    /// Glare reduction strength (0.1 to 1.0).
    @Published public var glareReductionLevel: Double {
        didSet {
            let clamped = max(0.1, min(1.0, glareReductionLevel))
            if clamped != glareReductionLevel {
                glareReductionLevel = clamped
            } else {
                UserDefaults.standard.set(glareReductionLevel, forKey: Keys.glareLevel)
            }
        }
    }

    /// User preference: Dims the top portion of the display where windshield glass reflections occur.
    @Published public var isWindshieldReflectionSuppressed: Bool {
        didSet {
            UserDefaults.standard.set(isWindshieldReflectionSuppressed, forKey: Keys.windshieldSuppression)
        }
    }

    /// User preference: Inverts harsh white web browser wrappers into pure dark mode.
    @Published public var isInvertWhiteBackgroundsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isInvertWhiteBackgroundsEnabled, forKey: Keys.invertWeb)
        }
    }

    /// Real-time status indicating if a tunnel transition is currently active.
    @Published public private(set) var isTunnelActive: Bool = false

    /// Simulated tunnel override for testing and demonstration.
    @Published public var simulatedTunnelActive: Bool? = nil {
        didSet {
            evaluateTunnelState()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        let storedPreset = UserDefaults.standard.string(forKey: Keys.selectedPreset)
            .flatMap { DarkShieldFilterPreset(rawValue: $0) } ?? .off
        self.selectedPreset = storedPreset

        let storedTunnelPreset = UserDefaults.standard.string(forKey: Keys.defaultTunnelPreset)
            .flatMap { DarkShieldFilterPreset(rawValue: $0) } ?? .photopicAmber
        self.tunnelDefaultPreset = storedTunnelPreset

        if UserDefaults.standard.object(forKey: Keys.autoTunnel) != nil {
            self.isAutoTunnelEnabled = UserDefaults.standard.bool(forKey: Keys.autoTunnel)
        } else {
            self.isAutoTunnelEnabled = true
        }

        if UserDefaults.standard.object(forKey: Keys.glareLevel) != nil {
            self.glareReductionLevel = UserDefaults.standard.double(forKey: Keys.glareLevel)
        } else {
            self.glareReductionLevel = 0.75
        }

        if UserDefaults.standard.object(forKey: Keys.windshieldSuppression) != nil {
            self.isWindshieldReflectionSuppressed = UserDefaults.standard.bool(forKey: Keys.windshieldSuppression)
        } else {
            self.isWindshieldReflectionSuppressed = true
        }

        if UserDefaults.standard.object(forKey: Keys.invertWeb) != nil {
            self.isInvertWhiteBackgroundsEnabled = UserDefaults.standard.bool(forKey: Keys.invertWeb)
        } else {
            self.isInvertWhiteBackgroundsEnabled = true
        }

        setupLocationObservers()
    }

    // MARK: - Effective Filter Evaluation

    /// The filter currently being rendered on screen (considers manual preset and automated tunnel trigger).
    public var effectivePreset: DarkShieldFilterPreset {
        if isTunnelActive && isAutoTunnelEnabled {
            return selectedPreset == .off ? tunnelDefaultPreset : selectedPreset
        }
        return selectedPreset
    }

    /// Whether any photopic filtering or glare suppression is actively running.
    public var isActive: Bool {
        effectivePreset != .off || isTunnelActive
    }

    // MARK: - Status Indicators

    public var statusTitle: String {
        if isTunnelActive {
            return "Tunnel Guard"
        }
        return effectivePreset.title
    }

    public var statusSubtitle: String {
        if isTunnelActive {
            return "Auto Photopic Active"
        }
        return effectivePreset.wavelengthDescription
    }

    public var statusColor: Color {
        if !isActive {
            return Color.gray
        }
        return effectivePreset.accentColor
    }

    public var statusIconName: String {
        if isTunnelActive {
            return "tunnel"
        }
        return effectivePreset.systemIconName
    }

    // MARK: - Mathematical Color Matrix Transformation

    /// Computes photopic color matrix transformation for RGB components in [0.0, 1.0].
    /// - Parameters:
    ///   - r: Normalized red channel (0.0 ... 1.0)
    ///   - g: Normalized green channel (0.0 ... 1.0)
    ///   - b: Normalized blue channel (0.0 ... 1.0)
    /// - Returns: Transformed (r, g, b) tuple clamped to [0.0, 1.0].
    public func colorTransform(r: Double, g: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let cr = max(0.0, min(1.0, r))
        let cg = max(0.0, min(1.0, g))
        let cb = max(0.0, min(1.0, b))

        // Rec. 709 / CIE 1931 Photopic Luminance
        let y = 0.2126 * cr + 0.7152 * cg + 0.0722 * cb

        switch effectivePreset {
        case .off:
            return (cr, cg, cb)

        case .photopicAmber:
            // 589nm Sodium-D boost: Enhances edge contrast and eliminates scatter blue
            let strength = glareReductionLevel
            let targetR = min(1.0, y * 1.08 + 0.04)
            let targetG = min(1.0, y * 0.78 + 0.02)
            let targetB = min(1.0, y * 0.08)
            let outR = cr * (1.0 - strength) + targetR * strength
            let outG = cg * (1.0 - strength) + targetG * strength
            let outB = cb * (1.0 - strength) + targetB * strength
            return (min(1.0, outR), min(1.0, outG), min(1.0, outB))

        case .aviationRed:
            // 650nm Aviation Red: Rod rhodopsin preservation (100% dark adaptation retained)
            let strength = glareReductionLevel
            let targetR = min(1.0, y * 1.25)
            let targetG = min(1.0, y * 0.05)
            let targetB = min(1.0, y * 0.04)
            let outR = cr * (1.0 - strength) + targetR * strength
            let outG = cg * (1.0 - strength) + targetG * strength
            let outB = cb * (1.0 - strength) + targetB * strength
            return (min(1.0, outR), min(1.0, outG), min(1.0, outB))

        case .oledDeepBlack:
            // High-contrast gamma compression: Crushes dark grays to true 0-nit black and tames highlights
            let strength = glareReductionLevel
            let gamma = 1.0 + (0.6 * strength)
            let targetR = pow(cr, gamma) * (1.0 - 0.35 * strength)
            let targetG = pow(cg, gamma) * (1.0 - 0.35 * strength)
            let targetB = pow(cb, gamma) * (1.0 - 0.35 * strength)
            return (min(1.0, targetR), min(1.0, targetG), min(1.0, targetB))
        }
    }

    // MARK: - SwiftUI Overlay Helpers

    public var overlayTintColor: Color {
        switch effectivePreset {
        case .off:
            return Color.clear
        case .photopicAmber:
            return Color(red: 1.0, green: 0.78, blue: 0.1).opacity(0.42 * glareReductionLevel)
        case .aviationRed:
            return Color(red: 1.0, green: 0.1, blue: 0.1).opacity(0.55 * glareReductionLevel)
        case .oledDeepBlack:
            return Color.black.opacity(0.50 * glareReductionLevel)
        }
    }

    public var overlayBlendMode: BlendMode {
        switch effectivePreset {
        case .off:
            return .normal
        case .photopicAmber:
            return .color
        case .aviationRed:
            return .multiply
        case .oledDeepBlack:
            return .multiply
        }
    }

    // MARK: - Actions

    /// Cycles through all available photopic presets.
    public func cycleNextPreset() {
        let all = DarkShieldFilterPreset.allCases
        if let idx = all.firstIndex(of: selectedPreset) {
            let nextIdx = (idx + 1) % all.count
            selectedPreset = all[nextIdx]
        } else {
            selectedPreset = .photopicAmber
        }
    }

    /// Sets a specific preset directly.
    public func setPreset(_ preset: DarkShieldFilterPreset) {
        self.selectedPreset = preset
    }

    /// Toggles active state between .off and .photopicAmber.
    public func toggleActive() {
        if selectedPreset == .off {
            selectedPreset = .photopicAmber
        } else {
            selectedPreset = .off
        }
    }

    /// Sets or clears simulated tunnel transition for testing.
    public func simulateTunnel(_ active: Bool?) {
        self.simulatedTunnelActive = active
    }

    /// Resets all settings to factory automotive defaults.
    public func resetDefaults() {
        selectedPreset = .off
        tunnelDefaultPreset = .photopicAmber
        isAutoTunnelEnabled = true
        glareReductionLevel = 0.75
        isWindshieldReflectionSuppressed = true
        isInvertWhiteBackgroundsEnabled = true
        simulatedTunnelActive = nil
        isTunnelActive = false

        UserDefaults.standard.removeObject(forKey: Keys.selectedPreset)
        UserDefaults.standard.removeObject(forKey: Keys.defaultTunnelPreset)
        UserDefaults.standard.removeObject(forKey: Keys.autoTunnel)
        UserDefaults.standard.removeObject(forKey: Keys.glareLevel)
        UserDefaults.standard.removeObject(forKey: Keys.windshieldSuppression)
        UserDefaults.standard.removeObject(forKey: Keys.invertWeb)
    }

    // MARK: - Tunnel Detection Logic

    private func setupLocationObservers() {
        DriveLocationService.shared.$currentLocation
            .combineLatest(DriveLocationService.shared.$currentSpeedKmh, DriveLocationService.shared.$isTracking)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location, speed, isTracking in
                self?.evaluateLocationForTunnel(location: location, speedKmh: speed, isTracking: isTracking)
            }
            .store(in: &cancellables)
    }

    private func evaluateTunnelState() {
        if let sim = simulatedTunnelActive {
            if isTunnelActive != sim {
                isTunnelActive = sim
            }
            return
        }

        let loc = DriveLocationService.shared.currentLocation
        let speed = DriveLocationService.shared.currentSpeedKmh
        let tracking = DriveLocationService.shared.isTracking
        evaluateLocationForTunnel(location: loc, speedKmh: speed, isTracking: tracking)
    }

    private func evaluateLocationForTunnel(location: CLLocation?, speedKmh: Double, isTracking: Bool) {
        if let sim = simulatedTunnelActive {
            isTunnelActive = sim
            return
        }

        guard isAutoTunnelEnabled else {
            if isTunnelActive { isTunnelActive = false }
            return
        }

        // Tunnel detection heuristic:
        // Moving at vehicular speed (> 15 km/h) while GPS horizontal accuracy degrades beyond 35 meters
        // (indicative of entering concrete tunnel or underground passage)
        if isTracking && speedKmh > 15.0 {
            let accuracy = location?.horizontalAccuracy ?? -1
            if accuracy > 35.0 || accuracy < 0 {
                if !isTunnelActive {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isTunnelActive = true
                    }
                }
                return
            }
        }

        if isTunnelActive {
            withAnimation(.easeInOut(duration: 0.5)) {
                isTunnelActive = false
            }
        }
    }
}
