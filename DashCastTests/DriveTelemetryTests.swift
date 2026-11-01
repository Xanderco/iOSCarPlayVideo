import XCTest
@testable import DashCast

final class DriveTelemetryTests: XCTestCase {
    @MainActor
    func testDrivingScorerBaseScore() {
        let scorer = DrivingScorer.shared
        scorer.reset()
        XCTAssertEqual(scorer.calculateScore(), 100)
    }

    @MainActor
    func testDrivingScorerHarshEvents() {
        let scorer = DrivingScorer.shared
        scorer.reset()

        scorer.recordHarshEvent(.braking) // -4
        XCTAssertEqual(scorer.harshBrakingCount, 1)
        XCTAssertEqual(scorer.calculateScore(), 96)

        scorer.recordHarshEvent(.acceleration) // -3
        XCTAssertEqual(scorer.harshAccelerationCount, 1)
        XCTAssertEqual(scorer.calculateScore(), 93)

        scorer.recordHarshEvent(.cornering) // -3
        XCTAssertEqual(scorer.harshCorneringCount, 1)
        XCTAssertEqual(scorer.calculateScore(), 90)
    }

    @MainActor
    func testDrivingScorerMinimumFloor() {
        let scorer = DrivingScorer.shared
        scorer.reset()

        // 30 harsh braking events (30 * 4 = 120 penalty)
        for _ in 0..<30 {
            scorer.recordHarshEvent(.braking)
        }
        XCTAssertEqual(scorer.calculateScore(), 10) // minimum clamped at 10
    }

    @MainActor
    func testLocationServiceSimulation() {
        let service = DriveLocationService.shared
        service.startTrip()

        service.simulatePoint(latitude: 37.7749, longitude: -122.4194, speedKmh: 45.0, altitude: 20.0)
        XCTAssertEqual(service.currentSpeedKmh, 45.0)
        XCTAssertEqual(service.topSpeedKmh, 45.0)

        service.simulatePoint(latitude: 37.7750, longitude: -122.4195, speedKmh: 68.0, altitude: 22.0)
        XCTAssertEqual(service.currentSpeedKmh, 68.0)
        XCTAssertEqual(service.topSpeedKmh, 68.0)

        let trip = service.endTrip()
        XCTAssertFalse(service.isTracking)
        XCTAssertEqual(trip.points.count, 2)
        XCTAssertEqual(trip.maxSpeedKmh, 68.0)
    }
}
