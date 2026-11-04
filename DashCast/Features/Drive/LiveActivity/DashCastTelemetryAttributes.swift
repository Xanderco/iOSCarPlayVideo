import Foundation
import ActivityKit
import SwiftUI

/// Static and dynamic attributes for the DashCast Live Activity and Dynamic Island.
public struct DashCastTelemetryAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentSpeed: Double
        public var currentSpeedKmh: Double
        public var topSpeed: Double
        public var distanceFormatted: String
        public var distanceMeters: Double
        public var elapsedTime: TimeInterval
        public var elapsedDurationFormatted: String
        public var currentGForce: Double
        public var peakGForce: Double
        public var smoothnessScore: Int
        public var isPaused: Bool
        public var isParked: Bool
        public var teaserMode: Bool
        public var lastUpdated: Date

        public init(
            currentSpeed: Double,
            currentSpeedKmh: Double,
            topSpeed: Double,
            distanceFormatted: String,
            distanceMeters: Double,
            elapsedTime: TimeInterval,
            elapsedDurationFormatted: String,
            currentGForce: Double,
            peakGForce: Double,
            smoothnessScore: Int,
            isPaused: Bool = false,
            isParked: Bool = false,
            teaserMode: Bool = false,
            lastUpdated: Date = Date()
        ) {
            self.currentSpeed = currentSpeed
            self.currentSpeedKmh = currentSpeedKmh
            self.topSpeed = topSpeed
            self.distanceFormatted = distanceFormatted
            self.distanceMeters = distanceMeters
            self.elapsedTime = elapsedTime
            self.elapsedDurationFormatted = elapsedDurationFormatted
            self.currentGForce = currentGForce
            self.peakGForce = peakGForce
            self.smoothnessScore = smoothnessScore
            self.isPaused = isPaused
            self.isParked = isParked
            self.teaserMode = teaserMode
            self.lastUpdated = lastUpdated
        }

        // MARK: - Formatting & Visual Helpers

        public var speedFormatted: String {
            String(format: "%.0f", max(0, currentSpeed))
        }

        public var topSpeedFormatted: String {
            String(format: "%.0f", max(0, topSpeed))
        }

        public var gForceFormatted: String {
            String(format: "%.2f G", max(0, currentGForce))
        }

        public var peakGForceFormatted: String {
            String(format: "%.2f G", max(0, peakGForce))
        }

        public var gForceIntensity: Double {
            // Clamped 0.0 to 1.0 (0 to 0.8g visual range)
            min(max(currentGForce / 0.8, 0.0), 1.0)
        }

        public var scoreRatingLabel: String {
            if smoothnessScore >= 90 {
                return "Smooth Driver"
            } else if smoothnessScore >= 75 {
                return "Good Pace"
            } else if smoothnessScore >= 60 {
                return "Spirited"
            } else {
                return "Aggressive"
            }
        }

        public var scoreColor: Color {
            if smoothnessScore >= 90 {
                return Color.dashGreen
            } else if smoothnessScore >= 75 {
                return Color.dashYellow
            } else if smoothnessScore >= 60 {
                return Color.dashOrange
            } else {
                return Color.dashRed
            }
        }
    }

    // Static attributes
    public var tripId: String
    public var vehicleName: String
    public var vehicleImageName: String
    public var speedUnit: String
    public var useMilesPerHour: Bool

    public init(
        tripId: String = UUID().uuidString,
        vehicleName: String = "Cyberpunk GT",
        vehicleImageName: String = "car_cyberpunk_supercar",
        speedUnit: String = "KM/H",
        useMilesPerHour: Bool = false
    ) {
        self.tripId = tripId
        self.vehicleName = vehicleName
        self.vehicleImageName = vehicleImageName
        self.speedUnit = speedUnit
        self.useMilesPerHour = useMilesPerHour
    }
}
