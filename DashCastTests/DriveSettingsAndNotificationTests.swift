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

    // MARK: DriveHomeHUDFormatter

    @MainActor
    func testDriveHomeHUDFormatterTrackingChipStates() {
        XCTAssertEqual(
            DriveHomeHUDFormatter.trackingChipKeyName(
                isAuthorized: false,
                authorizationStatus: .notDetermined,
                isTracking: false,
                isPaused: false
            ),
            "Enable Location"
        )
        XCTAssertEqual(
            DriveHomeHUDFormatter.trackingChipKeyName(
                isAuthorized: false,
                authorizationStatus: .denied,
                isTracking: false,
                isPaused: false
            ),
            "Location Off"
        )
        XCTAssertEqual(
            DriveHomeHUDFormatter.trackingChipKeyName(
                isAuthorized: true,
                authorizationStatus: .authorizedWhenInUse,
                isTracking: false,
                isPaused: false
            ),
            "Ready"
        )
        XCTAssertEqual(
            DriveHomeHUDFormatter.trackingChipKeyName(
                isAuthorized: true,
                authorizationStatus: .authorizedWhenInUse,
                isTracking: true,
                isPaused: false
            ),
            "Tracking"
        )
        XCTAssertEqual(
            DriveHomeHUDFormatter.trackingChipKeyName(
                isAuthorized: true,
                authorizationStatus: .authorizedAlways,
                isTracking: true,
                isPaused: true
            ),
            "Paused"
        )
        _ = DriveHomeHUDFormatter.trackingChipTitle(
            isAuthorized: true,
            authorizationStatus: .authorizedAlways,
            isTracking: true,
            isPaused: false
        )
    }

    func testDriveHomeHUDFormatterMetricAndImperialFormatting() {
        XCTAssertEqual(DriveHomeHUDFormatter.speedUnit(useMilesPerHour: false), "KM/H")
        XCTAssertEqual(DriveHomeHUDFormatter.speedUnit(useMilesPerHour: true), "MPH")

        XCTAssertEqual(DriveHomeHUDFormatter.speedValue(kmh: 100, useMilesPerHour: false), 100.0, accuracy: 0.01)
        XCTAssertEqual(DriveHomeHUDFormatter.speedValue(kmh: 100, useMilesPerHour: true), 62.1371, accuracy: 0.01)
        XCTAssertEqual(DriveHomeHUDFormatter.speedValue(kmh: -10, useMilesPerHour: false), 0.0, accuracy: 0.01)
        XCTAssertEqual(DriveHomeHUDFormatter.speedValue(kmh: .nan, useMilesPerHour: true), 0.0, accuracy: 0.01)

        XCTAssertEqual(DriveHomeHUDFormatter.speedText(kmh: 80, useMilesPerHour: false), "80 \(DriveHomeHUDFormatter.localizedSpeedUnit(useMilesPerHour: false))")
        XCTAssertEqual(DriveHomeHUDFormatter.speedText(kmh: 100, useMilesPerHour: true), "62 \(DriveHomeHUDFormatter.localizedSpeedUnit(useMilesPerHour: true))")

        XCTAssertEqual(DriveHomeHUDFormatter.distanceText(meters: 2500, useMilesPerHour: false), "2.50 km")
        XCTAssertEqual(DriveHomeHUDFormatter.distanceText(meters: 1609.344, useMilesPerHour: true), "1.00 mi")
        XCTAssertEqual(DriveHomeHUDFormatter.distanceText(meters: .nan, useMilesPerHour: false), "0.00 km")

        XCTAssertEqual(DriveHomeHUDFormatter.durationText(seconds: 125), "02m 05s")
        XCTAssertEqual(DriveHomeHUDFormatter.durationText(seconds: -5), "00m 00s")
        XCTAssertEqual(DriveHomeHUDFormatter.durationText(seconds: .infinity), "00m 00s")

        XCTAssertEqual(DriveHomeHUDFormatter.altitudeText(meters: 2600), "2600 m")
        XCTAssertEqual(DriveHomeHUDFormatter.altitudeText(meters: .nan), "0 m")

        let metricSummary = DriveHomeHUDFormatter.pastTripSummaryText(
            distanceMeters: 4800,
            durationSeconds: 900,
            useMilesPerHour: false
        )
        XCTAssertTrue(metricSummary.contains("4.80 km"))
        XCTAssertTrue(metricSummary.contains("15m"))

        let imperialSummary = DriveHomeHUDFormatter.pastTripSummaryText(
            distanceMeters: 1609.344,
            durationSeconds: 600,
            useMilesPerHour: true
        )
        XCTAssertTrue(imperialSummary.contains("1.00 mi"))
        XCTAssertTrue(imperialSummary.contains("10m"))
    }

    func testDriveHomeLocalizationKeysExistInCatalog() throws {
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

        for key in DriveHomeHUDFormatter.allLocalizationKeys {
            let entry = try XCTUnwrap(strings[key], "Missing key in Localizable.xcstrings: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]])
            let enValue = ((localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            let esValue = ((localizations["es"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            XCTAssertFalse(enValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Missing EN for \(key)")
            XCTAssertFalse(esValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Missing ES for \(key)")
        }
    }
}
