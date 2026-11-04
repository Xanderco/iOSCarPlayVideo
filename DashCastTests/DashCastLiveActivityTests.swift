import XCTest
@testable import DashCast

final class DashCastLiveActivityTests: XCTestCase {

    @MainActor
    override func setUp() {
        super.setUp()
        DriveLiveActivityManager.shared.isTestMode = true
        DrivingScorer.shared.reset()
    }

    @MainActor
    override func tearDown() {
        DriveLiveActivityManager.shared.endLiveActivity(dismissImmediately: true)
        DriveLiveActivityManager.shared.isTestMode = false
        super.tearDown()
    }

    // MARK: - Attributes & ContentState Serialization

    func testTelemetryAttributesEncodingAndDecoding() throws {
        let attributes = DashCastTelemetryAttributes(
            tripId: "TEST-TRIP-123",
            vehicleName: "Corvette Z06",
            vehicleImageName: "car_chevrolet_corvette",
            speedUnit: "MPH",
            useMilesPerHour: true
        )

        let state = DashCastTelemetryAttributes.ContentState(
            currentSpeed: 75.4,
            currentSpeedKmh: 121.3,
            topSpeed: 88.0,
            distanceFormatted: "14.20 mi",
            distanceMeters: 22852.6,
            elapsedTime: 720,
            elapsedDurationFormatted: "12:00",
            currentGForce: 0.32,
            peakGForce: 0.54,
            smoothnessScore: 94,
            isPaused: false,
            isParked: false,
            teaserMode: false
        )

        let encoder = JSONEncoder()
        let encodedState = try encoder.encode(state)
        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(DashCastTelemetryAttributes.ContentState.self, from: encodedState)

        XCTAssertEqual(decodedState.currentSpeed, 75.4, accuracy: 0.01)
        XCTAssertEqual(decodedState.distanceFormatted, "14.20 mi")
        XCTAssertEqual(decodedState.currentGForce, 0.32, accuracy: 0.01)
        XCTAssertEqual(decodedState.peakGForce, 0.54, accuracy: 0.01)
        XCTAssertEqual(decodedState.smoothnessScore, 94)
        XCTAssertEqual(attributes.vehicleName, "Corvette Z06")
        XCTAssertEqual(attributes.speedUnit, "MPH")
    }

    // MARK: - Formatting & Metric Helpers

    func testContentStateFormatting() {
        let state = DashCastTelemetryAttributes.ContentState(
            currentSpeed: 64.8,
            currentSpeedKmh: 64.8,
            topSpeed: 104.2,
            distanceFormatted: "5.40 km",
            distanceMeters: 5400,
            elapsedTime: 365,
            elapsedDurationFormatted: "06:05",
            currentGForce: 0.28,
            peakGForce: 0.45,
            smoothnessScore: 92
        )

        XCTAssertEqual(state.speedFormatted, "65")
        XCTAssertEqual(state.topSpeedFormatted, "104")
        XCTAssertEqual(state.gForceFormatted, "0.28 G")
        XCTAssertEqual(state.peakGForceFormatted, "0.45 G")
        XCTAssertEqual(state.scoreRatingLabel, "Smooth Driver")
        XCTAssertEqual(state.gForceIntensity, 0.28 / 0.8, accuracy: 0.01)

        // Test Spirited & Aggressive score labels
        let spiritedState = DashCastTelemetryAttributes.ContentState(
            currentSpeed: 50, currentSpeedKmh: 50, topSpeed: 50,
            distanceFormatted: "1 km", distanceMeters: 1000,
            elapsedTime: 60, elapsedDurationFormatted: "01:00",
            currentGForce: 0.50, peakGForce: 0.50, smoothnessScore: 65
        )
        XCTAssertEqual(spiritedState.scoreRatingLabel, "Spirited")

        let aggressiveState = DashCastTelemetryAttributes.ContentState(
            currentSpeed: 90, currentSpeedKmh: 90, topSpeed: 90,
            distanceFormatted: "1 km", distanceMeters: 1000,
            elapsedTime: 60, elapsedDurationFormatted: "01:00",
            currentGForce: 0.80, peakGForce: 0.80, smoothnessScore: 40
        )
        XCTAssertEqual(aggressiveState.scoreRatingLabel, "Aggressive")
    }

    // MARK: - Manager Lifecycle

    @MainActor
    func testLiveActivityManagerStartAndEnd() {
        let manager = DriveLiveActivityManager.shared
        XCTAssertFalse(manager.isLiveActivityActive)

        manager.startLiveActivity(
            vehicleName: "Cyberpunk GT",
            speedUnit: "KM/H",
            useMilesPerHour: false,
            initialSpeed: 0.0
        )

        XCTAssertTrue(manager.isLiveActivityActive)
        XCTAssertNotNil(manager.latestState)
        XCTAssertEqual(manager.latestAttributes?.vehicleName, "Cyberpunk GT")
        XCTAssertEqual(manager.latestState?.currentSpeed, 0.0)

        manager.endLiveActivity(dismissImmediately: true)
        XCTAssertFalse(manager.isLiveActivityActive)
    }

    // MARK: - Telemetry Updates

    @MainActor
    func testLiveActivityManagerTelemetryUpdate() {
        let manager = DriveLiveActivityManager.shared
        manager.startLiveActivity(
            vehicleName: "Cyberpunk GT",
            speedUnit: "KM/H",
            useMilesPerHour: false
        )

        manager.updateLiveActivity(
            speedKmh: 82.0,
            distanceMeters: 3500.0,
            elapsedTime: 240.0,
            currentGForce: 0.22,
            peakGForce: 0.38,
            smoothnessScore: 96,
            isPaused: false,
            useMilesPerHour: false,
            forceUpdate: true
        )

        XCTAssertEqual(manager.latestState?.currentSpeed, 82.0)
        XCTAssertEqual(manager.latestState?.distanceFormatted, "3.50 km")
        XCTAssertEqual(manager.latestState?.elapsedDurationFormatted, "04:00")
        XCTAssertEqual(manager.latestState?.currentGForce, 0.22, accuracy: 0.01)
        XCTAssertEqual(manager.latestState?.peakGForce, 0.38, accuracy: 0.01)
        XCTAssertEqual(manager.latestState?.smoothnessScore, 96)
        XCTAssertFalse(manager.latestState?.isPaused ?? true)
    }

    // MARK: - Teaser Mode

    @MainActor
    func testTeaserModeActivation() {
        let manager = DriveLiveActivityManager.shared
        manager.startTeaserLiveActivity()

        XCTAssertTrue(manager.isLiveActivityActive)
        XCTAssertTrue(manager.latestState?.teaserMode ?? false)
    }

    // MARK: - Integration with DriveLocationService

    @MainActor
    func testLocationServiceTelemetryStreaming() {
        let service = DriveLocationService.shared
        service.startTrip()

        XCTAssertTrue(service.isTracking)
        XCTAssertTrue(DriveLiveActivityManager.shared.isLiveActivityActive)

        // Inject simulated telemetry point
        service.simulatePoint(latitude: 37.7749, longitude: -122.4194, speedKmh: 74.0, altitude: 25.0)

        let latestState = DriveLiveActivityManager.shared.latestState
        XCTAssertNotNil(latestState)
        XCTAssertEqual(latestState?.currentSpeedKmh, 74.0)

        // Pause
        service.pauseTrip()
        XCTAssertTrue(DriveLiveActivityManager.shared.latestState?.isPaused ?? false)

        // Resume
        service.resumeTrip()
        XCTAssertFalse(DriveLiveActivityManager.shared.latestState?.isPaused ?? true)

        // End
        _ = service.endTrip()
        XCTAssertFalse(DriveLiveActivityManager.shared.isLiveActivityActive)
    }

    // MARK: - DrivingScorer G-Force Tracking

    @MainActor
    func testDrivingScorerGForceTracking() {
        let scorer = DrivingScorer.shared
        scorer.reset()
        XCTAssertEqual(scorer.currentGForce, 0.0)
        XCTAssertEqual(scorer.peakGForce, 0.0)

        scorer.simulateGForce(current: 0.35)
        XCTAssertEqual(scorer.currentGForce, 0.35, accuracy: 0.01)
        XCTAssertEqual(scorer.peakGForce, 0.35, accuracy: 0.01)

        scorer.simulateGForce(current: 0.15)
        XCTAssertEqual(scorer.currentGForce, 0.15, accuracy: 0.01)
        XCTAssertEqual(scorer.peakGForce, 0.35, accuracy: 0.01) // peak preserved

        scorer.reset()
        XCTAssertEqual(scorer.currentGForce, 0.0)
        XCTAssertEqual(scorer.peakGForce, 0.0)
    }

    // MARK: - UserPreferences Live Activities Setting

    func testUserPreferencesLiveActivitiesSetting() {
        var prefs = UserPreferences()
        XCTAssertTrue(prefs.liveActivitiesEnabled)

        prefs.liveActivitiesEnabled = false
        XCTAssertFalse(prefs.liveActivitiesEnabled)
    }
}
