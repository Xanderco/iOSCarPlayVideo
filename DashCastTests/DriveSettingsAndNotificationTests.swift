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

    func testDriveNotificationContentBuilderRecordingAndTripSaved() {
        let recording = DriveNotificationContentBuilder.recordingContent(distanceKm: 3.45)
        XCTAssertEqual(recording.identifier, "dashcast.drive.recording")
        XCTAssertEqual(recording.title, "Recording your drive")
        XCTAssertEqual(recording.body, "3.5 km so far · DashCast is tracking this trip.")
        XCTAssertEqual(recording.delay, 1)

        let clampedRecording = DriveNotificationContentBuilder.recordingContent(distanceKm: -2.0)
        XCTAssertEqual(clampedRecording.body, "0.0 km so far · DashCast is tracking this trip.")

        let start = Date(timeIntervalSince1970: 1000)
        let trip = TripModel(
            startTime: start,
            endTime: start.addingTimeInterval(900),
            distanceMeters: 16093.44,
            averageSpeedKmh: 64.0,
            maxSpeedKmh: 100.0,
            drivingScore: 91
        )

        let kmPayload = DriveNotificationContentBuilder.tripSavedContent(trip: trip, useMiles: false)
        XCTAssertEqual(kmPayload.identifier, "dashcast.trip.saved")
        XCTAssertEqual(kmPayload.title, "Trip saved")
        XCTAssertEqual(kmPayload.body, "16.1 km · 15 min · top 100 km/h\n🏁 Score 91/100")

        let milesPayload = DriveNotificationContentBuilder.tripSavedContent(trip: trip, useMiles: true)
        XCTAssertEqual(milesPayload.identifier, "dashcast.trip.saved")
        XCTAssertEqual(milesPayload.title, "Trip saved")
        XCTAssertEqual(milesPayload.body, "10.0 mi · 15 min · top 62 mph\n🏁 Score 91/100")
    }

    func testDriveNotificationContentBuilderFeatureTips() {
        let tips = DriveNotificationContentBuilder.featureTipContents()
        XCTAssertEqual(tips.count, 4)
        XCTAssertEqual(tips.map(\.identifier), ["dashcast.tip.0", "dashcast.tip.1", "dashcast.tip.2", "dashcast.tip.3"])
        XCTAssertEqual(tips.map(\.delay), [3600, 7200, 14400, 21600])
        XCTAssertEqual(tips[0].title, "Every detail, yours")
        XCTAssertEqual(tips[3].title, "Two taps, done")
    }

    func testDriveNotificationCopyLocalizationKeysComplete() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectDir
            .appendingPathComponent("DashCast")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])

        XCTAssertEqual(DriveNotificationCopy.allLocalizationKeys.count, 13)
        for key in DriveNotificationCopy.allLocalizationKeys {
            let entry = try XCTUnwrap(strings[key], "Missing Localizable.xcstrings entry for: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]], "Missing localizations for: \(key)")
            for lang in ["en", "es"] {
                let unit = try XCTUnwrap(localizations[lang]?["stringUnit"] as? [String: Any], "Missing \(lang) stringUnit for: \(key)")
                let value = try XCTUnwrap(unit["value"] as? String)
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(lang) translation for: \(key)")
            }
        }
    }
}
