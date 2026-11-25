import XCTest
@testable import DashCast

final class IncidentDashCamEngineTests: XCTestCase {

    private func makeTempSandboxDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DashCamTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "com.xanderco.dashcast.dashcam-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - Deceleration Threshold Math

    func testDecelerationFromSpeedDeltaCalculation() {
        // 100 km/h -> 60 km/h in 1.5s => deltaV = 40/3.6 = 11.111 m/s => a = 7.407 m/s^2 => 0.755G
        let hardG = IncidentTriggerPolicy.decelerationFromSpeedDelta(
            previousSpeedKmh: 100,
            currentSpeedKmh: 60,
            dt: 1.5
        )
        XCTAssertEqual(hardG, 0.755, accuracy: 0.01)
        XCTAssertGreaterThan(hardG, IncidentTriggerPolicy.standardDecelerationThresholdG)

        // Gentle braking: 100 km/h -> 90 km/h in 3.0s => ~0.094G
        let gentleG = IncidentTriggerPolicy.decelerationFromSpeedDelta(
            previousSpeedKmh: 100,
            currentSpeedKmh: 90,
            dt: 3.0
        )
        XCTAssertEqual(gentleG, 0.094, accuracy: 0.01)
        XCTAssertLessThan(gentleG, IncidentTriggerPolicy.standardDecelerationThresholdG)

        // Acceleration (speed increase) must yield 0 deceleration
        let accelG = IncidentTriggerPolicy.decelerationFromSpeedDelta(
            previousSpeedKmh: 40,
            currentSpeedKmh: 85,
            dt: 2.0
        )
        XCTAssertEqual(accelG, 0)

        // Invalid or stale time deltas must return 0 safely
        XCTAssertEqual(
            IncidentTriggerPolicy.decelerationFromSpeedDelta(previousSpeedKmh: 80, currentSpeedKmh: 0, dt: 0.01),
            0
        )
        XCTAssertEqual(
            IncidentTriggerPolicy.decelerationFromSpeedDelta(previousSpeedKmh: 80, currentSpeedKmh: 0, dt: 8.0),
            0
        )
    }

    func testEffectiveDecelerationCombinesMotionAndGPS() {
        let magnitude = IncidentTriggerPolicy.userAccelerationMagnitudeG(x: 0.3, y: 0.4, z: 0.5)
        XCTAssertEqual(magnitude, sqrt(0.5), accuracy: 0.001) // ~0.707G

        let combinedMotionWin = IncidentTriggerPolicy.effectiveDecelerationG(
            userAccelerationG: (x: 0.3, y: 0.4, z: 0.5),
            gpsDecelerationG: 0.25
        )
        XCTAssertEqual(combinedMotionWin, magnitude, accuracy: 0.001)

        let combinedGpsWin = IncidentTriggerPolicy.effectiveDecelerationG(
            userAccelerationG: (x: 0.1, y: 0.1, z: 0.1),
            gpsDecelerationG: 0.78
        )
        XCTAssertEqual(combinedGpsWin, 0.78, accuracy: 0.001)
    }

    func testGShockTriggerStrictThresholdAndCooldown() {
        let now = Date()

        // Strictly > 0.6G required: 0.60G must NOT trigger
        XCTAssertFalse(
            IncidentTriggerPolicy.shouldTriggerIncident(
                decelerationG: 0.60,
                thresholdG: 0.60,
                lastTriggerTime: nil,
                now: now
            )
        )

        // 0.61G DOES trigger
        XCTAssertTrue(
            IncidentTriggerPolicy.shouldTriggerIncident(
                decelerationG: 0.61,
                thresholdG: 0.60,
                lastTriggerTime: nil,
                now: now
            )
        )

        // Within 15s cooldown: blocked
        XCTAssertFalse(
            IncidentTriggerPolicy.shouldTriggerIncident(
                decelerationG: 0.95,
                thresholdG: 0.60,
                lastTriggerTime: now,
                now: now.addingTimeInterval(14.9),
                cooldown: 15.0
            )
        )

        // After 15s cooldown: allowed
        XCTAssertTrue(
            IncidentTriggerPolicy.shouldTriggerIncident(
                decelerationG: 0.95,
                thresholdG: 0.60,
                lastTriggerTime: now,
                now: now.addingTimeInterval(15.0),
                cooldown: 15.0
            )
        )
    }

    // MARK: - Rolling 60s Circular Buffer Retention

    func testRollingBufferRetentionPrunesBeyond60Seconds() {
        var buffer = RollingSegmentBuffer(windowSeconds: 60.0)
        let origin = Date(timeIntervalSince1970: 1_700_000_000)

        var totalExpired: [DashCamSegment] = []
        // Append 9 consecutive 10s segments (90s total)
        for index in 0..<9 {
            let start = origin.addingTimeInterval(Double(index) * 10.0)
            let end = start.addingTimeInterval(10.0)
            let seg = DashCamSegment(
                filename: "seg-\(index).mp4",
                startTime: start,
                endTime: end,
                peakDecelerationG: 0.12,
                peakSpeedKmh: 70
            )
            let expired = buffer.append(seg)
            totalExpired.append(contentsOf: expired)
        }

        // Segments 0, 1, 2 (0..30s) should be expired; segments 3..8 (30..90s = 60s) retained
        XCTAssertEqual(totalExpired.map(\.filename), ["seg-0.mp4", "seg-1.mp4", "seg-2.mp4"])
        XCTAssertEqual(buffer.segments.map(\.filename), [
            "seg-3.mp4", "seg-4.mp4", "seg-5.mp4", "seg-6.mp4", "seg-7.mp4", "seg-8.mp4"
        ])
        XCTAssertEqual(buffer.totalBufferedDuration, 60.0, accuracy: 0.001)
    }

    func testSnapshotSegmentsAroundTriggerReturnsChronologicalWindow() {
        var buffer = RollingSegmentBuffer(windowSeconds: 60.0)
        let origin = Date(timeIntervalSince1970: 1_700_000_000)

        for index in 0..<7 {
            let start = origin.addingTimeInterval(Double(index) * 10.0)
            let end = start.addingTimeInterval(10.0)
            buffer.append(
                DashCamSegment(
                    filename: "seg-\(index).mp4",
                    startTime: start,
                    endTime: end
                )
            )
        }

        let triggerTime = origin.addingTimeInterval(65.0)
        let snapshot = buffer.snapshotSegments(around: triggerTime)
        // Window is [5s, 65s], overlapping seg-1 (10..20) .. seg-6 (60..70)
        XCTAssertEqual(snapshot.count, 6)
        XCTAssertEqual(snapshot.first?.filename, "seg-1.mp4")
        XCTAssertEqual(snapshot.last?.filename, "seg-6.mp4")
    }

    // MARK: - Watermark Formatting & Local Sandbox Archiving

    func testWindshieldTelemetryWatermarkFormatting() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let kmhText = WindshieldTelemetryOverlay.formatWatermark(
            speedKmh: 92.4,
            decelerationG: 0.78,
            useMilesPerHour: false,
            timestamp: date
        )
        XCTAssertTrue(kmhText.contains("92 KM/H"))
        XCTAssertTrue(kmhText.contains("0.78 G"))

        let mphText = WindshieldTelemetryOverlay.formatWatermark(
            speedKmh: 100.0,
            decelerationG: 0.65,
            useMilesPerHour: true,
            timestamp: date
        )
        XCTAssertTrue(mphText.contains("62 MPH"))
        XCTAssertTrue(mphText.contains("0.65 G"))
    }

    @MainActor
    func testEngineIngestsSpeedDropArchivesToSandboxAndRespectsLocks() async throws {
        let sandbox = try makeTempSandboxDirectory()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let defaults = makeIsolatedDefaults()
        var currentTime = Date(timeIntervalSince1970: 1_700_000_000)

        let engine = IncidentDashCamEngine(
            defaults: defaults,
            sandboxRootDirectory: sandbox,
            now: { currentTime }
        )

        engine.setDecelerationThresholdG(0.6)
        XCTAssertEqual(engine.decelerationThresholdG, 0.6, accuracy: 0.001)

        engine.arm(useMilesPerHour: false)
        XCTAssertTrue(engine.isArmed)

        // Feed normal cruise telemetry: 95 km/h -> 94 km/h over 1s (no trigger)
        engine.ingestTelemetry(speedKmh: 95.0, timestamp: currentTime)
        currentTime = currentTime.addingTimeInterval(1.0)
        engine.ingestTelemetry(speedKmh: 94.0, timestamp: currentTime)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(engine.archivedClips.count, 0)

        // Feed hard braking: 94 km/h -> 50 km/h in 1.2s (~1.04G > 0.6G)
        currentTime = currentTime.addingTimeInterval(1.2)
        engine.ingestTelemetry(speedKmh: 50.0, timestamp: currentTime)

        // Wait briefly for async archive Task triggered by ingestTelemetry
        for _ in 0..<20 {
            if !engine.archivedClips.isEmpty { break }
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertEqual(engine.archivedClips.count, 1)
        let saved = try XCTUnwrap(engine.archivedClips.first)
        XCTAssertEqual(saved.triggerReason, .gShockDeceleration)
        XCTAssertGreaterThan(saved.peakDecelerationG, 0.6)
        XCTAssertTrue(FileManager.default.fileExists(atPath: engine.clipURL(for: saved).path))

        // Lock clip and verify persistence across reload
        engine.toggleLock(clipID: saved.id)
        XCTAssertTrue(engine.archivedClips.first?.isLocked == true)

        let reloaded = IncidentDashCamEngine(
            defaults: defaults,
            sandboxRootDirectory: sandbox,
            now: { currentTime }
        )
        XCTAssertEqual(reloaded.archivedClips.count, 1)
        XCTAssertTrue(reloaded.archivedClips.first?.isLocked == true)

        // Delete clip removes both record and file on disk
        let filePath = reloaded.clipURL(for: saved).path
        reloaded.deleteClip(clipID: saved.id)
        XCTAssertTrue(reloaded.archivedClips.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))

        engine.disarm()
        XCTAssertFalse(engine.isArmed)
    }

    @MainActor
    func testRollingSegmentDiskPruningOnEngine() throws {
        let sandbox = try makeTempSandboxDirectory()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let defaults = makeIsolatedDefaults()
        let origin = Date(timeIntervalSince1970: 1_700_000_000)
        let engine = IncidentDashCamEngine(
            defaults: defaults,
            sandboxRootDirectory: sandbox,
            now: { origin }
        )

        let rollingDir = sandbox.appendingPathComponent("RollingBuffer", isDirectory: true)
        var createdURLs: [URL] = []

        for index in 0..<8 {
            let fileURL = rollingDir.appendingPathComponent("seg-\(index).mp4")
            try Data("mock-video-\(index)".utf8).write(to: fileURL)
            createdURLs.append(fileURL)
            let start = origin.addingTimeInterval(Double(index) * 10.0)
            engine.recordCompletedSegment(
                fileURL: fileURL,
                startTime: start,
                endTime: start.addingTimeInterval(10.0),
                peakDecelerationG: 0.1,
                peakSpeedKmh: 60.0
            )
        }

        // Segments 0 and 1 (0..20s) should be pruned from disk; segments 2..7 (20..80s = 60s) must remain
        XCTAssertFalse(FileManager.default.fileExists(atPath: createdURLs[0].path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: createdURLs[1].path))
        for index in 2..<8 {
            XCTAssertTrue(FileManager.default.fileExists(atPath: createdURLs[index].path))
        }
        XCTAssertEqual(engine.bufferedSegmentCount, 6)
        XCTAssertEqual(engine.bufferedSeconds, 60.0, accuracy: 0.001)
    }
}
