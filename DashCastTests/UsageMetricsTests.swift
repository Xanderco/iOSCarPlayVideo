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

        metrics.recordHexClaimed(count: 5)
        XCTAssertEqual(metrics.metrics.totalHexesClaimed, 5)
    }
}
