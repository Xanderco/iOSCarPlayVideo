import Foundation
import CoreLocation

public struct TripPoint: Codable, Identifiable {
    public var id: UUID = UUID()
    public var latitude: Double
    public var longitude: Double
    public var speedKmh: Double
    public var altitudeMeters: Double
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        speedKmh: Double,
        altitudeMeters: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.speedKmh = speedKmh
        self.altitudeMeters = altitudeMeters
        self.timestamp = timestamp
    }
}

public struct TripModel: Codable, Identifiable {
    public var id: UUID
    public var startTime: Date
    public var endTime: Date?
    public var distanceMeters: Double
    public var averageSpeedKmh: Double
    public var maxSpeedKmh: Double
    public var drivingScore: Int // 0 - 100
    public var points: [TripPoint]
    public var harshBrakingCount: Int
    public var harshAccelerationCount: Int
    public var harshCorneringCount: Int

    public init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        distanceMeters: Double = 0,
        averageSpeedKmh: Double = 0,
        maxSpeedKmh: Double = 0,
        drivingScore: Int = 100,
        points: [TripPoint] = [],
        harshBrakingCount: Int = 0,
        harshAccelerationCount: Int = 0,
        harshCorneringCount: Int = 0
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.distanceMeters = distanceMeters
        self.averageSpeedKmh = averageSpeedKmh
        self.maxSpeedKmh = maxSpeedKmh
        self.drivingScore = drivingScore
        self.points = points
        self.harshBrakingCount = harshBrakingCount
        self.harshAccelerationCount = harshAccelerationCount
        self.harshCorneringCount = harshCorneringCount
    }

    public var durationSeconds: TimeInterval {
        let end = endTime ?? Date()
        return max(end.timeIntervalSince(startTime), 0)
    }

    public var distanceKilometers: Double {
        distanceMeters / 1000.0
    }

    public var distanceMiles: Double {
        distanceMeters * 0.000621371
    }
}
