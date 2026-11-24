import XCTest
import SwiftUI
import MediaPlayer
@testable import DashCast

final class CarPlayRotaryNavigationTests: XCTestCase {
    private var sut: CarPlayRotaryNavigationService!

    @MainActor
    override func setUp() {
        super.setUp()
        sut = CarPlayRotaryNavigationService()
        sut.resetDefaults()
    }

    @MainActor
    override func tearDown() {
        sut.resetDefaults()
        sut.detach()
        sut = nil
        super.tearDown()
    }

    // MARK: - Unit Tests

    @MainActor
    func testInitialDefaults() {
        XCTAssertEqual(sut.accelerationCurve, .parabolic)
        XCTAssertEqual(sut.steeringWheelMode, .channelSwitching)
        XCTAssertTrue(sut.isWrapAroundEnabled)
        XCTAssertEqual(sut.maxStride, 10)
        XCTAssertEqual(sut.focusedIndex, 0)
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertFalse(sut.isRotaryNavigationActive)
        XCTAssertEqual(sut.currentVelocityMultiplier, 1)
        XCTAssertEqual(sut.statusLabel, "Rotary Ready")
        XCTAssertEqual(sut.focusRingBorderWidth, 3.5)
        XCTAssertEqual(sut.focusRingGlowRadius, 8.0)
    }

    @MainActor
    func testFocusNextTraversalWithoutWrapping() {
        sut.isWrapAroundEnabled = false
        sut.itemCount = 5
        XCTAssertEqual(sut.focusedIndex, 0)

        // Slow turn: 1 click stride = 1
        let now = Date()
        sut.moveFocusNext(clicks: 1, timestamp: now.addingTimeInterval(1.0))
        XCTAssertEqual(sut.focusedIndex, 1)

        sut.moveFocusNext(clicks: 1, timestamp: now.addingTimeInterval(2.0))
        XCTAssertEqual(sut.focusedIndex, 2)

        sut.moveFocusNext(clicks: 1, timestamp: now.addingTimeInterval(3.0))
        XCTAssertEqual(sut.focusedIndex, 3)

        sut.moveFocusNext(clicks: 1, timestamp: now.addingTimeInterval(4.0))
        XCTAssertEqual(sut.focusedIndex, 4)

        // Beyond boundary clamps at itemCount - 1
        sut.moveFocusNext(clicks: 1, timestamp: now.addingTimeInterval(5.0))
        XCTAssertEqual(sut.focusedIndex, 4)
    }

    @MainActor
    func testFocusNextTraversalWithWrapping() {
        sut.isWrapAroundEnabled = true
        sut.itemCount = 4
        sut.setFocusedIndex(3)
        XCTAssertEqual(sut.focusedIndex, 3)

        let now = Date()
        sut.moveFocusNext(clicks: 1, timestamp: now.addingTimeInterval(1.0))
        XCTAssertEqual(sut.focusedIndex, 0)
    }

    @MainActor
    func testFocusPreviousTraversalWithoutWrapping() {
        sut.isWrapAroundEnabled = false
        sut.itemCount = 5
        sut.setFocusedIndex(1)
        XCTAssertEqual(sut.focusedIndex, 1)

        let now = Date()
        sut.moveFocusPrevious(clicks: 1, timestamp: now.addingTimeInterval(1.0))
        XCTAssertEqual(sut.focusedIndex, 0)

        // Clamps at 0
        sut.moveFocusPrevious(clicks: 1, timestamp: now.addingTimeInterval(2.0))
        XCTAssertEqual(sut.focusedIndex, 0)
    }

    @MainActor
    func testFocusPreviousTraversalWithWrapping() {
        sut.isWrapAroundEnabled = true
        sut.itemCount = 6
        sut.setFocusedIndex(0)
        XCTAssertEqual(sut.focusedIndex, 0)

        let now = Date()
        sut.moveFocusPrevious(clicks: 1, timestamp: now.addingTimeInterval(1.0))
        XCTAssertEqual(sut.focusedIndex, 5)
    }

    @MainActor
    func testAccelerationMathLinear() {
        let maxS = 10
        // Slow delta above slow threshold (0.28s) -> 1
        XCTAssertEqual(sut.computeStride(for: 0.35, curve: .linear, maxStride: maxS), 1)

        // Fast delta at or below fast threshold (0.06s) -> maxStride
        XCTAssertEqual(sut.computeStride(for: 0.05, curve: .linear, maxStride: maxS), maxS)
        XCTAssertEqual(sut.computeStride(for: 0.06, curve: .linear, maxStride: maxS), maxS)

        // Intermediate delta
        let mid = sut.computeStride(for: 0.17, curve: .linear, maxStride: maxS)
        XCTAssertGreaterThanOrEqual(mid, 4)
        XCTAssertLessThanOrEqual(mid, 7)
    }

    @MainActor
    func testAccelerationMathParabolic() {
        let maxS = 10
        // Slow delta -> 1
        XCTAssertEqual(sut.computeStride(for: 0.40, curve: .parabolic, maxStride: maxS), 1)

        // Fast delta -> maxStride
        XCTAssertEqual(sut.computeStride(for: 0.04, curve: .parabolic, maxStride: maxS), maxS)

        // Parabolic stays gentle at modest speeds
        let modest = sut.computeStride(for: 0.22, curve: .parabolic, maxStride: maxS)
        XCTAssertLessThanOrEqual(modest, 3)
    }

    @MainActor
    func testAccelerationMathStepped() {
        let maxS = 10
        XCTAssertEqual(sut.computeStride(for: 0.30, curve: .stepped, maxStride: maxS), 1)
        XCTAssertEqual(sut.computeStride(for: 0.18, curve: .stepped, maxStride: maxS), 2)
        XCTAssertEqual(sut.computeStride(for: 0.10, curve: .stepped, maxStride: maxS), 5)
        XCTAssertEqual(sut.computeStride(for: 0.05, curve: .stepped, maxStride: maxS), 10)
    }

    @MainActor
    func testAttachDetachLifecycle() {
        XCTAssertFalse(sut.isRotaryNavigationActive)
        sut.attach()
        XCTAssertTrue(sut.isRotaryNavigationActive)

        sut.detach()
        XCTAssertFalse(sut.isRotaryNavigationActive)
    }

    @MainActor
    func testSteeringWheelTrackSeekingMode() {
        sut.steeringWheelMode = .trackSeeking
        let statusNext = sut.handleNextTrackCommand()
        XCTAssertEqual(statusNext, .success)

        let statusPrev = sut.handlePreviousTrackCommand()
        XCTAssertEqual(statusPrev, .success)
    }

    @MainActor
    func testSteeringWheelDisabledMode() {
        sut.steeringWheelMode = .disabled
        let statusNext = sut.handleNextTrackCommand()
        XCTAssertEqual(statusNext, .commandFailed)

        let statusPrev = sut.handlePreviousTrackCommand()
        XCTAssertEqual(statusPrev, .commandFailed)
    }

    @MainActor
    func testPersistenceAndResetDefaults() {
        sut.accelerationCurve = .stepped
        XCTAssertEqual(UserDefaults.standard.string(forKey: CarPlayRotaryNavigationService.Keys.accelerationCurve), "stepped")

        sut.steeringWheelMode = .trackSeeking
        XCTAssertEqual(UserDefaults.standard.string(forKey: CarPlayRotaryNavigationService.Keys.steeringWheelMode), "track_seeking")

        sut.isWrapAroundEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: CarPlayRotaryNavigationService.Keys.wrapAround))

        sut.maxStride = 15
        XCTAssertEqual(UserDefaults.standard.integer(forKey: CarPlayRotaryNavigationService.Keys.maxStride), 15)

        sut.resetDefaults()
        XCTAssertEqual(sut.accelerationCurve, .parabolic)
        XCTAssertEqual(sut.steeringWheelMode, .channelSwitching)
        XCTAssertTrue(sut.isWrapAroundEnabled)
        XCTAssertEqual(sut.maxStride, 10)
    }

    @MainActor
    func testDeepLinkRouting() {
        guard let url = URL(string: "dashcast://rotary") else {
            XCTFail("Failed to form URL")
            return
        }

        let destination = DashCastLinks.destination(for: url)
        XCTAssertEqual(destination, .rotary)

        let appState = AppState()
        appState.showRotarySheet = false

        let handled = appState.handleDeepLink(url)
        XCTAssertTrue(handled)
        XCTAssertTrue(appState.showRotarySheet)
    }

    @MainActor
    func testViewInstantiations() {
        let compactBadge = CarPlayRotaryFocusBadgeView(isCompact: true)
        XCTAssertNotNil(compactBadge)

        let expandedBadge = CarPlayRotaryFocusBadgeView(isCompact: false)
        XCTAssertNotNil(expandedBadge)

        let viewWithRing = Text("Test Item").carPlayFocusRing(isFocused: true)
        XCTAssertNotNil(viewWithRing)

        let viewWithoutRing = Text("Test Item").carPlayFocusRing(isFocused: false)
        XCTAssertNotNil(viewWithoutRing)
    }
}
