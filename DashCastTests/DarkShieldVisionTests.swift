import XCTest
import SwiftUI
@testable import DashCast

final class DarkShieldVisionTests: XCTestCase {
    private var sut: DarkShieldVisionService!

    @MainActor
    override func setUp() {
        super.setUp()
        sut = DarkShieldVisionService()
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
    func testInitialDefaults() {
        XCTAssertEqual(sut.selectedPreset, .off)
        XCTAssertEqual(sut.tunnelDefaultPreset, .photopicAmber)
        XCTAssertTrue(sut.isAutoTunnelEnabled)
        XCTAssertEqual(sut.glareReductionLevel, 0.75, accuracy: 0.001)
        XCTAssertTrue(sut.isWindshieldReflectionSuppressed)
        XCTAssertTrue(sut.isInvertWhiteBackgroundsEnabled)
        XCTAssertFalse(sut.isActive)
        XCTAssertFalse(sut.isTunnelActive)
        XCTAssertEqual(sut.effectivePreset, .off)
    }

    @MainActor
    func testPresetSwitchingAndActiveState() {
        sut.setPreset(.photopicAmber)
        XCTAssertEqual(sut.effectivePreset, .photopicAmber)
        XCTAssertTrue(sut.isActive)
        XCTAssertEqual(sut.statusTitle, "Photopic Amber")
        XCTAssertEqual(sut.statusIconName, "eyeglasses")

        sut.setPreset(.aviationRed)
        XCTAssertEqual(sut.effectivePreset, .aviationRed)
        XCTAssertTrue(sut.isActive)
        XCTAssertEqual(sut.statusTitle, "Aviation Red")
        XCTAssertEqual(sut.statusIconName, "moon.stars.fill")

        sut.setPreset(.oledDeepBlack)
        XCTAssertEqual(sut.effectivePreset, .oledDeepBlack)
        XCTAssertTrue(sut.isActive)
        XCTAssertEqual(sut.statusTitle, "OLED Deep Black")
        XCTAssertEqual(sut.statusIconName, "shield.lefthalf.filled")

        sut.setPreset(.off)
        XCTAssertEqual(sut.effectivePreset, .off)
        XCTAssertFalse(sut.isActive)
    }

    @MainActor
    func testColorMatrixMathPassthrough() {
        sut.setPreset(.off)
        let result = sut.colorTransform(r: 0.4, g: 0.5, b: 0.6)
        XCTAssertEqual(result.r, 0.4, accuracy: 0.001)
        XCTAssertEqual(result.g, 0.5, accuracy: 0.001)
        XCTAssertEqual(result.b, 0.6, accuracy: 0.001)
    }

    @MainActor
    func testColorMatrixMathPhotopicAmber() {
        sut.setPreset(.photopicAmber)
        sut.glareReductionLevel = 1.0

        // White input: (1, 1, 1) -> Luminance Y = 1.0
        let transformed = sut.colorTransform(r: 1.0, g: 1.0, b: 1.0)
        XCTAssertEqual(transformed.r, 1.0, accuracy: 0.001, "Red channel should be boosted")
        XCTAssertGreaterThan(transformed.g, 0.70, "Green channel should remain high for amber transmission")
        XCTAssertLessThan(transformed.b, 0.15, "Blue Rayleigh scattering must be strongly attenuated (< 0.15)")
    }

    @MainActor
    func testColorMatrixMathAviationRed() {
        sut.setPreset(.aviationRed)
        sut.glareReductionLevel = 1.0

        // White input: (1, 1, 1) -> Luminance Y = 1.0
        let transformed = sut.colorTransform(r: 1.0, g: 1.0, b: 1.0)
        XCTAssertEqual(transformed.r, 1.0, accuracy: 0.001, "Red channel must dominate in Aviation Red mode")
        XCTAssertLessThan(transformed.g, 0.10, "Green channel must be suppressed to preserve rhodopsin")
        XCTAssertLessThan(transformed.b, 0.10, "Blue channel must be suppressed to preserve rhodopsin")
    }

    @MainActor
    func testColorMatrixMathOLEDDeepBlack() {
        sut.setPreset(.oledDeepBlack)
        sut.glareReductionLevel = 1.0

        // Midtone input (0.5, 0.5, 0.5)
        let transformed = sut.colorTransform(r: 0.5, g: 0.5, b: 0.5)
        XCTAssertLessThan(transformed.r, 0.5, "Gamma curve must compress midtones")
        XCTAssertLessThan(transformed.g, 0.5, "Gamma curve must compress midtones")
        XCTAssertLessThan(transformed.b, 0.5, "Gamma curve must compress midtones")

        // Dark input (0.1, 0.1, 0.1) should be crushed close to zero
        let darkTransform = sut.colorTransform(r: 0.1, g: 0.1, b: 0.1)
        XCTAssertLessThan(darkTransform.r, 0.03, "Dark grays must be crushed to near-black")
    }

    @MainActor
    func testAutoTunnelTriggerAndRecovery() {
        sut.setPreset(.off)
        XCTAssertFalse(sut.isActive)

        sut.simulateTunnel(true)
        XCTAssertTrue(sut.isTunnelActive)
        XCTAssertTrue(sut.isActive, "DarkShield must become active when entering tunnel")
        XCTAssertEqual(sut.effectivePreset, .photopicAmber, "Default tunnel preset should engage when off")
        XCTAssertEqual(sut.statusTitle, "Tunnel Guard")

        sut.simulateTunnel(false)
        XCTAssertFalse(sut.isTunnelActive)
        XCTAssertFalse(sut.isActive)
        XCTAssertEqual(sut.effectivePreset, .off)
    }

    @MainActor
    func testCycleNextPreset() {
        sut.setPreset(.off)
        sut.cycleNextPreset()
        XCTAssertEqual(sut.selectedPreset, .photopicAmber)

        sut.cycleNextPreset()
        XCTAssertEqual(sut.selectedPreset, .aviationRed)

        sut.cycleNextPreset()
        XCTAssertEqual(sut.selectedPreset, .oledDeepBlack)

        sut.cycleNextPreset()
        XCTAssertEqual(sut.selectedPreset, .off)
    }

    @MainActor
    func testToggleActive() {
        sut.setPreset(.off)
        XCTAssertFalse(sut.isActive)

        sut.toggleActive()
        XCTAssertEqual(sut.selectedPreset, .photopicAmber)
        XCTAssertTrue(sut.isActive)

        sut.toggleActive()
        XCTAssertEqual(sut.selectedPreset, .off)
        XCTAssertFalse(sut.isActive)
    }

    @MainActor
    func testPersistenceSettings() {
        sut.setPreset(.aviationRed)
        XCTAssertEqual(UserDefaults.standard.string(forKey: DarkShieldVisionService.Keys.selectedPreset), DarkShieldFilterPreset.aviationRed.rawValue)

        sut.isAutoTunnelEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: DarkShieldVisionService.Keys.autoTunnel))

        sut.glareReductionLevel = 0.5
        XCTAssertEqual(UserDefaults.standard.double(forKey: DarkShieldVisionService.Keys.glareLevel), 0.5, accuracy: 0.001)

        sut.isWindshieldReflectionSuppressed = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: DarkShieldVisionService.Keys.windshieldSuppression))

        sut.isInvertWhiteBackgroundsEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: DarkShieldVisionService.Keys.invertWeb))

        sut.resetDefaults()
        XCTAssertEqual(sut.selectedPreset, .off)
        XCTAssertTrue(sut.isAutoTunnelEnabled)
        XCTAssertEqual(sut.glareReductionLevel, 0.75, accuracy: 0.001)
        XCTAssertTrue(sut.isWindshieldReflectionSuppressed)
        XCTAssertTrue(sut.isInvertWhiteBackgroundsEnabled)
    }

    @MainActor
    func testDeepLinkRouting() {
        guard let url1 = URL(string: "dashcast://vision"),
              let url2 = URL(string: "dashcast://darkshield") else {
            XCTFail("Failed to form URLs")
            return
        }

        XCTAssertEqual(DashCastLinks.destination(for: url1), .vision)
        XCTAssertEqual(DashCastLinks.destination(for: url2), .vision)

        let appState = AppState()
        appState.showDarkShieldSheet = false

        let handled1 = appState.handleDeepLink(url1)
        XCTAssertTrue(handled1)
        XCTAssertTrue(appState.showDarkShieldSheet)

        appState.showDarkShieldSheet = false
        let handled2 = appState.handleDeepLink(url2)
        XCTAssertTrue(handled2)
        XCTAssertTrue(appState.showDarkShieldSheet)
    }

    @MainActor
    func testViewInstantiations() {
        let badge = DarkShieldBadgeView()
        XCTAssertNotNil(badge)

        let compactBadge = DarkShieldBadgeView(isCompact: true)
        XCTAssertNotNil(compactBadge)

        let overlay = DarkShieldFilterOverlay()
        XCTAssertNotNil(overlay)

        let webOverlay = DarkShieldFilterOverlay(isWebBrowser: true)
        XCTAssertNotNil(webOverlay)

        let sheet = DarkShieldVisionSheet()
        XCTAssertNotNil(sheet)
    }
}
