import Foundation
import ActivityKit

// Shared between the DashCast app and the DashCastCastWidget extension.

public struct EVChargingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Station name, e.g. "Tesla Supercharger", "Electrify America", "EVgo", "Rest Area"
        public var stationName: String
        /// Preset identifier string
        public var stationPresetRaw: String
        /// Current state percentage (0-100)
        public var currentBattery: Int
        /// Target percentage (e.g. 80)
        public var targetBattery: Int
        /// Charge power rating in kW (e.g. 250.0, 350.0)
        public var powerKw: Double
        /// Whether actively fast-charging or at rest area
        public var isCharging: Bool
        public var isRestArea: Bool
        /// Start of the session
        public var startTime: Date
        /// Projected time when target charge or rest countdown is reached
        public var estimatedCompletionTime: Date
        /// Human-readable status badge or note
        public var statusText: String

        public init(
            stationName: String,
            stationPresetRaw: String,
            currentBattery: Int,
            targetBattery: Int,
            powerKw: Double,
            isCharging: Bool,
            isRestArea: Bool,
            startTime: Date,
            estimatedCompletionTime: Date,
            statusText: String
        ) {
            self.stationName = stationName
            self.stationPresetRaw = stationPresetRaw
            self.currentBattery = currentBattery
            self.targetBattery = targetBattery
            self.powerKw = powerKw
            self.isCharging = isCharging
            self.isRestArea = isRestArea
            self.startTime = startTime
            self.estimatedCompletionTime = estimatedCompletionTime
            self.statusText = statusText
        }
    }

    public var sessionTitle: String

    public init(sessionTitle: String) {
        self.sessionTitle = sessionTitle
    }
}
