import XCTest
import CoreLocation
import SwiftUI
@testable import DashCast

final class TripHistoryAndReplayTests: XCTestCase {

    func testReplayIndexClampingAndBoundaries() {
        // Zero count edge case
        XCTAssertEqual(TripReplayMapView.index(for: 0.5, count: 0), 0)
        XCTAssertEqual(TripReplayMapView.index(for: 0, count: 0), 0)
        XCTAssertEqual(TripReplayMapView.index(for: 1.0, count: 0), 0)

        // Single coordinate
        XCTAssertEqual(TripReplayMapView.index(for: 0, count: 1), 0)
        XCTAssertEqual(TripReplayMapView.index(for: 0.5, count: 1), 0)
        XCTAssertEqual(TripReplayMapView.index(for: 1.0, count: 1), 0)

        // Normal route with 21 points (indices 0...20)
        XCTAssertEqual(TripReplayMapView.index(for: 0.0, count: 21), 0)
        XCTAssertEqual(TripReplayMapView.index(for: 0.25, count: 21), 5)
        XCTAssertEqual(TripReplayMapView.index(for: 0.5, count: 21), 10)
        XCTAssertEqual(TripReplayMapView.index(for: 0.75, count: 21), 15)
        XCTAssertEqual(TripReplayMapView.index(for: 1.0, count: 21), 20)

        // Underflow & overflow clamping
        XCTAssertEqual(TripReplayMapView.index(for: -0.5, count: 21), 0)
        XCTAssertEqual(TripReplayMapView.index(for: -99.0, count: 21), 0)
        XCTAssertEqual(TripReplayMapView.index(for: 1.5, count: 21), 20)
        XCTAssertEqual(TripReplayMapView.index(for: 99.0, count: 21), 20)
    }

    func testTripCoordinatesExtraction() {
        let t0 = Date()
        let points = [
            TripPoint(latitude: 37.7749, longitude: -122.4194, speedKmh: 45.0, altitudeMeters: 15.0, timestamp: t0),
            TripPoint(latitude: 37.7750, longitude: -122.4180, speedKmh: 50.0, altitudeMeters: 16.0, timestamp: t0.addingTimeInterval(10)),
            TripPoint(latitude: 37.7760, longitude: -122.4170, speedKmh: 55.0, altitudeMeters: 18.0, timestamp: t0.addingTimeInterval(20))
        ]

        let trip = TripModel(
            id: UUID(),
            startTime: t0,
            endTime: t0.addingTimeInterval(20),
            distanceMeters: 1500,
            averageSpeedKmh: 50.0,
            maxSpeedKmh: 55.0,
            drivingScore: 92,
            points: points,
            harshBrakingCount: 0,
            harshAccelerationCount: 1,
            harshCorneringCount: 0
        )

        let coordinates = trip.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        XCTAssertEqual(coordinates.count, 3)
        XCTAssertEqual(coordinates[0].latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(coordinates[0].longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(coordinates[2].latitude, 37.7760, accuracy: 0.0001)
        XCTAssertEqual(coordinates[2].longitude, -122.4170, accuracy: 0.0001)
        XCTAssertEqual(trip.durationSeconds, 20, accuracy: 0.1)
    }

    func testTripDistanceAndSpeedConversions() {
        let t0 = Date()
        let trip = TripModel(
            id: UUID(),
            startTime: t0,
            endTime: t0.addingTimeInterval(300),
            distanceMeters: 5000, // 5 km = ~3.10686 miles
            averageSpeedKmh: 60.0, // ~37.28 mph
            maxSpeedKmh: 90.0,     // ~55.92 mph
            drivingScore: 88
        )

        // Kilometers
        let km = trip.distanceKilometers
        XCTAssertEqual(km, 5.0, accuracy: 0.01)

        // Miles
        let miles = trip.distanceMeters * 0.000621371
        XCTAssertEqual(miles, 3.106855, accuracy: 0.01)

        // Average Speed mph
        let avgMph = trip.averageSpeedKmh * 0.621371
        XCTAssertEqual(avgMph, 37.28, accuracy: 0.1)

        // Max Speed mph
        let topMph = trip.maxSpeedKmh * 0.621371
        XCTAssertEqual(topMph, 55.92, accuracy: 0.1)

        // Duration seconds
        XCTAssertEqual(trip.durationSeconds, 300, accuracy: 0.1)
    }

    func testTripMapModeEnum() {
        XCTAssertEqual(TripMapMode.allCases.count, 2)
        XCTAssertEqual(TripMapMode.replay.rawValue, "Route Replay")
        XCTAssertEqual(TripMapMode.heatmap.rawValue, "Speed Heatmap")
        XCTAssertEqual(TripMapMode.replay.id, "Route Replay")
        XCTAssertEqual(TripMapMode.heatmap.id, "Speed Heatmap")
    }

    func testTripPersistenceCycle() {
        let testTrip = TripModel(
            id: UUID(),
            startTime: Date(timeIntervalSince1970: 1000),
            endTime: Date(timeIntervalSince1970: 1600),
            distanceMeters: 12000,
            averageSpeedKmh: 72.0,
            maxSpeedKmh: 110.0,
            drivingScore: 95
        )

        var trips = PersistenceController.shared.loadTrips()
        let initialCount = trips.count

        trips.insert(testTrip, at: 0)
        PersistenceController.shared.saveTrips(trips)

        let loaded = PersistenceController.shared.loadTrips()
        XCTAssertEqual(loaded.count, initialCount + 1)
        XCTAssertEqual(loaded.first?.id, testTrip.id)
        XCTAssertEqual(loaded.first?.drivingScore, 95)
        XCTAssertEqual(loaded.first?.distanceMeters, 12000)

        // Clean up
        let cleaned = loaded.filter { $0.id != testTrip.id }
        PersistenceController.shared.saveTrips(cleaned)
        XCTAssertEqual(PersistenceController.shared.loadTrips().count, initialCount)
    }

    func testTripSummaryMetricsFormatter() {
        XCTAssertEqual(TripSummaryMetricsFormatter.formattedDistance(meters: 4800, useMilesPerHour: false), "4.80 km")
        XCTAssertEqual(TripSummaryMetricsFormatter.formattedDistance(meters: 1609.344, useMilesPerHour: true), "1.00 mi")
        XCTAssertEqual(TripSummaryMetricsFormatter.formattedDistance(meters: -10, useMilesPerHour: false), "0.00 km")
        XCTAssertEqual(TripSummaryMetricsFormatter.formattedDistance(meters: .nan, useMilesPerHour: true), "0.00 mi")

        XCTAssertEqual(TripSummaryMetricsFormatter.formattedSpeed(kmh: 82.4, useMilesPerHour: false), "82 km/h")
        XCTAssertEqual(TripSummaryMetricsFormatter.formattedSpeed(kmh: 100.0, useMilesPerHour: true), "62 mph")
        XCTAssertEqual(TripSummaryMetricsFormatter.formattedSpeed(kmh: -5, useMilesPerHour: false), "0 km/h")
        XCTAssertEqual(TripSummaryMetricsFormatter.formattedSpeed(kmh: .infinity, useMilesPerHour: true), "0 mph")

        XCTAssertEqual(TripSummaryMetricsFormatter.formattedDuration(seconds: 125), "2m 05s")
        XCTAssertEqual(TripSummaryMetricsFormatter.formattedDuration(seconds: -3), "0m 00s")
        XCTAssertEqual(TripSummaryMetricsFormatter.formattedDuration(seconds: .nan), "0m 00s")

        XCTAssertEqual(TripSummaryMetricsFormatter.scoreTierString(for: 95), TripSummaryCopy.smoothEfficientScoreString)
        XCTAssertEqual(TripSummaryMetricsFormatter.scoreTierString(for: 85), TripSummaryCopy.goodDrivingScoreString)
        XCTAssertEqual(TripSummaryMetricsFormatter.scoreTierString(for: 75), TripSummaryCopy.moderateRideScoreString)
        XCTAssertEqual(TripSummaryMetricsFormatter.scoreTierString(for: 50), TripSummaryCopy.aggressiveDrivingScoreString)
    }

    @MainActor
    func testTripMapModeLocalizedTitles() {
        XCTAssertEqual(TripMapMode.replay.localizedTitle, TripSummaryCopy.routeReplayKey)
        XCTAssertEqual(TripMapMode.heatmap.localizedTitle, TripSummaryCopy.speedHeatmapKey)
        XCTAssertEqual(TripSummaryMetricsFormatter.scoreTierKey(for: 92), LocalizedStringKey(TripSummaryCopy.smoothEfficientScoreString))
    }

    func testTripSummaryCopyLocalizationKeysComplete() throws {
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

        for key in TripSummaryCopy.allLocalizationKeys {
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
