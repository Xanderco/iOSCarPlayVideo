import XCTest
import CoreLocation
@testable import DashCast

final class EndToEndFlowTests: XCTestCase {
    var testDefaults: UserDefaults!
    var persistence: PersistenceController!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "EndToEndTestsDefaults")
        testDefaults.removePersistentDomain(forName: "EndToEndTestsDefaults")
        persistence = PersistenceController(userDefaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "EndToEndTestsDefaults")
        super.tearDown()
    }

    @MainActor
    func testCompleteUserLifecycle() {
        // Step 1: Initial Launch
        let appState = AppState(isProLifetimeUnlocked: false)
        XCTAssertFalse(appState.isProLifetimeUnlocked)
        XCTAssertEqual(appState.selectedTab, .cast)

        // Step 2: Trigger and Unlock Lifetime Pro Pass (Pay Once, Own Forever)
        appState.showPaywall = true
        XCTAssertTrue(appState.showPaywall)
        appState.unlockProLifetime()
        XCTAssertTrue(appState.isProLifetimeUnlocked)
        XCTAssertFalse(appState.showPaywall)

        // Step 3: Start Drive, Simulate Route, Record Smooth Driving
        let locationService = DriveLocationService.shared
        let drivingScorer = DrivingScorer.shared
        drivingScorer.reset()

        locationService.startTrip()
        XCTAssertTrue(locationService.isTracking)

        // Simulate 4 GPS waypoint coordinates along a city street
        let waypoints: [(Double, Double, Double, Double)] = [
            (40.7580, -73.9855, 25.0, 15.0),
            (40.7595, -73.9840, 48.0, 16.0),
            (40.7610, -73.9825, 52.0, 17.0),
            (40.7625, -73.9810, 30.0, 16.0)
        ]

        for wp in waypoints {
            locationService.simulatePoint(latitude: wp.0, longitude: wp.1, speedKmh: wp.2, altitude: wp.3)
        }

        // Simulate 1 harsh braking event
        drivingScorer.recordHarshEvent(.braking) // -4 pts
        XCTAssertEqual(drivingScorer.calculateScore(), 96)

        // End Trip
        let completedTrip = locationService.endTrip()
        XCTAssertFalse(locationService.isTracking)
        XCTAssertEqual(completedTrip.drivingScore, 96)
        XCTAssertEqual(completedTrip.points.count, 4)

        // Step 4: Configure Custom CarPlay Widget
        let customWidget = WidgetConfigModel(
            carBrand: "Ford",
            carModelName: "Mustang Dark Horse",
            driverGreeting: "Track Mode",
            showWatermark: true,
            stickerId: "racing_flag"
        )
        persistence.saveWidgets([customWidget])
        let loadedWidgets = persistence.loadWidgets()
        XCTAssertEqual(loadedWidgets.count, 1)
        XCTAssertEqual(loadedWidgets.first?.driverGreeting, "Track Mode")

        // Step 5: Configure Siri Shortcuts Automotive Sound Trigger
        let prefs = UserPreferences(
            useMilesPerHour: true,
            isProLifetimeUnlocked: true,
            connectionSoundId: "sport_startup",
            disconnectionSoundId: "luxury_chime",
            homeArrivalSoundId: "welcome_traveler"
        )
        XCTAssertEqual(prefs.connectionSoundId, "sport_startup")
        XCTAssertEqual(prefs.disconnectionSoundId, "luxury_chime")
    }
}
