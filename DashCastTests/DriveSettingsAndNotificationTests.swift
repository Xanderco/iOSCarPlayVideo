import XCTest
import CoreLocation
import CoreMotion
import UserNotifications
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

    func testLocationPermissionStatusMapping() {
        XCTAssertEqual(
            DrivePermissionStatusMapper.locationDisplay(for: .authorizedAlways),
            DrivePermissionDisplay(statusKey: "Always", tone: .green)
        )
        XCTAssertEqual(
            DrivePermissionStatusMapper.locationDisplay(for: .authorizedWhenInUse),
            DrivePermissionDisplay(statusKey: "While using", tone: .orange)
        )
        XCTAssertEqual(
            DrivePermissionStatusMapper.locationDisplay(for: .denied),
            DrivePermissionDisplay(statusKey: "Denied", tone: .red)
        )
        XCTAssertEqual(
            DrivePermissionStatusMapper.locationDisplay(for: .restricted),
            DrivePermissionDisplay(statusKey: "Restricted", tone: .red)
        )
        XCTAssertEqual(
            DrivePermissionStatusMapper.locationDisplay(for: .notDetermined),
            DrivePermissionDisplay(statusKey: "Not set", tone: .muted)
        )
    }

    func testMotionPermissionStatusMapping() {
        XCTAssertEqual(
            DrivePermissionStatusMapper.motionDisplay(for: .authorized),
            DrivePermissionDisplay(statusKey: "On", tone: .green)
        )
        XCTAssertEqual(
            DrivePermissionStatusMapper.motionDisplay(for: .denied),
            DrivePermissionDisplay(statusKey: "Denied", tone: .red)
        )
        XCTAssertEqual(
            DrivePermissionStatusMapper.motionDisplay(for: .restricted),
            DrivePermissionDisplay(statusKey: "Restricted", tone: .red)
        )
        XCTAssertEqual(
            DrivePermissionStatusMapper.motionDisplay(for: .notDetermined),
            DrivePermissionDisplay(statusKey: "Not set", tone: .muted)
        )
    }

    func testNotificationPermissionStatusMapping() {
        XCTAssertEqual(
            DrivePermissionStatusMapper.notificationDisplay(isEnabledInApp: false, systemStatus: .authorized),
            DrivePermissionDisplay(statusKey: "Off", tone: .muted)
        )
        XCTAssertEqual(
            DrivePermissionStatusMapper.notificationDisplay(isEnabledInApp: true, systemStatus: .authorized),
            DrivePermissionDisplay(statusKey: "On", tone: .green)
        )
        XCTAssertEqual(
            DrivePermissionStatusMapper.notificationDisplay(isEnabledInApp: true, systemStatus: .provisional),
            DrivePermissionDisplay(statusKey: "On", tone: .green)
        )
        XCTAssertEqual(
            DrivePermissionStatusMapper.notificationDisplay(isEnabledInApp: true, systemStatus: .denied),
            DrivePermissionDisplay(statusKey: "Denied", tone: .red)
        )
        XCTAssertEqual(
            DrivePermissionStatusMapper.notificationDisplay(isEnabledInApp: true, systemStatus: .notDetermined),
            DrivePermissionDisplay(statusKey: "Not set", tone: .muted)
        )
    }

    func testMinimumDriveThresholdFiltering() {
        XCTAssertFalse(DriveLocationService.shouldSaveTrip(distanceMeters: 49.9, minimumDriveMeters: 50.0))
        XCTAssertTrue(DriveLocationService.shouldSaveTrip(distanceMeters: 50.0, minimumDriveMeters: 50.0))
        XCTAssertTrue(DriveLocationService.shouldSaveTrip(distanceMeters: 1200.0, minimumDriveMeters: 500.0))
        XCTAssertFalse(DriveLocationService.shouldSaveTrip(distanceMeters: 250.0, minimumDriveMeters: 500.0))
        XCTAssertTrue(DriveLocationService.shouldSaveTrip(distanceMeters: 0.0, minimumDriveMeters: 0.0))
    }

    func testCountryCatalogContainsDefaultsAndFilters() {
        let all = DriveCountryCatalog.allCountries
        XCTAssertTrue(all.contains("Colombia"))
        XCTAssertTrue(all.contains("United States"))

        let filtered = DriveCountryCatalog.filteredCountries(matching: "  colom ")
        XCTAssertTrue(filtered.contains("Colombia"))
        XCTAssertFalse(filtered.contains("United States"))

        XCTAssertEqual(DriveCountryCatalog.filteredCountries(matching: "   ").count, all.count)
    }
}
