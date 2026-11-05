import XCTest
@testable import DashCast

@MainActor
final class DemoDataSeederTests: XCTestCase {
    func testSeedPopulatesTripsAndMetricsOnce() {
        let suite = "DemoDataSeederTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let persistence = PersistenceController(userDefaults: defaults)
        let metrics = UsageMetricsManager(userDefaults: defaults)

        DemoDataSeeder.seed(persistence: persistence, metrics: metrics)
        XCTAssertEqual(persistence.loadTrips().count, 4)
        XCTAssertEqual(metrics.metrics.totalTripsRecorded, 4)

        // Seeding again must not duplicate data.
        DemoDataSeeder.seed(persistence: persistence, metrics: metrics)
        XCTAssertEqual(persistence.loadTrips().count, 4)
        XCTAssertEqual(metrics.metrics.totalTripsRecorded, 4)
    }

    func testDemoTripsAreValid() {
        let trips = DemoDataSeeder.demoTrips()
        XCTAssertFalse(trips.isEmpty)
        for trip in trips {
            XCTAssertTrue((0...100).contains(trip.drivingScore))
            XCTAssertGreaterThan(trip.distanceMeters, 0)
            XCTAssertNotNil(trip.endTime)
            XCTAssertFalse(trip.points.isEmpty)
        }
    }
}
