import XCTest
import SwiftUI
@testable import DashCast

final class VirtualDynoEngineTests: XCTestCase {
    private var sut: VirtualDynoEngine!

    @MainActor
    override func setUp() {
        super.setUp()
        sut = VirtualDynoEngine(loadPersistedData: false)
        sut.clearHistory()
        sut.reset()
    }

    @MainActor
    override func tearDown() {
        sut.clearHistory()
        sut.reset()
        sut = nil
        super.tearDown()
    }

    // MARK: - Unit Tests

    @MainActor
    func testInitialDefaults() {
        XCTAssertEqual(sut.state, .idle)
        XCTAssertNil(sut.activeTelemetry)
        XCTAssertNil(sut.lastRecord)
        XCTAssertNil(sut.personalBest0To60)
        XCTAssertNil(sut.personalBestQuarterMile)
        XCTAssertTrue(sut.sprintHistory.isEmpty)
        XCTAssertTrue(sut.isAutoArmEnabled)
    }

    @MainActor
    func testStagingDwellTransitionsToStaged() {
        let t0 = Date(timeIntervalSince1970: 1000.0)

        // Vehicle stationary (speed = 0)
        sut.processSample(speedMps: 0.0, longitudinalG: 0.0, lateralG: 0.0, timestamp: t0)
        XCTAssertEqual(sut.state, .idle, "Should still be idle immediately upon stopping")

        // 0.5s later (less than dwell threshold of 1.2s)
        sut.processSample(speedMps: 0.0, longitudinalG: 0.0, lateralG: 0.0, timestamp: t0.addingTimeInterval(0.5))
        XCTAssertEqual(sut.state, .idle)

        // 1.5s later (exceeds 1.2s dwell)
        sut.processSample(speedMps: 0.0, longitudinalG: 0.0, lateralG: 0.0, timestamp: t0.addingTimeInterval(1.5))
        XCTAssertEqual(sut.state, .staged, "Vehicle should auto-stage after dwell duration at 0 mph")
    }

    @MainActor
    func testLaunchTriggerTransitionsToSprinting() {
        let t0 = Date(timeIntervalSince1970: 1000.0)
        sut.processSample(speedMps: 0.0, longitudinalG: 0.0, lateralG: 0.0, timestamp: t0)
        sut.processSample(speedMps: 0.0, longitudinalG: 0.0, lateralG: 0.0, timestamp: t0.addingTimeInterval(1.5))
        XCTAssertEqual(sut.state, .staged)

        // Launch trigger: acceleration punch > 0.15G with positive speed
        let tLaunch = t0.addingTimeInterval(2.0)
        sut.processSample(speedMps: 1.0, longitudinalG: 0.35, lateralG: 0.02, timestamp: tLaunch)

        XCTAssertEqual(sut.state, .sprinting)
        XCTAssertNotNil(sut.activeTelemetry)
        XCTAssertEqual(sut.activeTelemetry?.currentSpeedMph ?? 0.0, 1.0 * 2.23693629, accuracy: 0.01)
    }

    @MainActor
    func testSplit0To30CapturedCorrectly() {
        let t0 = Date(timeIntervalSince1970: 1000.0)
        sut.armManually()
        XCTAssertEqual(sut.state, .staged)

        // Launch
        sut.processSample(speedMps: 2.0, longitudinalG: 0.4, lateralG: 0.0, timestamp: t0)
        XCTAssertEqual(sut.state, .sprinting)
        XCTAssertNil(sut.activeTelemetry?.time0To30)

        // Reach 32 mph (14.3 m/s) at 1.8 seconds
        let t30 = t0.addingTimeInterval(1.8)
        sut.processSample(speedMps: 14.3, longitudinalG: 0.5, lateralG: 0.0, timestamp: t30)

        XCTAssertNotNil(sut.activeTelemetry?.time0To30)
        XCTAssertEqual(sut.activeTelemetry?.time0To30 ?? 0, 1.8, accuracy: 0.05)
        XCTAssertNil(sut.activeTelemetry?.time0To60, "0-60 should not be captured yet at 32 mph")
    }

    @MainActor
    func testSplit0To60CapturedAndSprintCompletion() {
        let t0 = Date(timeIntervalSince1970: 1000.0)
        sut.armManually()

        // Launch
        sut.processSample(speedMps: 2.0, longitudinalG: 0.6, lateralG: 0.0, timestamp: t0)

        // Reach 30 mph at 1.5s
        sut.processSample(speedMps: 14.0, longitudinalG: 0.55, lateralG: 0.0, timestamp: t0.addingTimeInterval(1.5))

        // Reach 61 mph (27.3 m/s) at 3.8s
        let t60 = t0.addingTimeInterval(3.8)
        sut.processSample(speedMps: 27.3, longitudinalG: 0.45, lateralG: 0.0, timestamp: t60)

        XCTAssertNotNil(sut.activeTelemetry?.time0To60)
        XCTAssertEqual(sut.activeTelemetry?.time0To60 ?? 0, 3.8, accuracy: 0.05)

        // Reach 1/4 mile (403m)
        let tQuarter = t0.addingTimeInterval(11.9)
        // Simulate higher speed distance accumulation
        for i in 1...10 {
            let tStep = t60.addingTimeInterval(Double(i) * 0.8)
            sut.processSample(speedMps: 45.0, longitudinalG: 0.3, lateralG: 0.0, timestamp: tStep)
        }

        XCTAssertEqual(sut.state, .completed)
        XCTAssertNotNil(sut.lastRecord)
        XCTAssertEqual(sut.lastRecord?.time0To60 ?? 0, 3.8, accuracy: 0.05)
        XCTAssertFalse(sut.sprintHistory.isEmpty)
    }

    @MainActor
    func testPeakGForceTracking() {
        let t0 = Date(timeIntervalSince1970: 1000.0)
        sut.armManually()

        sut.processSample(speedMps: 2.0, longitudinalG: 0.4, lateralG: 0.1, timestamp: t0)
        XCTAssertEqual(sut.activeTelemetry?.peakLongitudinalG ?? 0.0, 0.4, accuracy: 0.001)

        // Huge acceleration hit
        sut.processSample(speedMps: 10.0, longitudinalG: 0.95, lateralG: -0.25, timestamp: t0.addingTimeInterval(0.5))
        XCTAssertEqual(sut.activeTelemetry?.peakLongitudinalG ?? 0.0, 0.95, accuracy: 0.001)
        XCTAssertEqual(sut.activeTelemetry?.peakLateralG ?? 0.0, 0.25, accuracy: 0.001)

        // Lower G subsequent sample shouldn't lower peak
        sut.processSample(speedMps: 15.0, longitudinalG: 0.3, lateralG: 0.05, timestamp: t0.addingTimeInterval(1.0))
        XCTAssertEqual(sut.activeTelemetry?.peakLongitudinalG ?? 0.0, 0.95, accuracy: 0.001)
    }

    @MainActor
    func testPrematureStopAbortsSprint() {
        let t0 = Date(timeIntervalSince1970: 1000.0)
        sut.armManually()

        sut.processSample(speedMps: 2.0, longitudinalG: 0.3, lateralG: 0.0, timestamp: t0)
        XCTAssertEqual(sut.state, .sprinting)

        // 3 seconds later, speed drops to 0 without reaching 60 mph
        sut.processSample(speedMps: 0.0, longitudinalG: -0.4, lateralG: 0.0, timestamp: t0.addingTimeInterval(3.0))

        XCTAssertEqual(sut.state, .aborted, "Sprint should abort when vehicle stops prematurely before 60 mph")
    }

    @MainActor
    func testPersonalBestCalculation() {
        let record1 = SprintRecord(
            id: UUID(),
            date: Date(),
            time0To30: 2.1,
            time0To60: 4.8,
            timeQuarterMile: 13.2,
            peakLongitudinalG: 0.75
        )

        let record2 = SprintRecord(
            id: UUID(),
            date: Date(),
            time0To30: 1.8,
            time0To60: 4.1, // Faster!
            timeQuarterMile: 12.4, // Faster!
            peakLongitudinalG: 0.88
        )

        let record3 = SprintRecord(
            id: UUID(),
            date: Date(),
            time0To30: 2.5,
            time0To60: 5.5, // Slower
            timeQuarterMile: 14.0,
            peakLongitudinalG: 0.65
        )

        let activeTel = ActiveSprintTelemetry(
            startTime: Date(),
            time0To60: record1.time0To60,
            timeQuarterMile: record1.timeQuarterMile,
            peakLongitudinalG: record1.peakLongitudinalG
        )
        sut.completeSprint(telemetry: activeTel)
        XCTAssertEqual(sut.personalBest0To60?.time0To60, 4.8)

        let activeTel2 = ActiveSprintTelemetry(
            startTime: Date(),
            time0To60: record2.time0To60,
            timeQuarterMile: record2.timeQuarterMile,
            peakLongitudinalG: record2.peakLongitudinalG
        )
        sut.completeSprint(telemetry: activeTel2)
        XCTAssertEqual(sut.personalBest0To60?.time0To60, 4.1, "PB should update to faster run (4.1s)")

        let activeTel3 = ActiveSprintTelemetry(
            startTime: Date(),
            time0To60: record3.time0To60,
            timeQuarterMile: record3.timeQuarterMile,
            peakLongitudinalG: record3.peakLongitudinalG
        )
        sut.completeSprint(telemetry: activeTel3)
        XCTAssertEqual(sut.personalBest0To60?.time0To60, 4.1, "Slower run (5.5s) must not overwrite PB (4.1s)")
    }

    @MainActor
    func testManualArmAndDisarm() {
        XCTAssertEqual(sut.state, .idle)

        sut.armManually()
        XCTAssertEqual(sut.state, .staged)

        sut.disarmManually()
        XCTAssertEqual(sut.state, .idle)
    }

    @MainActor
    func testAutoArmTogglePreventsStaging() {
        sut.isAutoArmEnabled = false
        let t0 = Date(timeIntervalSince1970: 1000.0)

        sut.processSample(speedMps: 0.0, longitudinalG: 0.0, lateralG: 0.0, timestamp: t0)
        sut.processSample(speedMps: 0.0, longitudinalG: 0.0, lateralG: 0.0, timestamp: t0.addingTimeInterval(2.0))

        XCTAssertEqual(sut.state, .idle, "When auto-arm is disabled, stopping should not stage the launch timer")
    }

    @MainActor
    func testJSONExportAndPersistenceRoundtrip() throws {
        let record = SprintRecord(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1700000000),
            time0To30: 1.95,
            time0To60: 4.25,
            time0To100Kmh: 4.40,
            timeEighthMile: 8.10,
            speedEighthMileMph: 88.5,
            timeQuarterMile: 12.50,
            speedQuarterMileMph: 114.2,
            peakLongitudinalG: 0.85,
            peakLateralG: 0.12,
            notes: "Test track sunny"
        )

        let tel = ActiveSprintTelemetry(
            startTime: record.date,
            time0To30: record.time0To30,
            time0To60: record.time0To60,
            time0To100Kmh: record.time0To100Kmh,
            timeEighthMile: record.timeEighthMile,
            speedEighthMileMph: record.speedEighthMileMph,
            timeQuarterMile: record.timeQuarterMile,
            speedQuarterMileMph: record.speedQuarterMileMph,
            peakLongitudinalG: record.peakLongitudinalG,
            peakLateralG: record.peakLateralG
        )
        sut.completeSprint(telemetry: tel)

        guard let json = sut.exportJSON() else {
            XCTFail("Export JSON returned nil")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([SprintRecord].self, from: json)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].time0To60, 4.25)
        XCTAssertEqual(decoded[0].speedQuarterMileMph, 114.2)
    }

    @MainActor
    func testResetClearsActiveTelemetry() {
        sut.armManually()
        sut.processSample(speedMps: 5.0, longitudinalG: 0.5, lateralG: 0.0, timestamp: Date())
        XCTAssertEqual(sut.state, .sprinting)
        XCTAssertNotNil(sut.activeTelemetry)

        sut.reset()
        XCTAssertEqual(sut.state, .idle)
        XCTAssertNil(sut.activeTelemetry)
    }
}
