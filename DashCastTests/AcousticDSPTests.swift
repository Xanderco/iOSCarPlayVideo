import XCTest
@testable import DashCast

final class AcousticDSPTests: XCTestCase {
    private var sut: CabinAcousticDSPService!

    @MainActor
    override func setUp() {
        super.setUp()
        sut = CabinAcousticDSPService()
        sut.isEnabled = true
        sut.speedCompensationEnabled = true
        sut.selectedProfile = .suv
        sut.speechEnhancerIntensity = 0.85
        sut.simulatedSpeedMph = nil
    }

    @MainActor
    override func tearDown() {
        sut.simulatedSpeedMph = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Tests

    @MainActor
    func testStationarySpeedGainIsBaseline() {
        // At 0 mph, dynamic speed offset should be 0.0 dB
        for band in CabinAcousticDSPService.EQBand.allCases {
            let offset = sut.speedOffset(for: band, atSpeedMph: 0.0)
            XCTAssertEqual(offset, 0.0, accuracy: 0.001)

            let gain = sut.computedGain(for: band, atSpeedMph: 0.0)
            let base = sut.selectedProfile.defaultBandGains[band.rawValue]
            XCTAssertEqual(gain, base, accuracy: 0.001)
        }
    }

    @MainActor
    func testHighwaySpeedVocalLift() {
        // At 70 mph, vocal clarity (2.5 kHz) should receive significant boost
        let baseline = sut.selectedProfile.defaultBandGains[CabinAcousticDSPService.EQBand.vocalClarity.rawValue]
        let highwayGain = sut.computedGain(for: .vocalClarity, atSpeedMph: 70.0)
        let boost = highwayGain - baseline

        XCTAssertGreaterThan(boost, 3.0, "Vocal clarity at 70 mph should be boosted by at least 3 dB")
        XCTAssertLessThanOrEqual(boost, 6.0, "Vocal clarity boost should not exceed 6 dB ceiling")
    }

    @MainActor
    func testSubBassRumbleAttenuationAtHighSpeed() {
        // At 75 mph, sub-bass (60 Hz) should roll off to cut door rattle & tire cavity resonance
        let offset = sut.speedOffset(for: .subBass, atSpeedMph: 75.0)
        XCTAssertLessThan(offset, -1.5, "Sub-bass should be attenuated by more than 1.5 dB at 75 mph")
    }

    @MainActor
    func testCabinProfilesDifferInAcousticCurves() {
        let sedan = CabinAcousticDSPService.CabinProfile.sedan
        let suv = CabinAcousticDSPService.CabinProfile.suv
        let sports = CabinAcousticDSPService.CabinProfile.sports

        XCTAssertLessThan(sedan.baseNoiseDBA, suv.baseNoiseDBA)
        XCTAssertLessThan(suv.baseNoiseDBA, sports.baseNoiseDBA)

        // Sports profile has higher default vocal clarity to overcome high ambient noise
        XCTAssertGreaterThan(
            sports.defaultBandGains[CabinAcousticDSPService.EQBand.vocalClarity.rawValue],
            sedan.defaultBandGains[CabinAcousticDSPService.EQBand.vocalClarity.rawValue]
        )
    }

    @MainActor
    func testEstimatedNoiseScalesWithSpeed() {
        sut.selectedProfile = .sedan
        let idleNoise = sut.estimatedAmbientNoiseDBA(atSpeedMph: 0.0)
        XCTAssertEqual(idleNoise, sut.selectedProfile.baseNoiseDBA, accuracy: 0.5)

        let highwayNoise = sut.estimatedAmbientNoiseDBA(atSpeedMph: 70.0)
        XCTAssertGreaterThan(highwayNoise, idleNoise + 15.0, "Highway noise should rise by over 15 dBA")
        XCTAssertLessThanOrEqual(highwayNoise, 86.0)
    }

    @MainActor
    func testCustomBandGainsAdjustmentAndReset() {
        sut.setCustomGain(band: .vocalClarity, gain: 4.5)
        XCTAssertEqual(sut.selectedProfile, .custom)
        XCTAssertEqual(sut.customBandGains[CabinAcousticDSPService.EQBand.vocalClarity.rawValue], 4.5, accuracy: 0.01)

        sut.resetToProfileDefaults()
        XCTAssertEqual(sut.customBandGains[CabinAcousticDSPService.EQBand.vocalClarity.rawValue], 0.0, accuracy: 0.01)
    }

    @MainActor
    func testSpeedCompensationToggle() {
        sut.speedCompensationEnabled = false
        let offset = sut.speedOffset(for: .vocalClarity, atSpeedMph: 75.0)
        XCTAssertEqual(offset, 0.0, "Disabled compensation must return 0 dB offset")

        let gain = sut.computedGain(for: .vocalClarity, atSpeedMph: 75.0)
        let base = sut.selectedProfile.defaultBandGains[CabinAcousticDSPService.EQBand.vocalClarity.rawValue]
        XCTAssertEqual(gain, base, accuracy: 0.001)
    }

    @MainActor
    func testMasterEnableToggle() {
        sut.isEnabled = false
        for band in CabinAcousticDSPService.EQBand.allCases {
            XCTAssertEqual(sut.computedGain(for: band, atSpeedMph: 70.0), 0.0, "Bypassed DSP must return 0.0 dB gain")
        }
    }

    @MainActor
    func testSimulatedSpeedOverride() {
        sut.simulatedSpeedMph = 62.0
        XCTAssertEqual(sut.effectiveSpeedMph, 62.0, accuracy: 0.1)

        sut.simulatedSpeedMph = nil
        // Without simulated speed, effectiveSpeedMph reads DriveLocationService (0.0 when stationary)
        XCTAssertEqual(sut.effectiveSpeedMph, 0.0, accuracy: 0.1)
    }

    @MainActor
    func testDeepLinkRouting() {
        guard let url = URL(string: "dashcast://acoustic-dsp") else {
            XCTFail("Failed to form URL")
            return
        }

        let destination = DashCastLinks.destination(for: url)
        XCTAssertEqual(destination, .acousticDSP)

        let appState = AppState()
        appState.selectedTab = .sounds
        appState.showAcousticDSPSheet = false

        let handled = appState.handleDeepLink(url)
        XCTAssertTrue(handled)
        XCTAssertEqual(appState.selectedTab, .cast)
        XCTAssertTrue(appState.showAcousticDSPSheet)
    }
    @MainActor
    func testCarPlayExternalDisplayBadge() {
        sut.isEnabled = true
        XCTAssertTrue(sut.isEnabled)
        
        let view = CarPlayExternalDisplayView()
        XCTAssertNotNil(view)
        
        sut.isEnabled = false
        XCTAssertFalse(sut.isEnabled)
    }
}
