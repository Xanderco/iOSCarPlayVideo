import XCTest
import AVFoundation
@testable import DashCast

@MainActor
final class PlaybackResumeTests: XCTestCase {

    private func makeStore(maxEntries: Int = PlaybackResumeStore.defaultMaxEntries) throws -> (PlaybackResumeStore, UserDefaults, String) {
        let suite = "PlaybackResumeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = PlaybackResumeStore(defaults: defaults, maxEntries: maxEntries)
        return (store, defaults, suite)
    }

    func testSavesAndRestoresVODStreamPosition() throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let vod = ChannelModel(
            name: "Road Documentary",
            streamURL: URL(string: "https://example.com/movies/road_doc.mp4")!
        )

        store.savePosition(125.5, duration: 600, for: vod)
        let restored = try XCTUnwrap(store.resumePosition(for: vod))
        XCTAssertEqual(restored, 125.5, accuracy: 0.01)

        // Survives re-initialization with the same UserDefaults suite.
        let reloaded = PlaybackResumeStore(defaults: defaults)
        let reloadedPos = try XCTUnwrap(reloaded.resumePosition(for: vod))
        XCTAssertEqual(reloadedPos, 125.5, accuracy: 0.01)
    }

    func testLocalVideoKeySurvivesContainerMove() throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let oldPath = ChannelModel(
            id: "local-1",
            name: "Track Day",
            streamURL: URL(fileURLWithPath: "/var/mobile/Containers/A/Documents/video_123.mp4")
        )
        let movedPath = ChannelModel(
            id: "local-1",
            name: "Track Day",
            streamURL: URL(fileURLWithPath: "/var/mobile/Containers/B/Documents/video_123.mp4")
        )

        store.savePosition(42.0, duration: 120.0, for: oldPath)
        let restored = try XCTUnwrap(store.resumePosition(for: movedPath))
        XCTAssertEqual(restored, 42.0, accuracy: 0.01)
    }

    func testAutoClearsAtOrAboveNinetyFivePercentCompletion() throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let vod = ChannelModel(
            name: "Feature Film",
            streamURL: URL(string: "https://example.com/film.mp4")!
        )

        // Just below 95% (94.9%) stays saved.
        store.savePosition(94.9, duration: 100.0, for: vod)
        XCTAssertEqual(try XCTUnwrap(store.resumePosition(for: vod)), 94.9, accuracy: 0.01)

        // Exactly 95.0% clears the entry.
        store.savePosition(95.0, duration: 100.0, for: vod)
        XCTAssertNil(store.resumePosition(for: vod))
        XCTAssertTrue(store.entries.isEmpty)

        // Above 95% (99% / 100%) also stays cleared.
        store.savePosition(60.0, duration: 100.0, for: vod)
        XCTAssertNotNil(store.resumePosition(for: vod))
        store.savePosition(100.0, duration: 100.0, for: vod)
        XCTAssertNil(store.resumePosition(for: vod))
    }

    func testLiveStreamsAndInvalidDurationsAreIgnored() throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let live = ChannelModel(
            name: "Live News 24",
            streamURL: URL(string: "https://example.com/live/news.m3u8")!
        )

        store.savePosition(180.0, duration: 0, for: live)
        XCTAssertNil(store.resumePosition(for: live))

        store.savePosition(180.0, duration: -10, for: live)
        XCTAssertNil(store.resumePosition(for: live))

        store.savePosition(180.0, duration: .infinity, for: live)
        XCTAssertNil(store.resumePosition(for: live))

        store.savePosition(180.0, duration: .nan, for: live)
        XCTAssertNil(store.resumePosition(for: live))

        XCTAssertTrue(store.entries.isEmpty)
    }

    func testCarPlayMirrorChannelIsIgnored() throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let mirror = ChannelModel(
            id: CarPlayMirrorPlayback.channelID,
            name: "iPhone Screen",
            streamURL: URL(string: "http://127.0.0.1:8099/live.m3u8")!
        )

        store.savePosition(30, duration: 100, for: mirror)
        XCTAssertNil(store.resumePosition(for: mirror))
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testZeroOrNegativePositionClearsExistingEntry() throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let vod = ChannelModel(
            name: "Episode 1",
            streamURL: URL(string: "https://example.com/ep1.mp4")!
        )

        store.savePosition(45, duration: 300, for: vod)
        XCTAssertNotNil(store.resumePosition(for: vod))

        store.savePosition(0, duration: 300, for: vod)
        XCTAssertNil(store.resumePosition(for: vod))
    }

    func testEvictsOldestEntriesBeyondMaxEntries() throws {
        let (store, defaults, suite) = try makeStore(maxEntries: 2)
        defer { defaults.removePersistentDomain(forName: suite) }

        let t0 = Date(timeIntervalSince1970: 1_000)
        let ch1 = ChannelModel(name: "One", streamURL: URL(string: "https://example.com/1.mp4")!)
        let ch2 = ChannelModel(name: "Two", streamURL: URL(string: "https://example.com/2.mp4")!)
        let ch3 = ChannelModel(name: "Three", streamURL: URL(string: "https://example.com/3.mp4")!)

        store.savePosition(10, duration: 100, for: ch1, now: t0)
        store.savePosition(20, duration: 100, for: ch2, now: t0.addingTimeInterval(10))
        store.savePosition(30, duration: 100, for: ch3, now: t0.addingTimeInterval(20))

        XCTAssertNil(store.resumePosition(for: ch1), "Oldest entry should be evicted")
        XCTAssertNotNil(store.resumePosition(for: ch2))
        XCTAssertNotNil(store.resumePosition(for: ch3))
    }

    func testClearAllRemovesAllSavedEntries() throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let ch1 = ChannelModel(name: "One", streamURL: URL(string: "https://example.com/1.mp4")!)
        let ch2 = ChannelModel(name: "Two", streamURL: URL(string: "https://example.com/2.mp4")!)
        store.savePosition(10, duration: 100, for: ch1)
        store.savePosition(20, duration: 100, for: ch2)

        store.clearAll()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertNil(PlaybackResumeStore(defaults: defaults).resumePosition(for: ch1))
    }

    func testVideoPlayerServiceAutoResumesBundledDemoVideo() async throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let demo = try XCTUnwrap(IPTVParser.samplePlaylist.first)
        let service = VideoPlayerService(resumeStore: store)
        service.load(channel: demo)

        let probeDeadline = Date().addingTimeInterval(10)
        while service.duration <= 0 && Date() < probeDeadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let mediaDuration = service.duration
        XCTAssertGreaterThan(mediaDuration, 0)
        service.stop()

        // Save at 40% of the real bundled duration, well below the 95% clear threshold.
        let targetResume = mediaDuration * 0.4
        store.savePosition(targetResume, duration: mediaDuration, for: demo)

        let resumedService = VideoPlayerService(resumeStore: store)
        resumedService.load(channel: demo)

        let resumeDeadline = Date().addingTimeInterval(10)
        while (resumedService.duration <= 0 || resumedService.player.currentTime().seconds < targetResume * 0.8) && Date() < resumeDeadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertGreaterThanOrEqual(resumedService.player.currentTime().seconds, targetResume * 0.8)

        resumedService.stop()
        let savedAfterStop = try XCTUnwrap(store.resumePosition(for: demo))
        XCTAssertGreaterThanOrEqual(savedAfterStop, targetResume * 0.8)
    }

    func testPiPActivePreventsBackgroundVideoLayerDetachment() throws {
        let (store, defaults, suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = VideoPlayerService(resumeStore: store)
        XCTAssertTrue(service.isVideoLayerAttached)

        // When PiP is active, entering background must keep the layer attached.
        service.setPictureInPictureActive(true, isInBackground: false)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertTrue(service.isVideoLayerAttached)

        // When PiP stops while still in the background, the layer detaches cleanly.
        service.setPictureInPictureActive(false, isInBackground: true)
        XCTAssertFalse(service.isVideoLayerAttached)

        // Returning to foreground reattaches the layer.
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertTrue(service.isVideoLayerAttached)
    }

    func testPictureInPictureCoordinatorDetachWithoutLayerIsSafe() {
        let coordinator = PictureInPictureCoordinator()
        let layer = AVPlayerLayer()
        coordinator.detach(playerLayer: layer)
        XCTAssertFalse(coordinator.isActive)
        XCTAssertFalse(coordinator.isPossible)
    }
}
