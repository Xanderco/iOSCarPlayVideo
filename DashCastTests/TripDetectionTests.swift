import XCTest
import CoreLocation
@testable import DashCast

final class TripDetectionTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// Feeds one sample per `step` seconds from `from` to `to` (inclusive) and returns events.
    @discardableResult
    private func drive(_ m: inout TripDetectionStateMachine, from: TimeInterval, to: TimeInterval, step: TimeInterval = 5,
                       speed: Double?, automotive: Bool? = nil, confidence: MotionConfidence = .high) -> [TripDetectionEvent] {
        var events: [TripDetectionEvent] = []
        var t = from
        while t <= to {
            let e = m.update(TripDetectionSample(speedKmh: speed, automotive: automotive, confidence: confidence, at: t0.addingTimeInterval(t)))
            if e != .none { events.append(e) }
            t += step
        }
        return events
    }

    func testStartsAfterSixtySecondsOfAutomotiveAboveThreshold() {
        var m = TripDetectionStateMachine()
        XCTAssertEqual(drive(&m, from: 0, to: 55, speed: 30, automotive: true), [])
        XCTAssertEqual(m.phase, .candidate(since: t0))
        XCTAssertEqual(drive(&m, from: 60, to: 60, speed: 30, automotive: true), [.startTrip])
        XCTAssertTrue(m.isDriving)
    }

    func testSlowAutomotiveDoesNotStart() {
        var m = TripDetectionStateMachine()
        XCTAssertEqual(drive(&m, from: 0, to: 300, speed: 10, automotive: true), [])
        XCTAssertEqual(m.phase, .idle)
    }

    func testLowConfidenceAutomotiveNeedsSpeedOnlyThreshold() {
        var m = TripDetectionStateMachine()
        XCTAssertEqual(drive(&m, from: 0, to: 120, speed: 20, automotive: true, confidence: .low), [])
        var m2 = TripDetectionStateMachine()
        XCTAssertEqual(drive(&m2, from: 0, to: 120, speed: 40, automotive: true, confidence: .low), [.startTrip])
    }

    func testDroppingBelowThresholdResetsCandidate() {
        var m = TripDetectionStateMachine()
        drive(&m, from: 0, to: 40, speed: 30, automotive: true)
        drive(&m, from: 45, to: 45, speed: 5, automotive: true)
        XCTAssertEqual(m.phase, .idle)
        XCTAssertEqual(drive(&m, from: 50, to: 105, speed: 30, automotive: true), [])
        XCTAssertEqual(drive(&m, from: 110, to: 110, speed: 30, automotive: true), [.startTrip])
    }

    func testSpeedOnlyStartsWhenNoMotionData() {
        // Simulator "Freeway Drive": no Core Motion, ~100 km/h.
        var m = TripDetectionStateMachine()
        XCTAssertEqual(drive(&m, from: 0, to: 60, speed: 100), [.startTrip])
    }

    func testRedLightDoesNotEndTrip() {
        var m = TripDetectionStateMachine()
        drive(&m, from: 0, to: 60, speed: 50, automotive: true)
        XCTAssertEqual(drive(&m, from: 65, to: 155, speed: 0, automotive: true), []) // 90 s stop
        XCTAssertEqual(drive(&m, from: 160, to: 400, speed: 50, automotive: true), [])
        XCTAssertTrue(m.isDriving)
    }

    func testEndsAfterThreeMinutesStationary() {
        var m = TripDetectionStateMachine()
        drive(&m, from: 0, to: 60, speed: 50, automotive: true)
        let events = drive(&m, from: 65, to: 65 + 175, speed: 0, automotive: false)
        XCTAssertEqual(events, [])
        XCTAssertEqual(drive(&m, from: 245, to: 250, speed: 0, automotive: false), [.endTrip])
        XCTAssertEqual(m.phase, .idle)
    }

    func testEndsWhenSensorsGoSilent() {
        var m = TripDetectionStateMachine()
        drive(&m, from: 0, to: 60, speed: 50, automotive: true)
        // Only timer ticks, no new speed or motion (fresh data expires after 30 s / 120 s).
        let events = drive(&m, from: 75, to: 600, step: 15, speed: nil)
        XCTAssertEqual(events, [.endTrip])
    }

    func testCustomThresholdsAreHonoured() {
        var m = TripDetectionStateMachine(startSpeedKmh: 15, speedOnlyStartKmh: 25, startHoldSeconds: 10, stopHoldSeconds: 20)
        XCTAssertEqual(drive(&m, from: 0, to: 10, speed: 30, automotive: true), [.startTrip])
        XCTAssertEqual(drive(&m, from: 15, to: 40, speed: 0, automotive: false), [.endTrip])
    }

    func testResetToDrivingForManualTrips() {
        var m = TripDetectionStateMachine()
        m.reset(driving: true, at: t0)
        XCTAssertTrue(m.isDriving)
        m.reset(driving: false, at: t0)
        XCTAssertEqual(m.phase, .idle)
    }

    func testAutoDetectionDefaultsOnOnlyWithAlways() {
        XCTAssertTrue(AutoTripService.isEnabled(preference: nil, status: .authorizedAlways))
        XCTAssertFalse(AutoTripService.isEnabled(preference: false, status: .authorizedAlways))
        XCTAssertFalse(AutoTripService.isEnabled(preference: nil, status: .authorizedWhenInUse))
        XCTAssertFalse(AutoTripService.isEnabled(preference: true, status: .denied))
    }

    func testPermissionCardKinds() {
        XCTAssertEqual(LocationPermissionCard.kind(for: .notDetermined), .askWhenInUse)
        XCTAssertEqual(LocationPermissionCard.kind(for: .authorizedWhenInUse), .askAlways)
        XCTAssertEqual(LocationPermissionCard.kind(for: .denied), .denied)
        XCTAssertEqual(LocationPermissionCard.kind(for: .restricted), .restricted)
        XCTAssertEqual(LocationPermissionCard.kind(for: .authorizedAlways), .none)
    }

    func testAutoTripPreferenceRoundTripsAndDefaultsToNil() throws {
        let legacy = try JSONDecoder().decode(UserPreferences.self, from: Data("{}".utf8))
        XCTAssertNil(legacy.autoTripDetectionEnabled)
        var prefs = UserPreferences()
        prefs.autoTripDetectionEnabled = false
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(prefs))
        XCTAssertEqual(decoded.autoTripDetectionEnabled, false)
    }
}

final class TripReplayTests: XCTestCase {
    func testReplayIndexMapping() {
        XCTAssertEqual(TripReplayMapView.index(for: 0, count: 11), 0)
        XCTAssertEqual(TripReplayMapView.index(for: 0.5, count: 11), 5)
        XCTAssertEqual(TripReplayMapView.index(for: 1, count: 11), 10)
        XCTAssertEqual(TripReplayMapView.index(for: 2, count: 11), 10)
        XCTAssertEqual(TripReplayMapView.index(for: -1, count: 11), 0)
        XCTAssertEqual(TripReplayMapView.index(for: 0.5, count: 0), 0)
    }
}
