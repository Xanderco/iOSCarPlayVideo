import XCTest
@testable import DashCast

final class TripLogTests: XCTestCase {
    func testDistanceFormatting() {
        XCTAssertEqual(TripFormatting.distance(meters: 4800, useMiles: false), "4.8 km")
        XCTAssertEqual(TripFormatting.distance(meters: 1609.344, useMiles: true), "1.0 mi")
    }

    func testSpeedFormatting() {
        XCTAssertEqual(TripFormatting.speed(kmh: 50, useMiles: false), "50 km/h")
        XCTAssertEqual(TripFormatting.speed(kmh: 100, useMiles: true), "62 mph")
    }

    func testDurationFormatting() {
        XCTAssertEqual(TripFormatting.duration(65), "1:05")
        XCTAssertEqual(TripFormatting.duration(3_725), "1:02:05")
        XCTAssertEqual(TripFormatting.duration(-5), "0:00")
    }

    func testTripSavedNotificationBodyHasNoScore() {
        let start = Date(timeIntervalSince1970: 0)
        let trip = TripModel(startTime: start, endTime: start.addingTimeInterval(720), distanceMeters: 4800)
        let body = DriveNotificationService.tripSavedBody(for: trip, useMiles: false)

        XCTAssertEqual(body, "4.8 km · 12 min. Saved to Trip Log on this iPhone.")
        XCTAssertFalse(body.localizedCaseInsensitiveContains("score"))
    }

    func testUserPreferencesDefaultsAndRoundTrip() throws {
        let defaults = UserPreferences()
        XCTAssertFalse(defaults.useMilesPerHour)
        XCTAssertTrue(defaults.driveNotificationsEnabled)
        XCTAssertEqual(defaults.connectionSoundId, SoundCatalogService.defaultSoundId)

        var prefs = UserPreferences()
        prefs.useMilesPerHour = true
        prefs.driveNotificationsEnabled = false
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(prefs))
        XCTAssertTrue(decoded.useMilesPerHour)
        XCTAssertFalse(decoded.driveNotificationsEnabled)
    }

    func testUserPreferencesDecodesLegacyPayload() throws {
        // Older builds stored extra sound slots and vehicle fields; they must be ignored, not fail.
        let legacy = """
        {"useMilesPerHour":true,"connectionSoundId":"retired_id","disconnectionSoundId":"x",
         "homeArrivalSoundId":"y","driveCountry":"Somewhere","driveVehicleName":"Car"}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(legacy.utf8))
        XCTAssertTrue(decoded.useMilesPerHour)
        XCTAssertEqual(decoded.connectionSoundId, "retired_id")
        // Unknown chime ids fall back to the default chime.
        XCTAssertEqual(SoundCatalogService.shared.selectedSound(preferences: decoded).id, SoundCatalogService.defaultSoundId)
    }
}
