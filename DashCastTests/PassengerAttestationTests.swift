import XCTest
import SwiftUI
@testable import DashCast

final class PassengerAttestationTests: XCTestCase {
    private var sut: PassengerAttestationGate!

    @MainActor
    override func setUp() {
        super.setUp()
        sut = PassengerAttestationGate()
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
        XCTAssertEqual(PassengerAttestationGate.speedThresholdMph, 5.0, accuracy: 0.001)
        XCTAssertEqual(PassengerAttestationGate.speedThresholdKmh, 8.04672, accuracy: 0.001)
        XCTAssertEqual(sut.currentSpeedKmh, 0)
        XCTAssertEqual(sut.currentSpeedMph, 0)
        XCTAssertFalse(sut.isVehicleMovingAboveThreshold)
        XCTAssertFalse(sut.isAttestationRequired)
        XCTAssertFalse(sut.isPassengerModeActive)
        XCTAssertTrue(sut.isPlaybackAllowed, "Parked or stopped vehicle should allow video playback by default")
        XCTAssertNil(sut.attestationExpiresAt)
        XCTAssertEqual(sut.sessionTimeRemaining, 0)
        XCTAssertEqual(sut.sessionDuration, 900)
    }

    @MainActor
    func testSpeedThresholdTriggersMotionGate() {
        // Speed below 5 mph (e.g. 4.0 km/h ~= 2.5 mph)
        sut.simulateSpeed(kmh: 4.0)
        XCTAssertFalse(sut.isVehicleMovingAboveThreshold)
        XCTAssertFalse(sut.isAttestationRequired)
        XCTAssertTrue(sut.isPlaybackAllowed)

        // Speed exceeds 5 mph threshold (e.g. 15.0 km/h ~= 9.3 mph)
        sut.simulateSpeed(kmh: 15.0)
        XCTAssertTrue(sut.isVehicleMovingAboveThreshold)
        XCTAssertTrue(sut.isAttestationRequired)
        XCTAssertFalse(sut.isPlaybackAllowed, "Video playback must be blocked when moving > 5 mph without passenger attestation")
        XCTAssertFalse(sut.isPassengerModeActive)

        // Verify audit log has recorded the trigger
        XCTAssertTrue(sut.auditHistory.contains { $0.eventType == .speedThresholdExceeded })
        XCTAssertTrue(sut.auditHistory.contains { $0.eventType == .playbackBlocked })
    }

    @MainActor
    func testMultiFingerTouchAttestationUnlocksPlayback() {
        // Vehicle in motion (> 5 mph)
        sut.simulateSpeed(kmh: 20.0)
        XCTAssertFalse(sut.isPlaybackAllowed)

        // Passenger confirms viewing via physical multi-finger touch
        let now = Date()
        sut.confirmPassengerAttestation(method: .multiFingerTouch, now: now)

        XCTAssertTrue(sut.isPassengerModeActive)
        XCTAssertFalse(sut.isAttestationRequired)
        XCTAssertTrue(sut.isPlaybackAllowed, "Playback must be unlocked once passenger attests")
        XCTAssertNotNil(sut.attestationExpiresAt)
        XCTAssertGreaterThan(sut.sessionTimeRemaining, 0)

        // Check audit entry
        let grantedEvent = sut.auditHistory.first { $0.eventType == .attestationGranted }
        XCTAssertNotNil(grantedEvent)
        XCTAssertEqual(grantedEvent?.method, "multi_finger_touch")
    }

    @MainActor
    func testManualConfirmationMethod() {
        sut.simulateSpeed(kmh: 25.0)
        let now = Date()
        sut.confirmPassengerAttestation(method: .manualConfirmation, now: now)

        XCTAssertTrue(sut.isPassengerModeActive)
        XCTAssertTrue(sut.isPlaybackAllowed)
        let grantedEvent = sut.auditHistory.first { $0.eventType == .attestationGranted }
        XCTAssertEqual(grantedEvent?.method, "manual_confirm")
    }

    @MainActor
    func testRevocationWhileInMotionImmediatelyBlocksPlayback() {
        // In motion and attested
        sut.simulateSpeed(kmh: 30.0)
        sut.confirmPassengerAttestation(method: .multiFingerTouch)
        XCTAssertTrue(sut.isPlaybackAllowed)

        // Revoke attestation
        sut.revokeAttestation(reason: "test_revocation")
        XCTAssertFalse(sut.isPassengerModeActive)
        XCTAssertTrue(sut.isAttestationRequired)
        XCTAssertFalse(sut.isPlaybackAllowed, "Revoking attestation in motion must immediately block playback")
        XCTAssertNil(sut.attestationExpiresAt)

        XCTAssertTrue(sut.auditHistory.contains { $0.eventType == .attestationRevoked })
    }

    @MainActor
    func testVehicleStoppingRestoresPlaybackLegally() {
        // In motion without attestation: blocked
        sut.simulateSpeed(kmh: 20.0)
        XCTAssertFalse(sut.isPlaybackAllowed)

        // Vehicle stops at traffic light (0 km/h)
        sut.simulateSpeed(kmh: 0.0)
        XCTAssertFalse(sut.isVehicleMovingAboveThreshold)
        XCTAssertFalse(sut.isAttestationRequired)
        XCTAssertTrue(sut.isPlaybackAllowed, "When stopped or parked, video playback is legally unrestricted")

        XCTAssertTrue(sut.auditHistory.contains { $0.eventType == .speedDroppedBelowThreshold })
    }

    @MainActor
    func testAttestationExpirationRequiresReattestationInMotion() {
        sut.simulateSpeed(kmh: 20.0)
        sut.confirmPassengerAttestation(method: .multiFingerTouch)
        XCTAssertTrue(sut.isPlaybackAllowed)

        // Simulate session timeout / expiration
        sut.simulateExpiration()

        XCTAssertFalse(sut.isPassengerModeActive)
        XCTAssertTrue(sut.isAttestationRequired)
        XCTAssertFalse(sut.isPlaybackAllowed, "Expired attestation while in motion must block playback and require re-attestation")
        XCTAssertTrue(sut.auditHistory.contains { $0.eventType == .attestationExpired })
    }

    @MainActor
    func testAuditTrailPersistenceAndClearing() {
        sut.simulateSpeed(kmh: 15.0)
        sut.confirmPassengerAttestation(method: .multiFingerTouch)
        XCTAssertGreaterThan(sut.auditHistory.count, 0)

        let countBefore = sut.auditHistory.count
        sut.clearAuditHistory()
        XCTAssertEqual(sut.auditHistory.count, 0, "Audit history must be emptied on clear")
    }

    @MainActor
    func testDeepLinkRoutingAndDestinations() {
        XCTAssertEqual(DashCastLinks.destination(for: URL(string: "dashcast://safety")!), .safety)
        XCTAssertEqual(DashCastLinks.destination(for: URL(string: "dashcast://attestation")!), .safety)
        XCTAssertEqual(DashCastLinks.destination(for: URL(string: "dashcast://passenger")!), .safety)

        let appState = AppState.shared
        appState.showAttestationSheet = false
        let handled = appState.handleDeepLink(URL(string: "dashcast://safety")!)
        XCTAssertTrue(handled)
        XCTAssertTrue(appState.showAttestationSheet)
    }

    @MainActor
    func testViewInstantiationSanity() {
        let compactWatermark = HUDPassengerWatermarkOverlay(isCompact: true)
        XCTAssertNotNil(compactWatermark.body)

        let fullWatermark = HUDPassengerWatermarkOverlay(isCompact: false)
        XCTAssertNotNil(fullWatermark.body)

        let badge = PassengerAttestationBadgeView(isCompact: true)
        XCTAssertNotNil(badge.body)

        let blocker = PassengerAttestationBlockerOverlay()
        XCTAssertNotNil(blocker.body)

        let sheet = PassengerAttestationSheet()
        XCTAssertNotNil(sheet.body)

        let auditSheet = PassengerAuditLogSheet()
        XCTAssertNotNil(auditSheet.body)
    }
}
