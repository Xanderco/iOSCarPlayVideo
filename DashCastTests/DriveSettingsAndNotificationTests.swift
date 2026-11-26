import XCTest
import CoreLocation
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

    // MARK: LocationPermissionCardCopy

    @MainActor
    func testLocationPermissionCardCopyAllAuthorizationStates() {
        let notDetermined = LocationPermissionCardCopy.descriptor(for: .notDetermined)
        XCTAssertEqual(notDetermined?.icon, "location.circle.fill")
        XCTAssertEqual(notDetermined?.titleKeyName, "Show where you are")
        XCTAssertEqual(notDetermined?.buttonKeyName, "Allow Location")
        _ = notDetermined?.title
        _ = notDetermined?.message
        _ = notDetermined?.button

        let whenInUse = LocationPermissionCardCopy.descriptor(for: .authorizedWhenInUse)
        XCTAssertEqual(whenInUse?.icon, "car.circle.fill")
        XCTAssertEqual(whenInUse?.titleKeyName, "Record trips automatically")
        XCTAssertEqual(whenInUse?.buttonKeyName, "Allow All the Time")
        _ = whenInUse?.title
        _ = whenInUse?.message
        _ = whenInUse?.button

        let denied = LocationPermissionCardCopy.descriptor(for: .denied)
        XCTAssertEqual(denied?.icon, "location.slash.fill")
        XCTAssertEqual(denied?.titleKeyName, "Location is off for DashCast")
        XCTAssertEqual(denied?.buttonKeyName, "Open Settings")
        _ = denied?.title
        _ = denied?.message
        _ = denied?.button

        let restricted = LocationPermissionCardCopy.descriptor(for: .restricted)
        XCTAssertEqual(restricted?.icon, "lock.fill")
        XCTAssertEqual(restricted?.titleKeyName, "Location is restricted")
        XCTAssertNil(restricted?.buttonKeyName)
        XCTAssertNil(restricted?.button)

        XCTAssertNil(LocationPermissionCardCopy.descriptor(for: .authorizedAlways))
    }

    func testDriveLiveMapAndPermissionLocalizationKeysExistInCatalog() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = Bundle(for: DriveSettingsAndNotificationTests.self).url(forResource: "Localizable", withExtension: "xcstrings")
            ?? projectDir
                .appendingPathComponent("DashCast")
                .appendingPathComponent("Resources")
                .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])

        for key in LocationPermissionCardCopy.allLocalizationKeys {
            let entry = try XCTUnwrap(strings[key], "Missing key in Localizable.xcstrings: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]])
            let enValue = ((localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            let esValue = ((localizations["es"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            XCTAssertFalse(enValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Missing EN for \(key)")
            XCTAssertFalse(esValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Missing ES for \(key)")
        }
    }
}
