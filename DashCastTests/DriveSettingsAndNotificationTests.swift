import XCTest
import UserNotifications
@testable import DashCast

private final class MockNotificationScheduler: NotificationRequestScheduling {
    var authorizationResult = true
    var status: UNAuthorizationStatus = .authorized
    private(set) var addedRequests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationResult
    }

    func notificationStatus() async -> UNAuthorizationStatus {
        status
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        addedRequests.append(request)
        completionHandler?(nil)
    }
}

final class DriveSettingsAndNotificationTests: XCTestCase {
    func testUserPreferencesDriveDefaults() {
        let prefs = UserPreferences()
        XCTAssertTrue(prefs.autoDetectDrives)
        XCTAssertEqual(prefs.minimumDriveMeters, 50.0)
        XCTAssertTrue(prefs.driveNotificationsEnabled)
        XCTAssertEqual(prefs.driveCountry, "Colombia")
        XCTAssertEqual(prefs.driveVehicleName, "Chevrolet Trax")
    }

    func testUserPreferencesCustomEncodingAndDecoding() {
        var prefs = UserPreferences()
        prefs.autoDetectDrives = false
        prefs.minimumDriveMeters = 250.0
        prefs.driveCountry = "United States"
        prefs.driveVehicleName = "Porsche 911 GT3 RS"
        prefs.driveVehicleImage = "car_porsche_911"
        prefs.useMilesPerHour = true

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(prefs) else {
            XCTFail("Failed to encode UserPreferences")
            return
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(UserPreferences.self, from: data) else {
            XCTFail("Failed to decode UserPreferences")
            return
        }

        XCTAssertFalse(decoded.autoDetectDrives)
        XCTAssertEqual(decoded.minimumDriveMeters, 250.0)
        XCTAssertEqual(decoded.driveCountry, "United States")
        XCTAssertEqual(decoded.driveVehicleName, "Porsche 911 GT3 RS")
        XCTAssertEqual(decoded.driveVehicleImage, "car_porsche_911")
        XCTAssertTrue(decoded.useMilesPerHour)
    }

    func testTripSavedNotificationGeneration() {
        let scheduler = MockNotificationScheduler()
        let service = DriveNotificationService(scheduler: scheduler)
        let trip = TripModel(
            distanceMeters: 4800,
            averageSpeedKmh: 35.0,
            maxSpeedKmh: 47.0,
            drivingScore: 92
        )

        service.sendTripSavedNotification(trip: trip)
        service.sendTripSavedNotification(trip: trip, useMiles: true)
        service.sendDriveRecordingNotification(distanceKm: 0.1)
        service.scheduleFeatureTips()

        XCTAssertEqual(scheduler.addedRequests.count, 7)

        let metricTripRequest = scheduler.addedRequests[0]
        XCTAssertEqual(metricTripRequest.identifier, "dashcast.trip.saved")
        XCTAssertEqual(metricTripRequest.content.title, "Trip saved")
        XCTAssertTrue(metricTripRequest.content.body.contains("4.8 km"))
        XCTAssertTrue(metricTripRequest.content.body.contains("Score 92/100"))

        let imperialTripRequest = scheduler.addedRequests[1]
        XCTAssertEqual(imperialTripRequest.identifier, "dashcast.trip.saved")
        XCTAssertTrue(imperialTripRequest.content.body.contains("mi"))
        XCTAssertTrue(imperialTripRequest.content.body.contains("mph"))

        let recordingRequest = scheduler.addedRequests[2]
        XCTAssertEqual(recordingRequest.identifier, "dashcast.drive.recording")
        XCTAssertEqual(recordingRequest.content.title, "Recording your drive")
        XCTAssertTrue(recordingRequest.content.body.contains("0.1 km so far"))

        let tipRequests = Array(scheduler.addedRequests.dropFirst(3))
        XCTAssertEqual(tipRequests.map(\.identifier), ["dashcast.tip.0", "dashcast.tip.1", "dashcast.tip.2", "dashcast.tip.3"])
        let delays = tipRequests.compactMap { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval }
        XCTAssertEqual(delays, [3600, 7200, 14400, 21600])
    }
}
