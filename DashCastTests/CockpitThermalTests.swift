import XCTest
@testable import DashCast

final class CockpitThermalTests: XCTestCase {
    private var sut: CockpitThermalService!

    @MainActor
    override func setUp() {
        super.setUp()
        sut = CockpitThermalService()
        sut.resetDefaults()
    }

    @MainActor
    override func tearDown() {
        sut.resetDefaults()
        sut = nil
        super.tearDown()
    }

    // MARK: - Unit Tests

    @MainActor
    func testInitialNominalState() {
        sut.simulateThermalState(.nominal)
        XCTAssertEqual(sut.effectiveThermalState, .nominal)
        XCTAssertEqual(sut.targetFrameRate, 60)
        XCTAssertFalse(sut.isThrottlingActive)
        XCTAssertFalse(sut.isScreenDimmed)
        XCTAssertFalse(sut.isPlaybackPausedByThermal)
        XCTAssertEqual(sut.statusColor, .dcSuccess)
    }

    @MainActor
    func testSeriousThermalStateThrottlesTo30FPSAndAutoDims() {
        sut.simulateThermalState(.serious)
        XCTAssertEqual(sut.effectiveThermalState, .serious)
        XCTAssertEqual(sut.targetFrameRate, 30, "Serious thermal state must throttle render loop to 30 FPS")
        XCTAssertTrue(sut.isThrottlingActive)
        XCTAssertTrue(sut.isScreenDimmed, "Auto-dim should be engaged on .serious when enabled")
        XCTAssertFalse(sut.isPlaybackPausedByThermal)
        XCTAssertEqual(sut.statusColor, .dcWarning)
    }

    @MainActor
    func testCriticalThermalStateSets15FPSAndTriggersEmergencyPause() {
        sut.simulateThermalState(.critical)
        XCTAssertEqual(sut.effectiveThermalState, .critical)
        XCTAssertEqual(sut.targetFrameRate, 15, "Critical thermal state must throttle render loop to 15 FPS")
        XCTAssertTrue(sut.isThrottlingActive)
        XCTAssertTrue(sut.isScreenDimmed)
        XCTAssertEqual(sut.statusColor, .dcDanger)
    }

    @MainActor
    func testRecoveryFromCriticalToNominal() {
        sut.simulateThermalState(.critical)
        XCTAssertEqual(sut.targetFrameRate, 15)

        sut.simulateThermalState(.nominal)
        XCTAssertEqual(sut.effectiveThermalState, .nominal)
        XCTAssertEqual(sut.targetFrameRate, 60, "Target frame rate must recover to 60 FPS")
        XCTAssertFalse(sut.isThrottlingActive)
        XCTAssertFalse(sut.isPlaybackPausedByThermal)
    }

    @MainActor
    func testEcoModeCapsFramerateTo30FPSAtNominal() {
        sut.simulateThermalState(.nominal)
        XCTAssertEqual(sut.targetFrameRate, 60)

        sut.isEcoModeEnabled = true
        XCTAssertEqual(sut.targetFrameRate, 30, "Eco Mode must cap render frame rate to 30 FPS even when nominal")
        XCTAssertTrue(sut.isThrottlingActive)

        sut.isEcoModeEnabled = false
        XCTAssertEqual(sut.targetFrameRate, 60)
        XCTAssertFalse(sut.isThrottlingActive)
    }

    @MainActor
    func testScreenDimmerManualToggleAndWake() {
        XCTAssertFalse(sut.isScreenDimmed)

        sut.toggleScreenDimming()
        XCTAssertTrue(sut.isScreenDimmed)

        sut.wakeScreen()
        XCTAssertFalse(sut.isScreenDimmed)
    }

    @MainActor
    func testSimulatedThermalStateOverride() {
        sut.simulateThermalState(.fair)
        XCTAssertEqual(sut.effectiveThermalState, .fair)
        XCTAssertEqual(sut.targetFrameRate, 60)
        XCTAssertEqual(sut.statusColor, .dcInfo)

        sut.simulateThermalState(nil)
        XCTAssertEqual(sut.effectiveThermalState, sut.systemThermalState)
    }

    @MainActor
    func testPersistenceSettings() {
        sut.isEcoModeEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: CockpitThermalService.Keys.ecoMode))

        sut.autoDimOnSerious = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: CockpitThermalService.Keys.autoDim))

        sut.audioAlertOnCritical = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: CockpitThermalService.Keys.audioAlert))

        sut.resetDefaults()
        XCTAssertFalse(sut.isEcoModeEnabled)
        XCTAssertTrue(sut.autoDimOnSerious)
        XCTAssertTrue(sut.audioAlertOnCritical)
    }

    @MainActor
    func testDeepLinkRouting() {
        guard let url = URL(string: "dashcast://thermal") else {
            XCTFail("Failed to form URL")
            return
        }

        let destination = DashCastLinks.destination(for: url)
        XCTAssertEqual(destination, .thermal)

        let appState = AppState()
        appState.showThermalSheet = false

        let handled = appState.handleDeepLink(url)
        XCTAssertTrue(handled)
        XCTAssertTrue(appState.showThermalSheet)
    }

    @MainActor
    func testViewInstantiations() {
        let badge = CockpitThermalBadgeView()
        XCTAssertNotNil(badge)

        let compactBadge = CockpitThermalBadgeView(isCompact: true)
        XCTAssertNotNil(compactBadge)

        let dimmer = CockpitThermalDimmerOverlay()
        XCTAssertNotNil(dimmer)

        let sheet = ThermalProtectionSheet()
        XCTAssertNotNil(sheet)
    }
}
