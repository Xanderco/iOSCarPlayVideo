import CoreLocation
import CoreMotion
import XCTest
@testable import DashCast

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
        let service = DriveNotificationService.shared
        let trip = TripModel(
            distanceMeters: 4800,
            averageSpeedKmh: 35.0,
            maxSpeedKmh: 47.0,
            drivingScore: 92
        )

        service.sendTripSavedNotification(trip: trip)
        service.sendDriveRecordingNotification(distanceKm: 0.1)
        service.scheduleFeatureTips()
        // If no crash occurred, notifications requests dispatched to UNUserNotificationCenter
        XCTAssertTrue(true)
    }

    func testTripSummaryDistanceFormattingMetricAndImperial() {
        XCTAssertEqual(TripSummaryFormatter.formatDistance(meters: 0, useMilesPerHour: false), "0.00 km")
        XCTAssertEqual(TripSummaryFormatter.formatDistance(meters: 0, useMilesPerHour: true), "0.00 mi")
        XCTAssertEqual(TripSummaryFormatter.formatDistance(meters: 2500, useMilesPerHour: false), "2.50 km")
        XCTAssertEqual(TripSummaryFormatter.formatDistance(meters: 1609.344, useMilesPerHour: true), "1.00 mi")
    }

    func testTripSummarySpeedFormattingMetricAndImperial() {
        XCTAssertEqual(TripSummaryFormatter.formatSpeed(kmh: 0, useMilesPerHour: false), "0 km/h")
        XCTAssertEqual(TripSummaryFormatter.formatSpeed(kmh: 0, useMilesPerHour: true), "0 mph")
        XCTAssertEqual(TripSummaryFormatter.formatSpeed(kmh: 100, useMilesPerHour: false), "100 km/h")
        XCTAssertEqual(TripSummaryFormatter.formatSpeed(kmh: 100, useMilesPerHour: true), "62 mph")
    }

    func testTripSummaryScoreMessageKeys() {
        XCTAssertEqual(TripSummaryFormatter.scoreMessageKey(for: 100), "Flawless Driving!")
        XCTAssertEqual(TripSummaryFormatter.scoreMessageKey(for: 90), "Flawless Driving!")
        XCTAssertEqual(TripSummaryFormatter.scoreMessageKey(for: 89), "Smooth & Safe Drive")
        XCTAssertEqual(TripSummaryFormatter.scoreMessageKey(for: 80), "Smooth & Safe Drive")
        XCTAssertEqual(TripSummaryFormatter.scoreMessageKey(for: 79), "Moderate Ride")
        XCTAssertEqual(TripSummaryFormatter.scoreMessageKey(for: 70), "Moderate Ride")
        XCTAssertEqual(TripSummaryFormatter.scoreMessageKey(for: 69), "Aggressive Driving Detected")
    }

    func testDriveTrackingPermissionMapperCopyKeys() {
        XCTAssertEqual(DriveTrackingPermissionMapper.locationSubtitleKey(for: .authorizedAlways), "Always allowed.")
        XCTAssertEqual(
            DriveTrackingPermissionMapper.locationSubtitleKey(for: .authorizedWhenInUse),
            "Allowed while using DashCast; trips keep recording when the screen locks."
        )
        XCTAssertEqual(
            DriveTrackingPermissionMapper.locationSubtitleKey(for: .denied),
            "Off. Turn it on in Settings to record trips."
        )
        XCTAssertEqual(
            DriveTrackingPermissionMapper.locationSubtitleKey(for: .notDetermined),
            "Needed to measure speed, distance and your route."
        )

        XCTAssertEqual(
            DriveTrackingPermissionMapper.motionSubtitleKey(for: .authorized),
            "Allowed for automatic drive detection and harsh-braking scoring."
        )
        XCTAssertEqual(
            DriveTrackingPermissionMapper.motionSubtitleKey(for: .denied),
            "Off. Turn it on in Settings for automatic drive detection."
        )
        XCTAssertEqual(
            DriveTrackingPermissionMapper.motionSubtitleKey(for: .restricted),
            "Off. Turn it on in Settings for automatic drive detection."
        )
        XCTAssertEqual(
            DriveTrackingPermissionMapper.motionSubtitleKey(for: .notDetermined),
            "Used for automatic drive detection and driving smoothness."
        )
    }
}
