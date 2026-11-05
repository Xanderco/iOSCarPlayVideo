import Foundation

/// Seeds realistic demo content when the app is launched with `-seedDemoData`.
/// Used by the App Store media pipeline (Scripts/generate-appstore-media.sh) so
/// screenshots show populated screens instead of empty states. Never runs in
/// normal launches.
@MainActor
enum DemoDataSeeder {
    static let launchArgument = "-seedDemoData"

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static func seedIfRequested() {
        guard isRequested else { return }
        seed()
    }

    /// Defaults are resolved inside the body: default-argument expressions are evaluated in a
    /// nonisolated context, so `= .shared` on the main-actor `UsageMetricsManager` warned.
    static func seed(persistence: PersistenceController? = nil,
                     metrics: UsageMetricsManager? = nil) {
        let persistence = persistence ?? .shared
        let metrics = metrics ?? .shared
        guard persistence.loadTrips().isEmpty else { return }

        let trips = demoTrips()
        persistence.saveTrips(trips)
        if metrics.metrics.totalTripsRecorded == 0 {
            trips.forEach { metrics.recordTrip(trip: $0) }
            (0..<14).forEach { _ in metrics.recordVideoPlayed() }
            (0..<9).forEach { _ in metrics.recordSoundPlayed() }
        }
    }

    static func demoTrips(now: Date = Date()) -> [TripModel] {
        // (hours ago, duration min, km, avg km/h, max km/h, score)
        let specs: [(Double, Double, Double, Double, Double, Int)] = [
            (3, 24, 18.6, 46, 92, 97),
            (27, 41, 37.2, 54, 108, 93),
            (51, 12, 6.4, 32, 61, 100),
            (75, 58, 71.9, 74, 121, 89)
        ]
        let origin = (lat: 37.7793, lon: -122.4193)
        return specs.enumerated().map { index, spec in
            let start = now.addingTimeInterval(-spec.0 * 3600)
            let end = start.addingTimeInterval(spec.1 * 60)
            let points = (0..<24).map { step -> TripPoint in
                let t = Double(step) / 23.0
                return TripPoint(
                    latitude: origin.lat + t * 0.06 * cos(Double(index)) + 0.004 * sin(t * 6),
                    longitude: origin.lon + t * 0.06 * sin(Double(index) + 0.6),
                    speedKmh: spec.3 + (spec.4 - spec.3) * abs(sin(t * .pi * 2)),
                    altitudeMeters: 20 + 35 * t,
                    timestamp: start.addingTimeInterval(t * spec.1 * 60)
                )
            }
            return TripModel(
                startTime: start,
                endTime: end,
                distanceMeters: spec.2 * 1000,
                averageSpeedKmh: spec.3,
                maxSpeedKmh: spec.4,
                drivingScore: spec.5,
                points: points,
                harshBrakingCount: spec.5 < 95 ? 1 : 0
            )
        }
    }
}
