import XCTest
import SwiftUI
import CoreLocation
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

    func testTripHistoryMetricsFormatterDistanceScoreAndDuration() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let trips = [
            TripModel(
                id: UUID(),
                startTime: t0,
                endTime: t0.addingTimeInterval(300),
                distanceMeters: 5000,
                averageSpeedKmh: 60,
                maxSpeedKmh: 90,
                drivingScore: 90
            ),
            TripModel(
                id: UUID(),
                startTime: t0,
                endTime: t0.addingTimeInterval(600),
                distanceMeters: 15000,
                averageSpeedKmh: 75,
                maxSpeedKmh: 100,
                drivingScore: 80
            )
        ]

        XCTAssertEqual(TripHistoryMetricsFormatter.averageScore(trips: []), 0)
        XCTAssertEqual(TripHistoryMetricsFormatter.averageScore(trips: trips), 85)
        XCTAssertEqual(TripHistoryMetricsFormatter.totalDistanceFormatted(trips: trips, useMilesPerHour: false), "20.0 km")
        XCTAssertEqual(TripHistoryMetricsFormatter.totalDistanceFormatted(trips: trips, useMilesPerHour: true), "12.4 mi")
        XCTAssertEqual(TripHistoryMetricsFormatter.distanceText(meters: 5000, useMilesPerHour: false), "5.0 km")
        XCTAssertEqual(TripHistoryMetricsFormatter.distanceText(meters: 5000, useMilesPerHour: true), "3.1 mi")
        XCTAssertEqual(TripHistoryMetricsFormatter.durationText(seconds: 95), "1m 35s")
        XCTAssertEqual(TripHistoryMetricsFormatter.durationText(seconds: 3900), "1h 5m")
    }

    @MainActor
    func testTripHistoryCopyHeadersAndSwiftUIKeys() {
        XCTAssertEqual(TripHistoryCopy.allRecordedTripsHeader(count: 3), "All Recorded Trips (3)")
        XCTAssertEqual(TripHistoryCopy.totalDrivesKey, LocalizedStringKey(TripHistoryCopy.totalDrivesString))
        XCTAssertEqual(TripHistoryCopy.totalDistanceKey, LocalizedStringKey(TripHistoryCopy.totalDistanceString))
        XCTAssertEqual(TripHistoryCopy.avgScoreKey, LocalizedStringKey(TripHistoryCopy.avgScoreString))
        XCTAssertEqual(TripHistoryCopy.summaryHeaderKey, LocalizedStringKey(TripHistoryCopy.summaryHeaderString))
        XCTAssertEqual(TripHistoryCopy.navigationTitleKey, LocalizedStringKey(TripHistoryCopy.navigationTitleString))
        XCTAssertEqual(TripHistoryCopy.closeKey, LocalizedStringKey(TripHistoryCopy.closeString))
        XCTAssertEqual(TripHistoryCopy.clearAllAccessibilityKey, LocalizedStringKey(TripHistoryCopy.clearAllAccessibilityString))
        XCTAssertEqual(TripHistoryCopy.clearAlertTitleKey, LocalizedStringKey(TripHistoryCopy.clearAlertTitleString))
        XCTAssertEqual(TripHistoryCopy.clearAllButtonKey, LocalizedStringKey(TripHistoryCopy.clearAllButtonString))
        XCTAssertEqual(TripHistoryCopy.cancelKey, LocalizedStringKey(TripHistoryCopy.cancelString))
        XCTAssertEqual(TripHistoryCopy.clearAlertMessageKey, LocalizedStringKey(TripHistoryCopy.clearAlertMessageString))
        XCTAssertEqual(TripHistoryCopy.replayKey, LocalizedStringKey(TripHistoryCopy.replayString))
        XCTAssertEqual(TripHistoryCopy.scoreBadgeKey, LocalizedStringKey(TripHistoryCopy.scoreBadgeString))
    }

    func testTripHistoryCopyLocalizationKeysComplete() throws {
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

        for key in TripHistoryCopy.allLocalizationKeys {
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
