import Foundation
import Combine

public struct LocalUsageMetrics: Codable {
    public var totalTripsRecorded: Int
    public var totalDistanceDrivenMeters: Double
    public var totalDurationSeconds: Double
    public var totalVideosWatched: Int
    public var totalSoundsPlayed: Int
    public var widgetCustomizationsCount: Int
    public var totalHexesClaimed: Int
    public var drivingScoresList: [Int]
    public var firstLaunchDate: Date
    public var lastActiveDate: Date

    public init(
        totalTripsRecorded: Int = 0,
        totalDistanceDrivenMeters: Double = 0,
        totalDurationSeconds: Double = 0,
        totalVideosWatched: Int = 0,
        totalSoundsPlayed: Int = 0,
        widgetCustomizationsCount: Int = 0,
        totalHexesClaimed: Int = 0,
        drivingScoresList: [Int] = [],
        firstLaunchDate: Date = Date(),
        lastActiveDate: Date = Date()
    ) {
        self.totalTripsRecorded = totalTripsRecorded
        self.totalDistanceDrivenMeters = totalDistanceDrivenMeters
        self.totalDurationSeconds = totalDurationSeconds
        self.totalVideosWatched = totalVideosWatched
        self.totalSoundsPlayed = totalSoundsPlayed
        self.widgetCustomizationsCount = widgetCustomizationsCount
        self.totalHexesClaimed = totalHexesClaimed
        self.drivingScoresList = drivingScoresList
        self.firstLaunchDate = firstLaunchDate
        self.lastActiveDate = lastActiveDate
    }

    public var averageDrivingScore: Double {
        guard !drivingScoresList.isEmpty else { return 100.0 }
        let sum = drivingScoresList.reduce(0, +)
        return Double(sum) / Double(drivingScoresList.count)
    }

    public var totalDistanceKm: Double {
        totalDistanceDrivenMeters / 1000.0
    }

    public var totalDistanceMiles: Double {
        totalDistanceDrivenMeters * 0.000621371
    }
}

@MainActor
public final class UsageMetricsManager: ObservableObject {
    public static let shared = UsageMetricsManager()

    @Published public private(set) var metrics: LocalUsageMetrics

    private let metricsKey = "dashcast_local_user_metrics_data"
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: metricsKey),
           let decoded = try? JSONDecoder().decode(LocalUsageMetrics.self, from: data) {
            self.metrics = decoded
        } else {
            self.metrics = LocalUsageMetrics()
        }
    }

    public func recordTrip(trip: TripModel) {
        metrics.totalTripsRecorded += 1
        metrics.totalDistanceDrivenMeters += trip.distanceMeters
        metrics.totalDurationSeconds += trip.durationSeconds
        metrics.drivingScoresList.append(trip.drivingScore)
        metrics.lastActiveDate = Date()
        saveMetrics()
    }

    public func recordVideoPlayed() {
        metrics.totalVideosWatched += 1
        metrics.lastActiveDate = Date()
        saveMetrics()
    }

    public func recordSoundPlayed() {
        metrics.totalSoundsPlayed += 1
        metrics.lastActiveDate = Date()
        saveMetrics()
    }

    public func recordWidgetCustomization() {
        metrics.widgetCustomizationsCount += 1
        metrics.lastActiveDate = Date()
        saveMetrics()
    }

    public func recordHexClaimed(count: Int = 1) {
        metrics.totalHexesClaimed += count
        metrics.lastActiveDate = Date()
        saveMetrics()
    }

    private func saveMetrics() {
        if let encoded = try? JSONEncoder().encode(metrics) {
            userDefaults.set(encoded, forKey: metricsKey)
        }
    }
}
