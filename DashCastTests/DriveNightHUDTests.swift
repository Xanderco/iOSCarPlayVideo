import XCTest
@testable import DashCast

final class DriveNightHUDTests: XCTestCase {

    @MainActor
    func testNightHUDServiceDefaults() {
        let service = DriveNightHUDService(userDefaults: UserDefaults(suiteName: "TestHUDDefaults")!)
        service.resetToDefaults()

        XCTAssertFalse(service.isHUDActive)
        XCTAssertFalse(service.isWindshieldMirrored)
        XCTAssertTrue(service.isAmbientWarningAuraEnabled)
        XCTAssertEqual(service.speedLimitKmh, 100.0)
        XCTAssertEqual(service.speedLimitWarningOffsetKmh, 8.0)
        XCTAssertEqual(service.selectedTheme, .pureOLED)
        XCTAssertFalse(service.autoLaunchAtNight)
    }

    @MainActor
    func testSpeedLimitWarningCalculation() {
        let service = DriveNightHUDService(userDefaults: UserDefaults(suiteName: "TestHUDWarning")!)
        service.resetToDefaults()
        service.setSpeedLimitKmh(100.0)

        // At or below speed limit -> normal
        XCTAssertEqual(service.warningStatus(currentSpeedKmh: 0.0), .normal)
        XCTAssertEqual(service.warningStatus(currentSpeedKmh: 60.0), .normal)
        XCTAssertEqual(service.warningStatus(currentSpeedKmh: 100.0), .normal)

        // Within warning offset (100.0 < speed <= 108.0) -> caution
        XCTAssertEqual(service.warningStatus(currentSpeedKmh: 101.0), .caution)
        XCTAssertEqual(service.warningStatus(currentSpeedKmh: 105.0), .caution)
        XCTAssertEqual(service.warningStatus(currentSpeedKmh: 108.0), .caution)

        // Above limit + offset (> 108.0) -> critical
        XCTAssertEqual(service.warningStatus(currentSpeedKmh: 108.1), .critical)
        XCTAssertEqual(service.warningStatus(currentSpeedKmh: 125.0), .critical)
        XCTAssertEqual(service.warningStatus(currentSpeedKmh: 180.0), .critical)
    }

    @MainActor
    func testSpeedLimitWarningDisabled() {
        let service = DriveNightHUDService(userDefaults: UserDefaults(suiteName: "TestHUDAuraDisabled")!)
        service.resetToDefaults()
        service.isAmbientWarningAuraEnabled = false

        // When warning aura is disabled, always returns .normal
        XCTAssertEqual(service.warningStatus(currentSpeedKmh: 150.0), .normal)
        XCTAssertEqual(service.warningStatus(currentSpeedKmh: 200.0), .normal)
    }

    @MainActor
    func testCardinalHeadingCalculation() {
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: 0.0), "N")
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: 15.0), "N")
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: 45.0), "NE")
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: 90.0), "E")
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: 135.0), "SE")
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: 180.0), "S")
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: 225.0), "SW")
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: 270.0), "W")
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: 315.0), "NW")
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: 355.0), "N")
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: 360.0), "N")

        // Invalid courses (e.g. negative when no GPS fix)
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: -1.0), "--")
        XCTAssertEqual(DriveNightHUDService.cardinalHeading(from: 400.0), "--")
    }

    @MainActor
    func testWindshieldMirrorToggle() {
        let service = DriveNightHUDService(userDefaults: UserDefaults(suiteName: "TestHUDMirror")!)
        service.resetToDefaults()
        XCTAssertFalse(service.isWindshieldMirrored)

        service.toggleWindshieldMirror()
        XCTAssertTrue(service.isWindshieldMirrored)

        service.toggleWindshieldMirror()
        XCTAssertFalse(service.isWindshieldMirrored)
    }

    @MainActor
    func testSpeedLimitClampingAndAdjustment() {
        let service = DriveNightHUDService(userDefaults: UserDefaults(suiteName: "TestHUDClamping")!)
        service.resetToDefaults()

        service.setSpeedLimitKmh(120.0)
        XCTAssertEqual(service.speedLimitKmh, 120.0)

        // Lower clamp bound (20 km/h)
        service.setSpeedLimitKmh(5.0)
        XCTAssertEqual(service.speedLimitKmh, 20.0)

        // Upper clamp bound (250 km/h)
        service.setSpeedLimitKmh(300.0)
        XCTAssertEqual(service.speedLimitKmh, 250.0)

        // Delta adjustments
        service.setSpeedLimitKmh(100.0)
        service.adjustSpeedLimit(deltaKmh: 10.0)
        XCTAssertEqual(service.speedLimitKmh, 110.0)

        service.adjustSpeedLimit(deltaKmh: -20.0)
        XCTAssertEqual(service.speedLimitKmh, 90.0)
    }

    @MainActor
    func testSpeedLimitMphConversion() {
        let service = DriveNightHUDService(userDefaults: UserDefaults(suiteName: "TestHUDMph")!)
        service.resetToDefaults()

        service.setSpeedLimitMph(65.0)
        XCTAssertEqual(service.speedLimitMph, 65.0, accuracy: 0.1)
        XCTAssertEqual(service.speedLimitKmh, 104.6, accuracy: 0.5)
    }

    @MainActor
    func testNightHUDThemes() {
        let service = DriveNightHUDService(userDefaults: UserDefaults(suiteName: "TestHUDThemes")!)
        service.resetToDefaults()

        service.setTheme(.tacticalCrimson)
        XCTAssertEqual(service.selectedTheme, .tacticalCrimson)
        XCTAssertEqual(service.selectedTheme.displayName, "Tactical Crimson")

        service.setTheme(.emeraldGlow)
        XCTAssertEqual(service.selectedTheme, .emeraldGlow)
        XCTAssertEqual(service.selectedTheme.displayName, "Emerald Phosphor")

        service.setTheme(.pureOLED)
        XCTAssertEqual(service.selectedTheme, .pureOLED)
        XCTAssertEqual(service.selectedTheme.displayName, "OLED Amber")
    }

    @MainActor
    func testSpeedWarningAuraIntensity() {
        XCTAssertEqual(SpeedWarningStatus.normal.auraIntensity, 0.0)
        XCTAssertEqual(SpeedWarningStatus.caution.auraIntensity, 0.55)
        XCTAssertEqual(SpeedWarningStatus.critical.auraIntensity, 0.95)
    }

    @MainActor
    func testUserPreferencesPersistenceRoundtrip() throws {
        var prefs = UserPreferences()
        prefs.nightHUDWindshieldMirrored = true
        prefs.nightHUDAmbientAuraEnabled = true
        prefs.nightHUDSpeedLimitKmh = 115.0
        prefs.nightHUDThemeRawValue = "tacticalCrimson"

        let encoder = JSONEncoder()
        let data = try encoder.encode(prefs)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserPreferences.self, from: data)

        XCTAssertTrue(decoded.nightHUDWindshieldMirrored)
        XCTAssertTrue(decoded.nightHUDAmbientAuraEnabled)
        XCTAssertEqual(decoded.nightHUDSpeedLimitKmh, 115.0)
        XCTAssertEqual(decoded.nightHUDThemeRawValue, "tacticalCrimson")
    }
}
