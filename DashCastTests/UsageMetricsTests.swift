import XCTest
@testable import DashCast

final class UsageMetricsTests: XCTestCase {
    var defaults: UserDefaults!
    var metrics: UsageMetricsManager!

    @MainActor
    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "UsageMetricsTestDefaults")!
        defaults.removePersistentDomain(forName: "UsageMetricsTestDefaults")
        metrics = UsageMetricsManager(userDefaults: defaults)
    }

    @MainActor
    override func tearDown() {
        defaults.removePersistentDomain(forName: "UsageMetricsTestDefaults")
        super.tearDown()
    }

    @MainActor
    func testInitialMetrics() {
        XCTAssertEqual(metrics.metrics.totalTripsRecorded, 0)
        XCTAssertEqual(metrics.metrics.totalVideosWatched, 0)
        XCTAssertEqual(metrics.metrics.totalSoundsPlayed, 0)
        XCTAssertEqual(metrics.metrics.averageDrivingScore, 100.0)
    }

    @MainActor
    func testRecordTripAndAverageScore() {
        let trip1 = TripModel(distanceMeters: 5000, drivingScore: 90)
        let trip2 = TripModel(distanceMeters: 10000, drivingScore: 100)

        metrics.recordTrip(trip: trip1)
        metrics.recordTrip(trip: trip2)

        XCTAssertEqual(metrics.metrics.totalTripsRecorded, 2)
        XCTAssertEqual(metrics.metrics.totalDistanceDrivenMeters, 15000)
        XCTAssertEqual(metrics.metrics.totalDistanceKm, 15.0)
        XCTAssertEqual(metrics.metrics.averageDrivingScore, 95.0)
    }

    @MainActor
    func testRecordActions() {
        metrics.recordVideoPlayed()
        metrics.recordVideoPlayed()
        XCTAssertEqual(metrics.metrics.totalVideosWatched, 2)

        metrics.recordSoundPlayed()
        XCTAssertEqual(metrics.metrics.totalSoundsPlayed, 1)

        metrics.recordWidgetCustomization()
        XCTAssertEqual(metrics.metrics.widgetCustomizationsCount, 1)
    }

    func testUsageMetricsFormatterDistanceDurationAndScore() {
        XCTAssertEqual(UsageMetricsFormatter.distanceString(distanceKm: 12.34, distanceMiles: 7.67, useMilesPerHour: false), "12.3 km")
        XCTAssertEqual(UsageMetricsFormatter.distanceString(distanceKm: 12.34, distanceMiles: 7.67, useMilesPerHour: true), "7.7 mi")
        XCTAssertEqual(UsageMetricsFormatter.distanceString(distanceKm: -5, distanceMiles: -5, useMilesPerHour: false), "0.0 km")
        XCTAssertEqual(UsageMetricsFormatter.distanceString(distanceKm: .nan, distanceMiles: .infinity, useMilesPerHour: true), "0.0 mi")

        XCTAssertEqual(UsageMetricsFormatter.durationString(totalSeconds: 0), "0h 0m")
        XCTAssertEqual(UsageMetricsFormatter.durationString(totalSeconds: -120), "0h 0m")
        XCTAssertEqual(UsageMetricsFormatter.durationString(totalSeconds: .nan), "0h 0m")
        XCTAssertEqual(UsageMetricsFormatter.durationString(totalSeconds: .infinity), "0h 0m")
        XCTAssertEqual(UsageMetricsFormatter.durationString(totalSeconds: 3665), "1h 1m")
        XCTAssertEqual(UsageMetricsFormatter.durationString(totalSeconds: 7380), "2h 3m")

        XCTAssertEqual(UsageMetricsFormatter.safetyScoreString(score: 95.4), "95 / 100")
        XCTAssertEqual(UsageMetricsFormatter.safetyScoreString(score: -10), "0 / 100")
        XCTAssertEqual(UsageMetricsFormatter.safetyScoreString(score: 125), "100 / 100")
        XCTAssertEqual(UsageMetricsFormatter.safetyScoreString(score: .nan), "0 / 100")
        XCTAssertEqual(UsageMetricsFormatter.safetyScoreString(score: .infinity), "0 / 100")
    }

    func testUsageMetricsLocalizationKeysComplete() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectDir
            .appendingPathComponent("DashCast")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])

        for key in UsageMetricsCopy.allLocalizationKeys {
            let entry = try XCTUnwrap(strings[key], "Missing Localizable.xcstrings entry for: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]], "Missing localizations for: \(key)")
            for lang in ["en", "es"] {
                let unit = try XCTUnwrap(localizations[lang]?["stringUnit"] as? [String: Any], "Missing \(lang) stringUnit for: \(key)")
                let value = try XCTUnwrap(unit["value"] as? String)
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(lang) translation for: \(key)")
            }
        }
    }
}
