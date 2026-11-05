import AVFoundation
import XCTest
@testable import DashCast

/// Plays the tiny bundled clip through the real `VideoPlayerService` — no network, no live streams.
@MainActor
final class LocalVideoPlaybackTests: XCTestCase {
    override func tearDown() async throws {
        VideoPlayerService.shared.pause()
    }

    func testTinyFixtureIsAValidOneSecondVideo() async throws {
        let asset = AVURLAsset(url: try TestSupport.tinyClipURL())
        let duration = try await asset.load(.duration).seconds
        XCTAssertEqual(duration, 1.0, accuracy: 0.25)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertEqual(videoTracks.count, 1)
        let isPlayable = try await asset.load(.isPlayable)
        XCTAssertTrue(isPlayable)
    }

    func testServiceLoadsPlaysPausesAndReportsDuration() throws {
        let service = VideoPlayerService.shared
        let channel = ChannelModel(name: "Tiny Clip", streamURL: try TestSupport.tinyClipURL(), groupTitle: "Tests")

        service.load(channel: channel)

        XCTAssertEqual(service.currentChannel?.name, "Tiny Clip")
        XCTAssertTrue(service.isPlaying)
        waitUntil("player item becomes ready") {
            service.player.currentItem?.status == .readyToPlay
        }
        waitUntil("duration is published") { service.duration > 0.5 }

        service.togglePlayPause()
        XCTAssertFalse(service.isPlaying)
        service.togglePlayPause()
        XCTAssertTrue(service.isPlaying)

        service.seek(to: 0.5)
        service.skip(seconds: -10)
        XCTAssertGreaterThanOrEqual(service.player.currentTime().seconds, 0)
    }

    func testBundledSampleVideosShipInTheApp() {
        // UI tests and the demo playlist rely on these being bundled (offline playback).
        XCTAssertNotNil(Bundle.main.url(forResource: "night_drive", withExtension: "mp4"))
        XCTAssertNotNil(Bundle.main.url(forResource: "track_lap", withExtension: "mp4"))
        XCTAssertTrue(IPTVParser.samplePlaylist.prefix(2).allSatisfy { $0.streamURL.isFileURL })
    }
}
