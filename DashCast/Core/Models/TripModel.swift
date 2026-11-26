import Foundation
import CoreLocation

public enum TripCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case personal
    case business
    case commute

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .personal: return "Personal"
        case .business: return "Business"
        case .commute: return "Commute"
        }
    }

    public var systemImage: String {
        switch self {
        case .personal: return "person.fill"
        case .business: return "briefcase.fill"
        case .commute: return "building.2.fill"
        }
    }
}

public struct TripPoint: Codable, Identifiable, Equatable, Sendable {
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

public struct TripModel: Codable, Identifiable, Equatable, Sendable {
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
    public var category: TripCategory?
    public var note: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case startTime
        case endTime
        case distanceMeters
        case averageSpeedKmh
        case maxSpeedKmh
        case drivingScore
        case points
        case harshBrakingCount
        case harshAccelerationCount
        case harshCorneringCount
        case category
        case note
    }

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
        harshCorneringCount: Int = 0,
        category: TripCategory? = nil,
        note: String? = nil
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
        self.category = category
        self.note = Self.normalizedNote(note)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.startTime = try container.decode(Date.self, forKey: .startTime)
        self.endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        self.distanceMeters = try container.decode(Double.self, forKey: .distanceMeters)
        self.averageSpeedKmh = try container.decode(Double.self, forKey: .averageSpeedKmh)
        self.maxSpeedKmh = try container.decode(Double.self, forKey: .maxSpeedKmh)
        self.drivingScore = try container.decode(Int.self, forKey: .drivingScore)
        self.points = try container.decodeIfPresent([TripPoint].self, forKey: .points) ?? []
        self.harshBrakingCount = try container.decodeIfPresent(Int.self, forKey: .harshBrakingCount) ?? 0
        self.harshAccelerationCount = try container.decodeIfPresent(Int.self, forKey: .harshAccelerationCount) ?? 0
        self.harshCorneringCount = try container.decodeIfPresent(Int.self, forKey: .harshCorneringCount) ?? 0

        if let rawCategory = try container.decodeIfPresent(String.self, forKey: .category) {
            self.category = TripCategory(rawValue: rawCategory)
        } else {
            self.category = nil
        }

        let rawNote = try container.decodeIfPresent(String.self, forKey: .note)
        self.note = Self.normalizedNote(rawNote)
    }

    public static func normalizedNote(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
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

public struct TripCategorySummary: Equatable, Sendable {
    public let category: TripCategory?
    public let tripCount: Int
    public let totalDistanceMeters: Double
    public let averageScore: Int

    public var totalDistanceKilometers: Double {
        totalDistanceMeters / 1000.0
    }

    public var totalDistanceMiles: Double {
        totalDistanceMeters * 0.000621371
    }

    public static func filter(_ trips: [TripModel], by category: TripCategory?) -> [TripModel] {
        guard let category else { return trips }
        return trips.filter { $0.category == category }
    }

    public static func summarize(_ trips: [TripModel], category: TripCategory? = nil) -> TripCategorySummary {
        let matching = filter(trips, by: category)
        let totalMeters = matching.reduce(0.0) { $0 + $1.distanceMeters }
        let averageScore: Int
        if matching.isEmpty {
            averageScore = 0
        } else {
            averageScore = matching.reduce(0) { $0 + $1.drivingScore } / matching.count
        }
        return TripCategorySummary(
            category: category,
            tripCount: matching.count,
            totalDistanceMeters: totalMeters,
            averageScore: averageScore
        )
    }

    public static func breakdown(for trips: [TripModel]) -> [TripCategory: TripCategorySummary] {
        var result: [TripCategory: TripCategorySummary] = [:]
        for category in TripCategory.allCases {
            result[category] = summarize(trips, category: category)
        }
        return result
    }
}
