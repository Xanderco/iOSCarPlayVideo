import XCTest
import AVFoundation
import UIKit
@testable import DashCast

/// Regression tests for the 2026-11 core bug audit (Docs/Audit-2026-11.md).
final class CoreBugfixTests: XCTestCase {

    // MARK: Audio session

    func testAudioSessionCategoryIsAccepted() throws {
        // Previously `.playback` + `.allowBluetoothHFP/.allowAirPlay` made setCategory throw,
        // leaving the app on `.soloAmbient` (no background audio, muted by the silent switch).
        XCTAssertTrue(VideoPlayerService.audioSessionOptions.isEmpty)
        try VideoPlayerService.configureAudioSessionCategory()
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
        XCTAssertEqual(AVAudioSession.sharedInstance().mode, .moviePlayback)
    }

    // MARK: Player

    func testSkipTargetClamping() {
        XCTAssertEqual(VideoPlayerService.clampedSkipTarget(current: 5, delta: -10, duration: 100), 0)
        XCTAssertEqual(VideoPlayerService.clampedSkipTarget(current: 95, delta: 10, duration: 100), 100)
        XCTAssertEqual(VideoPlayerService.clampedSkipTarget(current: 50, delta: 10, duration: 100), 60)
        // Live stream (duration 0): no upper bound, never negative.
        XCTAssertEqual(VideoPlayerService.clampedSkipTarget(current: 50, delta: 10, duration: 0), 60)
        XCTAssertEqual(VideoPlayerService.clampedSkipTarget(current: 3, delta: -10, duration: 0), 0)
    }

    @MainActor
    func testPlayerSurfacesLoadFailure() async throws {
        let service = VideoPlayerService()
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).mp4")
        service.load(channel: ChannelModel(name: "Missing", streamURL: missing))
        XCTAssertNil(service.playbackError)

        let deadline = Date().addingTimeInterval(10)
        while service.playbackError == nil && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertNotNil(service.playbackError, "A failing item must surface an error instead of spinning silently")
        XCTAssertFalse(service.isPlaying)
        XCTAssertFalse(service.isBuffering)

        service.stop()
        XCTAssertNil(service.currentChannel)
        XCTAssertNil(service.playbackError)
    }

    // MARK: Local videos

    @MainActor
    func testLocalVideoImportPersistsAndSurvivesContainerMove() throws {
        let suite = "CoreBugfixTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let oldDir = root.appendingPathComponent("old")
        let newDir = root.appendingPathComponent("new")
        defer { try? FileManager.default.removeItem(at: root) }

        // Source lives in tmp (like a PhotosPicker transfer), so it is moved into the library.
        let source = oldDir.deletingLastPathComponent().appendingPathComponent("IMG_0001.MOV")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data([0, 1, 2, 3]).write(to: source)

        let manager = LocalVideoManager(videosDirectory: oldDir, defaults: defaults)
        let channel = try manager.importFile(at: source, originalName: "IMG_0001.MOV")
        XCTAssertEqual(channel.name, "IMG_0001")
        XCTAssertEqual(channel.streamURL.pathExtension, "MOV")
        XCTAssertTrue(FileManager.default.fileExists(atPath: channel.streamURL.path))
        XCTAssertEqual(manager.localVideos.count, 1)

        // Simulate an app update moving the container: the file now lives in a new folder.
        try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
        try FileManager.default.moveItem(
            at: channel.streamURL,
            to: newDir.appendingPathComponent(channel.streamURL.lastPathComponent)
        )
        let reloaded = LocalVideoManager(videosDirectory: newDir, defaults: defaults)
        XCTAssertEqual(reloaded.localVideos.count, 1)
        XCTAssertEqual(reloaded.localVideos.first?.streamURL.deletingLastPathComponent().standardizedFileURL,
                       newDir.standardizedFileURL)

        reloaded.deleteVideo(try XCTUnwrap(reloaded.localVideos.first))
        XCTAssertTrue(reloaded.localVideos.isEmpty)
        XCTAssertTrue(LocalVideoManager(videosDirectory: newDir, defaults: defaults).localVideos.isEmpty)
    }

    func testRebaseLeavesRemoteURLsAlone() {
        let remote = URL(string: "https://example.com/a.m3u8")!
        XCTAssertEqual(LocalVideoManager.rebase(remote, onto: URL(fileURLWithPath: "/x")), remote)
        let local = URL(fileURLWithPath: "/old/container/Documents/video_1.mp4")
        XCTAssertEqual(LocalVideoManager.rebase(local, onto: URL(fileURLWithPath: "/new/Documents")).path,
                       "/new/Documents/video_1.mp4")
    }

    // MARK: External display

    func testOnlyExternalDisplayRoleIsTreatedAsExternal() {
        XCTAssertTrue(ExternalDisplayManager.isExternalDisplayRole(.windowExternalDisplayNonInteractive))
        XCTAssertFalse(ExternalDisplayManager.isExternalDisplayRole(.windowApplication))
    }

    func testInfoPlistDeclaresExternalDisplaySceneAndBackgroundModes() throws {
        let info = try XCTUnwrap(Bundle(for: ExternalDisplayManager.self).infoDictionary)
        let manifest = try XCTUnwrap(info["UIApplicationSceneManifest"] as? [String: Any])
        let configs = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: Any])
        let external = try XCTUnwrap(configs["UIWindowSceneSessionRoleExternalDisplayNonInteractive"] as? [[String: Any]])
        XCTAssertEqual((external.first?["UISceneDelegateClassName"] as? String)?.hasSuffix("ExternalDisplaySceneDelegate"), true)
        let className = try XCTUnwrap(external.first?["UISceneDelegateClassName"] as? String)
        XCTAssertNotNil(NSClassFromString(className), "Scene delegate class \(className) must resolve at runtime")

        let modes = try XCTUnwrap(info["UIBackgroundModes"] as? [String])
        XCTAssertTrue(modes.contains("audio"))
        XCTAssertTrue(modes.contains("location"))
    }

    // MARK: Driving score

    @MainActor
    func testLateralAccelerationFromCourse() {
        // 72 km/h (20 m/s) turning 30°/s ≈ 10.5 m/s² lateral.
        let lateral = DrivingScorer.lateralAcceleration(speedKmh: 72, previousCourse: 0, course: 30, dt: 1)
        XCTAssertEqual(lateral, 20 * (.pi / 6), accuracy: 0.01)
        // Wrap-around 350° → 10° is a 20° change, not 340°.
        let wrapped = DrivingScorer.lateralAcceleration(speedKmh: 36, previousCourse: 350, course: 10, dt: 1)
        XCTAssertEqual(wrapped, 10 * (20 * .pi / 180), accuracy: 0.01)
    }

    @MainActor
    func testRawAccelerometerNoLongerPenalisesLandscapeMount() {
        let scorer = DrivingScorer()
        // Phone in a landscape mount: gravity reads ~1 g on x. Used to cost 3 points per sample.
        for _ in 0..<50 { scorer.analyzeGForce(x: 1.0, y: 0, z: 0) }
        XCTAssertEqual(scorer.harshCorneringCount, 0)
        XCTAssertEqual(scorer.calculateScore(), 100)
    }

    @MainActor
    func testGPSEventsAreDetectedAndDebounced() {
        let scorer = DrivingScorer()
        let t0 = Date()
        // Steady driving straight: no events.
        scorer.recordPoint(speedKmh: 60, course: 90, timestamp: t0)
        scorer.recordPoint(speedKmh: 61, course: 90, timestamp: t0.addingTimeInterval(1))
        XCTAssertEqual(scorer.calculateScore(), 100)

        // Hard stop spanning two samples (-25 km/h per second ≈ -6.9 m/s²) counts once.
        scorer.recordPoint(speedKmh: 36, course: 90, timestamp: t0.addingTimeInterval(2))
        scorer.recordPoint(speedKmh: 11, course: 90, timestamp: t0.addingTimeInterval(3))
        XCTAssertEqual(scorer.harshBrakingCount, 1)

        // Sharp turn at speed: 60 km/h, 30°/s → ~8.7 m/s².
        scorer.recordPoint(speedKmh: 60, course: 90, timestamp: t0.addingTimeInterval(10))
        scorer.recordPoint(speedKmh: 60, course: 120, timestamp: t0.addingTimeInterval(11))
        XCTAssertEqual(scorer.harshCorneringCount, 1)
        XCTAssertEqual(scorer.harshAccelerationCount, 0)

        // Slow parking-lot turn is ignored.
        scorer.recordPoint(speedKmh: 10, course: 0, timestamp: t0.addingTimeInterval(20))
        scorer.recordPoint(speedKmh: 10, course: 90, timestamp: t0.addingTimeInterval(21))
        XCTAssertEqual(scorer.harshCorneringCount, 1)
    }

    @MainActor
    func testStartTripResetsScorerAndDistance() {
        let service = DriveLocationService.shared
        DrivingScorer.shared.recordHarshEvent(.braking)
        service.startTrip()
        XCTAssertEqual(DrivingScorer.shared.calculateScore(), 100, "Events from before the trip must not count")
        XCTAssertEqual(service.distanceMeters, 0)
        XCTAssertEqual(service.currentSpeedKmh, 0)
        _ = service.endTrip()
        XCTAssertEqual(service.currentSpeedKmh, 0)
    }

    func testStaleOrInaccurateFixesAreRejected() {
        XCTAssertTrue(DriveLocationService.isUsableFix(horizontalAccuracy: 5, age: 0.5))
        XCTAssertFalse(DriveLocationService.isUsableFix(horizontalAccuracy: -1, age: 0.5))
        XCTAssertFalse(DriveLocationService.isUsableFix(horizontalAccuracy: 200, age: 0.5))
        XCTAssertFalse(DriveLocationService.isUsableFix(horizontalAccuracy: 5, age: 120))
    }
}
