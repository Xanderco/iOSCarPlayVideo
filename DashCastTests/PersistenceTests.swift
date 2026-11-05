import XCTest
@testable import DashCast

final class PersistenceTests: XCTestCase {
    var testDefaults: UserDefaults!
    var persistence: PersistenceController!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "DashCastTestDefaults")
        testDefaults.removePersistentDomain(forName: "DashCastTestDefaults")
        persistence = PersistenceController(userDefaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "DashCastTestDefaults")
        super.tearDown()
    }

    func testSaveAndLoadTrips() {
        let trip = TripModel(
            id: UUID(),
            distanceMeters: 4200,
            averageSpeedKmh: 45,
            maxSpeedKmh: 75,
            drivingScore: 98
        )
        persistence.saveTrips([trip])

        let loaded = persistence.loadTrips()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, trip.id)
        XCTAssertEqual(loaded.first?.distanceMeters, 4200)
    }
}
