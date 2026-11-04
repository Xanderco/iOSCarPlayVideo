import Foundation
import CoreLocation
import SwiftUI

/// Transfer and state model for rendering high-resolution 1080x1920 Instagram Story & TikTok graphics.
public struct DriveSummaryCardData: Codable, Identifiable, Equatable {
    public var id: UUID
    public var tripId: UUID
    public var date: Date
    public var durationSeconds: TimeInterval
    public var distanceMeters: Double
    public var averageSpeedKmh: Double
    public var topSpeedKmh: Double
    public var drivingScore: Int
    public var badgeTier: SmoothnessBadgeTier
    public var peakLateralG: Double
    public var peakLongitudinalG: Double
    public var peakCombinedG: Double
    public var harshBrakingCount: Int
    public var harshAccelerationCount: Int
    public var harshCorneringCount: Int
    public var vehicleName: String
    public var vehicleBrand: String
    public var vehicleImageName: String
    public var vehicleAccentHex: String
    public var useMilesPerHour: Bool
    public var routeCoordinates: [RouteCoordinate]
    public var targetWidth: CGFloat
    public var targetHeight: CGFloat

    public struct RouteCoordinate: Codable, Identifiable, Equatable {
        public var id: UUID
        public var latitude: Double
        public var longitude: Double
        public var speedKmh: Double

        public init(id: UUID = UUID(), latitude: Double, longitude: Double, speedKmh: Double) {
            self.id = id
            self.latitude = latitude
            self.longitude = longitude
            self.speedKmh = speedKmh
        }
    }

    public init(
        id: UUID = UUID(),
        tripId: UUID = UUID(),
        date: Date = Date(),
        durationSeconds: TimeInterval = 0,
        distanceMeters: Double = 0,
        averageSpeedKmh: Double = 0,
        topSpeedKmh: Double = 0,
        drivingScore: Int = 100,
        badgeTier: SmoothnessBadgeTier = .formulaElite,
        peakLateralG: Double = 0.45,
        peakLongitudinalG: Double = 0.38,
        peakCombinedG: Double = 0.58,
        harshBrakingCount: Int = 0,
        harshAccelerationCount: Int = 0,
        harshCorneringCount: Int = 0,
        vehicleName: String = "911 GT3 RS",
        vehicleBrand: String = "PORSCHE",
        vehicleImageName: String = "car_porsche_911",
        vehicleAccentHex: String = "#FFE600",
        useMilesPerHour: Bool = false,
        routeCoordinates: [RouteCoordinate] = [],
        targetWidth: CGFloat = 1080,
        targetHeight: CGFloat = 1920
    ) {
        self.id = id
        self.tripId = tripId
        self.date = date
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.averageSpeedKmh = averageSpeedKmh
        self.topSpeedKmh = topSpeedKmh
        self.drivingScore = drivingScore
        self.badgeTier = badgeTier
        self.peakLateralG = peakLateralG
        self.peakLongitudinalG = peakLongitudinalG
        self.peakCombinedG = peakCombinedG
        self.harshBrakingCount = harshBrakingCount
        self.harshAccelerationCount = harshAccelerationCount
        self.harshCorneringCount = harshCorneringCount
        self.vehicleName = vehicleName
        self.vehicleBrand = vehicleBrand
        self.vehicleImageName = vehicleImageName
        self.vehicleAccentHex = vehicleAccentHex
        self.useMilesPerHour = useMilesPerHour
        self.routeCoordinates = routeCoordinates
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
    }

    /// Convenience factory from a TripModel, UserPreferences, and optional VehicleModel.
    public init(
        trip: TripModel,
        preferences: UserPreferences = UserPreferences(),
        vehicle: VehicleModel? = nil,
        metrics: SmoothnessMetrics? = nil
    ) {
        let evaluatedMetrics = metrics ?? SmoothnessScorer.evaluate(trip: trip)
        let coords = trip.points.map {
            RouteCoordinate(id: $0.id, latitude: $0.latitude, longitude: $0.longitude, speedKmh: $0.speedKmh)
        }

        let defaultVehicle = VehicleCatalogService.shared.vehicles.first { $0.id == "porsche_911" }
        let resolvedVehicle = vehicle ?? defaultVehicle

        self.init(
            id: UUID(),
            tripId: trip.id,
            date: trip.startTime,
            durationSeconds: trip.durationSeconds,
            distanceMeters: trip.distanceMeters,
            averageSpeedKmh: trip.averageSpeedKmh,
            topSpeedKmh: trip.maxSpeedKmh,
            drivingScore: trip.drivingScore,
            badgeTier: evaluatedMetrics.badgeTier,
            peakLateralG: evaluatedMetrics.peakLateralG,
            peakLongitudinalG: evaluatedMetrics.peakLongitudinalG,
            peakCombinedG: evaluatedMetrics.peakCombinedG,
            harshBrakingCount: trip.harshBrakingCount,
            harshAccelerationCount: trip.harshAccelerationCount,
            harshCorneringCount: trip.harshCorneringCount,
            vehicleName: resolvedVehicle?.name.uppercased() ?? preferences.driveVehicleName.uppercased(),
            vehicleBrand: resolvedVehicle?.brandId.uppercased() ?? "DASHCAST",
            vehicleImageName: resolvedVehicle?.imageName ?? preferences.driveVehicleImage,
            vehicleAccentHex: evaluatedMetrics.badgeTier.accentHex,
            useMilesPerHour: preferences.useMilesPerHour,
            routeCoordinates: coords,
            targetWidth: 1080,
            targetHeight: 1920
        )
    }

    // MARK: - Formatting Helpers

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy • h:mm a"
        return formatter.string(from: date).uppercased()
    }

    public var formattedDuration: String {
        let totalSeconds = Int(durationSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm %02ds", minutes, seconds)
        }
    }

    public var formattedDistance: String {
        if useMilesPerHour {
            let miles = distanceMeters * 0.000621371
            return String(format: "%.1f MI", miles)
        } else {
            let km = distanceMeters / 1000.0
            return String(format: "%.1f KM", km)
        }
    }

    public var formattedTopSpeed: String {
        if useMilesPerHour {
            let mph = topSpeedKmh * 0.621371
            return String(format: "%.0f MPH", mph)
        } else {
            return String(format: "%.0f KM/H", topSpeedKmh)
        }
    }

    public var formattedAverageSpeed: String {
        if useMilesPerHour {
            let mph = averageSpeedKmh * 0.621371
            return String(format: "%.0f MPH", mph)
        } else {
            return String(format: "%.0f KM/H", averageSpeedKmh)
        }
    }

    public var formattedPeakG: String {
        String(format: "%.2f G", peakCombinedG)
    }

    public var formattedLateralG: String {
        String(format: "%.2f G", peakLateralG)
    }

    public var formattedLongitudinalG: String {
        String(format: "%.2f G", peakLongitudinalG)
    }

    public var vehicleAccentColor: Color {
        Color(hex: vehicleAccentHex)
    }

    public var targetAspect: CGFloat {
        targetWidth / targetHeight // 9 / 16 (0.5625)
    }

    // MARK: - JSON Serialization

    public func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func fromJSONData(_ data: Data) throws -> DriveSummaryCardData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DriveSummaryCardData.self, from: data)
    }
}
