import XCTest
import CoreHaptics
@testable import DashCast

@MainActor
final class CabinHapticsEngineTests: XCTestCase {
    private var suiteName: String!
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.xanderco.dashcast.tests.haptics.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        if let suiteName {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeEngine() -> CabinHapticsEngine {
        CabinHapticsEngine(userDefaults: testDefaults, enableHardwareEngine: false)
    }

    func testAllCuesHaveValidCalibratedWaveformsAndCHHapticPattern() throws {
        for cue in CabinHapticCue.allCases {
            let spec = cue.waveform
            XCTAssertFalse(spec.events.isEmpty, "\(cue.rawValue) should define at least one haptic event")
            XCTAssertFalse(spec.patternFamily.isEmpty, "\(cue.rawValue) should define a pattern family")
            XCTAssertGreaterThan(spec.totalDuration, 0.0, "\(cue.rawValue) should have positive duration")

            let pattern = try spec.buildCHHapticPattern(intensityScale: 0.75)
            XCTAssertGreaterThan(pattern.duration, 0.0, "\(cue.rawValue) CHHapticPattern should have positive duration")
        }
    }

    func testNamedPatternFamiliesExistForChimeWarningAndLaunchRumble() {
        XCTAssertEqual(CabinHapticCue.carConnected.waveform.patternFamily, "Chime Pulse")
        XCTAssertEqual(CabinHapticCue.speedWarning.waveform.patternFamily, "Warning Thud")
        XCTAssertEqual(CabinHapticCue.launchStaged.waveform.patternFamily, "Launch Stage Rumble")
        XCTAssertEqual(CabinHapticCue.streamBuffering.waveform.patternFamily, "Buffer Cadence")
        XCTAssertEqual(CabinHapticCue.blindSelect.waveform.patternFamily, "Tactile Detent")
    }

    func testIntensityScalingClampsSafely() {
        let spec = CabinHapticCue.speedWarning.waveform
        XCTAssertEqual(spec.scaledIntensity(0.8, scale: 0.5), 0.4, accuracy: 0.0001)
        XCTAssertEqual(spec.scaledIntensity(1.0, scale: 2.0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(spec.scaledIntensity(1.0, scale: -0.5), 0.0, accuracy: 0.0001)
    }

    func testParkedAllowsNonCriticalAndCriticalCues() {
        let engine = makeEngine()
        let base = Date(timeIntervalSince1970: 1_000)
        engine.updateMotionState(isMoving: false, speedKmh: 0)

        XCTAssertTrue(engine.trigger(.streamBuffering, now: base).didTrigger)
        XCTAssertTrue(engine.trigger(.streamReady, now: base.addingTimeInterval(0.1)).didTrigger)
        XCTAssertTrue(engine.trigger(.carConnected, now: base.addingTimeInterval(0.2)).didTrigger)
        XCTAssertTrue(engine.trigger(.launchStaged, now: base.addingTimeInterval(0.3)).didTrigger)
        XCTAssertTrue(engine.trigger(.blindSelect, now: base.addingTimeInterval(0.4)).didTrigger)
    }

    func testMovingSuppressesNonCriticalCuesWhenMotionSuppressionEnabled() {
        let engine = makeEngine()
        let base = Date(timeIntervalSince1970: 2_000)
        engine.suppressNonCriticalWhileMoving = true
        engine.updateMotionState(isMoving: true, speedKmh: 65)

        let nonCritical: [CabinHapticCue] = [
            .streamBuffering,
            .streamReady,
            .carConnected,
            .launchStaged,
            .launchReady,
            .blindSelect
        ]

        for (index, cue) in nonCritical.enumerated() {
            let outcome = engine.trigger(cue, now: base.addingTimeInterval(Double(index)))
            XCTAssertFalse(outcome.didTrigger, "\(cue.rawValue) should be suppressed while moving")
            XCTAssertEqual(outcome.suppressionReason, .suppressedWhileMoving)
        }
    }

    func testMovingStillAllowsCriticalSafetyAndDisconnectCues() {
        let engine = makeEngine()
        let base = Date(timeIntervalSince1970: 3_000)
        engine.suppressNonCriticalWhileMoving = true
        engine.updateMotionState(isMoving: true, speedKmh: 90)

        let speedOutcome = engine.trigger(.speedWarning, now: base)
        XCTAssertTrue(speedOutcome.didTrigger, "Speed warning must fire while moving")

        let harshOutcome = engine.trigger(.harshDrivingEvent, now: base.addingTimeInterval(1))
        XCTAssertTrue(harshOutcome.didTrigger, "Harsh driving event must fire while moving")

        let disconnectOutcome = engine.trigger(.carDisconnected, now: base.addingTimeInterval(2))
        XCTAssertTrue(disconnectOutcome.didTrigger, "Car disconnect alert must fire while moving")
    }

    func testDisablingMotionSuppressionPermitsPlaybackAndNavigationCuesWhileMoving() {
        let engine = makeEngine()
        let base = Date(timeIntervalSince1970: 4_000)
        engine.suppressNonCriticalWhileMoving = false
        engine.updateMotionState(isMoving: true, speedKmh: 70)

        XCTAssertTrue(engine.trigger(.streamBuffering, now: base).didTrigger)
        XCTAssertTrue(engine.trigger(.blindSelect, now: base.addingTimeInterval(0.5)).didTrigger)
    }

    func testMasterDisableSuppressesAllCuesIncludingSafety() {
        let engine = makeEngine()
        let base = Date(timeIntervalSince1970: 5_000)
        engine.isHapticsEnabled = false
        engine.updateMotionState(isMoving: true, speedKmh: 135)

        for (index, cue) in CabinHapticCue.allCases.enumerated() {
            let outcome = engine.trigger(cue, now: base.addingTimeInterval(Double(index)))
            XCTAssertEqual(outcome, .suppressed(cue: cue, reason: .hapticsDisabled))
        }
    }

    func testQuietModeSuppressesNonSafetyButPreservesSafetyAlerts() {
        let engine = makeEngine()
        let base = Date(timeIntervalSince1970: 6_000)
        engine.isQuietModeEnabled = true
        engine.updateMotionState(isMoving: false, speedKmh: 0)

        let bufferOutcome = engine.trigger(.streamBuffering, now: base)
        XCTAssertEqual(bufferOutcome, .suppressed(cue: .streamBuffering, reason: .quietModeActive))

        let connectOutcome = engine.trigger(.carConnected, now: base.addingTimeInterval(1))
        XCTAssertEqual(connectOutcome, .suppressed(cue: .carConnected, reason: .quietModeActive))

        XCTAssertTrue(engine.trigger(.speedWarning, now: base.addingTimeInterval(2)).didTrigger)
        XCTAssertTrue(engine.trigger(.harshDrivingEvent, now: base.addingTimeInterval(3)).didTrigger)
    }

    func testCooldownPreventsRapidRetriggerAndRecoversAfterInterval() {
        let engine = makeEngine()
        let t0 = Date(timeIntervalSince1970: 7_000)

        XCTAssertTrue(engine.trigger(.speedWarning, now: t0).didTrigger)

        let suppressed = engine.trigger(.speedWarning, now: t0.addingTimeInterval(2.0))
        XCTAssertEqual(suppressed, .suppressed(cue: .speedWarning, reason: .cooldownActive))

        let allowedAgain = engine.trigger(.speedWarning, now: t0.addingTimeInterval(CabinHapticCue.speedWarning.defaultCooldownSeconds))
        XCTAssertTrue(allowedAgain.didTrigger)
    }

    func testEvaluateTelemetryTriggersSpeedWarningOnlyAtOrAboveThreshold() {
        let engine = makeEngine()
        engine.speedWarningLimitKmh = 100
        let t0 = Date(timeIntervalSince1970: 8_000)

        let below = engine.evaluateTelemetry(speedKmh: 95, now: t0)
        XCTAssertNil(below)
        XCTAssertTrue(engine.isVehicleMoving)

        let above = engine.evaluateTelemetry(speedKmh: 105, now: t0.addingTimeInterval(1))
        XCTAssertEqual(above?.didTrigger, true)

        // When speed warning is disabled, threshold crossing does not trigger speed warning
        engine.isSpeedWarningEnabled = false
        let disabled = engine.evaluateTelemetry(speedKmh: 120, now: t0.addingTimeInterval(10))
        XCTAssertEqual(disabled, .suppressed(cue: .speedWarning, reason: .speedWarningDisabled))
    }

    func testPreferencesPersistAcrossEngineInstances() {
        let engine1 = makeEngine()
        engine1.isHapticsEnabled = false
        engine1.suppressNonCriticalWhileMoving = false
        engine1.isSpeedWarningEnabled = false
        engine1.speedWarningLimitKmh = 145
        engine1.isQuietModeEnabled = true
        engine1.intensityScale = 0.65

        let engine2 = makeEngine()
        XCTAssertFalse(engine2.isHapticsEnabled)
        XCTAssertFalse(engine2.suppressNonCriticalWhileMoving)
        XCTAssertFalse(engine2.isSpeedWarningEnabled)
        XCTAssertEqual(engine2.speedWarningLimitKmh, 145, accuracy: 0.001)
        XCTAssertTrue(engine2.isQuietModeEnabled)
        XCTAssertEqual(engine2.intensityScale, 0.65, accuracy: 0.001)
    }
}
