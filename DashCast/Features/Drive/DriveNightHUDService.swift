import Foundation
import SwiftUI
import CoreLocation
import Combine

// MARK: - Night HUD Themes

public enum NightHUDTheme: String, CaseIterable, Identifiable, Codable {
    case pureOLED = "pureOLED"
    case tacticalCrimson = "tacticalCrimson"
    case emeraldGlow = "emeraldGlow"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pureOLED:
            return "OLED Amber"
        case .tacticalCrimson:
            return "Tactical Crimson"
        case .emeraldGlow:
            return "Emerald Phosphor"
        }
    }

    public var accentColor: Color {
        switch self {
        case .pureOLED:
            return Color(hex: "#FFE600") // Electric Racing Yellow / Amber
        case .tacticalCrimson:
            return Color(hex: "#FF3B30") // Aviation Crimson Red (scotopic preservation)
        case .emeraldGlow:
            return Color(hex: "#2BE47F") // High-contrast Emerald Phosphor
        }
    }

    public var secondaryColor: Color {
        switch self {
        case .pureOLED:
            return Color(hex: "#FFA000")
        case .tacticalCrimson:
            return Color(hex: "#D32F2F")
        case .emeraldGlow:
            return Color(hex: "#0E9F4E")
        }
    }

    public var auraCautionColor: Color {
        switch self {
        case .pureOLED:
            return Color(hex: "#FFB020")
        case .tacticalCrimson:
            return Color(hex: "#FF5252")
        case .emeraldGlow:
            return Color(hex: "#FFD600")
        }
    }

    public var auraCriticalColor: Color {
        return Color(hex: "#FF1744") // Universal Warning Crimson
    }
}

// MARK: - Speed Warning Status

public enum SpeedWarningStatus: String, Equatable {
    case normal
    case caution
    case critical

    public var auraIntensity: Double {
        switch self {
        case .normal: return 0.0
        case .caution: return 0.55
        case .critical: return 0.95
        }
    }
}

// MARK: - DriveNightHUDService

@MainActor
public final class DriveNightHUDService: ObservableObject {
    public static let shared = DriveNightHUDService()

    @Published public var isHUDActive: Bool = false
    @Published public var isWindshieldMirrored: Bool = false
    @Published public var isAmbientWarningAuraEnabled: Bool = true
    @Published public var speedLimitKmh: Double = 100.0
    @Published public var speedLimitWarningOffsetKmh: Double = 8.0 // ~5 mph warning margin
    @Published public var selectedTheme: NightHUDTheme = .pureOLED
    @Published public var autoLaunchAtNight: Bool = false

    private let userDefaults: UserDefaults
    private let preferencesKey = "dashcast_nighthud_preferences"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadPreferences()
    }

    // MARK: - Warning Status Computation

    public func warningStatus(currentSpeedKmh: Double) -> SpeedWarningStatus {
        guard isAmbientWarningAuraEnabled else { return .normal }

        if currentSpeedKmh <= speedLimitKmh {
            return .normal
        } else if currentSpeedKmh <= (speedLimitKmh + speedLimitWarningOffsetKmh) {
            return .caution
        } else {
            return .critical
        }
    }

    // MARK: - Cardinal Direction

    public static func cardinalHeading(from courseDegrees: Double) -> String {
        guard courseDegrees >= 0.0 && courseDegrees <= 360.0 else {
            return "--"
        }

        let normalized = courseDegrees.truncatingRemainder(dividingBy: 360.0)
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int(round(normalized / 45.0)) % 8
        return directions[index]
    }

    // MARK: - Speed Limit Controls

    public var speedLimitMph: Double {
        speedLimitKmh * 0.621371
    }

    public func setSpeedLimitKmh(_ kmh: Double) {
        speedLimitKmh = min(max(kmh, 20.0), 250.0)
        savePreferences()
    }

    public func setSpeedLimitMph(_ mph: Double) {
        let kmh = mph / 0.621371
        setSpeedLimitKmh(kmh)
    }

    public func adjustSpeedLimit(deltaKmh: Double) {
        setSpeedLimitKmh(speedLimitKmh + deltaKmh)
    }

    public func toggleWindshieldMirror() {
        isWindshieldMirrored.toggle()
        savePreferences()
    }

    public func setTheme(_ theme: NightHUDTheme) {
        selectedTheme = theme
        savePreferences()
    }

    public func toggleAmbientAura() {
        isAmbientWarningAuraEnabled.toggle()
        savePreferences()
    }

    // MARK: - Persistence

    private struct StoredConfig: Codable {
        var isWindshieldMirrored: Bool
        var isAmbientWarningAuraEnabled: Bool
        var speedLimitKmh: Double
        var speedLimitWarningOffsetKmh: Double
        var selectedThemeRaw: String
        var autoLaunchAtNight: Bool
    }

    public func savePreferences() {
        let config = StoredConfig(
            isWindshieldMirrored: isWindshieldMirrored,
            isAmbientWarningAuraEnabled: isAmbientWarningAuraEnabled,
            speedLimitKmh: speedLimitKmh,
            speedLimitWarningOffsetKmh: speedLimitWarningOffsetKmh,
            selectedThemeRaw: selectedTheme.rawValue,
            autoLaunchAtNight: autoLaunchAtNight
        )
        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: preferencesKey)
        }
    }

    public func loadPreferences() {
        guard let data = userDefaults.data(forKey: preferencesKey),
              let config = try? JSONDecoder().decode(StoredConfig.self, from: data) else {
            return
        }
        self.isWindshieldMirrored = config.isWindshieldMirrored
        self.isAmbientWarningAuraEnabled = config.isAmbientWarningAuraEnabled
        self.speedLimitKmh = config.speedLimitKmh
        self.speedLimitWarningOffsetKmh = config.speedLimitWarningOffsetKmh
        self.selectedTheme = NightHUDTheme(rawValue: config.selectedThemeRaw) ?? .pureOLED
        self.autoLaunchAtNight = config.autoLaunchAtNight
    }

    public func resetToDefaults() {
        isWindshieldMirrored = false
        isAmbientWarningAuraEnabled = true
        speedLimitKmh = 100.0
        speedLimitWarningOffsetKmh = 8.0
        selectedTheme = .pureOLED
        autoLaunchAtNight = false
        savePreferences()
    }
}
