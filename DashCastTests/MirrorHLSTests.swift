import XCTest
import VideoToolbox
@testable import DashCast

/// ADR-002 §7.5: iPhone screen → H.264 → low-latency HLS → system player on the CarPlay screen.
final class MirrorHLSTests: XCTestCase {

    // MARK: Routes

    func testRoutesParseHLSPaths() {
        XCTAssertEqual(MirrorHLS.route(forPath: "/hls/live.m3u8"), .playlist)
        XCTAssertEqual(MirrorHLS.route(forPath: "/hls/init.mp4"), .initSegment)
        XCTAssertEqual(MirrorHLS.route(forPath: "/hls/seg42.m4s"), .segment(42))
        XCTAssertEqual(MirrorHLS.route(forPath: "/hls/seg.m4s"), .notHLS)
        XCTAssertEqual(MirrorHLS.route(forPath: "/hls/segx1.m4s"), .notHLS)
        XCTAssertEqual(MirrorHLS.route(forPath: "/stream"), .notHLS)
        XCTAssertEqual(MirrorHLS.route(forPath: "/"), .notHLS)
    }

    func testRouteFromRawRequestIgnoresQuery() {
        let request = Data("GET /hls/live.m3u8?_HLS_msn=3 HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n".utf8)
        XCTAssertEqual(MirrorHLS.route(forRequest: request), .playlist)
        XCTAssertEqual(MirrorHLS.route(forRequest: Data("POST /hls/live.m3u8 HTTP/1.1\r\n\r\n".utf8)), .notHLS)
    }

    func testPlaylistURLIsLoopbackOnMirrorPort() {
        XCTAssertEqual(MirrorHLS.playlistURL().absoluteString, "http://127.0.0.1:\(CarCastShared.mirrorPort)/hls/live.m3u8")
    }

    // MARK: Playlist

    func testLivePlaylistFormat() {
        let text = HLSPlaylistBuilder.livePlaylist(segments: [(5, 1.0), (6, 1.034)], targetDuration: 1)
        let lines = text.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.first, "#EXTM3U")
        XCTAssertTrue(lines.contains("#EXT-X-VERSION:7"))
        XCTAssertTrue(lines.contains("#EXT-X-TARGETDURATION:2"), "target = ceil(longest segment)")
        XCTAssertTrue(lines.contains("#EXT-X-MEDIA-SEQUENCE:5"))
        XCTAssertTrue(lines.contains("#EXT-X-MAP:URI=\"init.mp4\""))
        XCTAssertTrue(lines.contains("#EXTINF:1.034,"))
        XCTAssertEqual(lines.last, "seg6.m4s")
        XCTAssertFalse(text.contains("#EXT-X-ENDLIST"), "live playlist must not end")
    }

    func testStoreSlidesWindowAndServesSegments() {
        let store = HLSSegmentStore(window: 3, targetDuration: 1)
        XCTAssertNil(store.playlist(), "not ready without init + segment")
        store.setInitSegment(Data([1, 2, 3]))
        XCTAssertNil(store.playlist())
        for index in 0..<5 { store.append(Data([UInt8(index)]), duration: 1) }
        XCTAssertTrue(store.isReady)
        XCTAssertEqual(store.sequences, [2, 3, 4])
        XCTAssertNil(store.segment(1))
        XCTAssertEqual(store.segment(4)?.data, Data([4]))
        XCTAssertTrue(store.playlist()?.contains("#EXT-X-MEDIA-SEQUENCE:2") ?? false)
    }

    func testStoreReplacesInvalidDurationAndKeepsSequenceAfterReset() {
        let store = HLSSegmentStore(window: 2, targetDuration: 1)
        store.setInitSegment(Data([0]))
        XCTAssertEqual(store.append(Data(), duration: .nan), 0)
        XCTAssertEqual(store.segment(0)?.duration, 1)
        store.reset()
        XCTAssertFalse(store.isReady)
        XCTAssertEqual(store.append(Data(), duration: 1), 1, "media sequence never goes back")
    }

    func testServerResponses() throws {
        let store = HLSSegmentStore(window: 2, targetDuration: 1)
        XCTAssertNil(MirrorHLS.response(for: .notHLS, store: store))
        let notReady = try XCTUnwrap(MirrorHLS.response(for: .playlist, store: store))
        XCTAssertTrue(String(decoding: notReady, as: UTF8.self).hasPrefix("HTTP/1.1 404"))

        store.setInitSegment(Data([9]))
        store.append(Data([7]), duration: 1)
        let playlist = String(decoding: try XCTUnwrap(MirrorHLS.response(for: .playlist, store: store)), as: UTF8.self)
        XCTAssertTrue(playlist.hasPrefix("HTTP/1.1 200 OK"))
        XCTAssertTrue(playlist.contains("Content-Type: application/vnd.apple.mpegurl"))
        let segment = String(decoding: try XCTUnwrap(MirrorHLS.response(for: .segment(0), store: store)), as: UTF8.self)
        XCTAssertTrue(segment.contains("Content-Type: video/iso.segment"))
    }

    // MARK: Encoder config

    func testEncoderConfigIsLowLatency720p30() {
        let config = MirrorEncoderConfig.carPlay
        XCTAssertEqual(config.framesPerSecond, 30)
        XCTAssertEqual(config.maxKeyFrameInterval, 30, "one keyframe per 1 s segment")
        XCTAssertEqual(config.segmentDurationSeconds, 1)
        let props = config.compressionProperties
        XCTAssertEqual(props[kVTCompressionPropertyKey_RealTime as String] as? Bool, true)
        XCTAssertEqual(props[kVTCompressionPropertyKey_AllowFrameReordering as String] as? Bool, false)
        XCTAssertEqual(props[kVTCompressionPropertyKey_AverageBitRate as String] as? Int, 3_000_000)
        XCTAssertEqual(props[kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration as String] as? Double, 1)
        XCTAssertEqual(config.encoderSpecification[kVTVideoEncoderSpecification_EnableLowLatencyRateControl as String] as? Bool, true)
        XCTAssertLessThan(config.estimatedWindowBytes, 5_000_000, "segment window must stay far below the 50 MB extension limit")
    }

    func testOutputSizeKeepsAspectEvenAndWithin720p() {
        let config = MirrorEncoderConfig.carPlay
        let portrait = config.outputSize(sourceWidth: 1179, sourceHeight: 2556)
        XCTAssertLessThanOrEqual(portrait.height, 1280)
        XCTAssertLessThanOrEqual(portrait.width, 720)
        XCTAssertEqual(portrait.width % 2, 0)
        XCTAssertEqual(portrait.height % 2, 0)
        XCTAssertEqual(Double(portrait.width) / Double(portrait.height), 1179.0 / 2556.0, accuracy: 0.01)

        let landscape = config.outputSize(sourceWidth: 2556, sourceHeight: 1179)
        XCTAssertLessThanOrEqual(landscape.width, 1280)
        XCTAssertLessThanOrEqual(landscape.height, 720)

        let small = config.outputSize(sourceWidth: 640, sourceHeight: 360)
        XCTAssertEqual(small.width, 640, "never upscale")
        XCTAssertEqual(small.height, 360)
        XCTAssertEqual(config.outputSize(sourceWidth: 0, sourceHeight: 100).width, 0)
    }

    // MARK: Parked-only playback decision

    func testMirrorPlaybackDecisionIsParkedOnly() {
        var live = BroadcastStatus.idle
        live.state = .live
        XCTAssertEqual(CarPlayMirrorPlayback.decide(mirrorEnabled: true, broadcast: live, vehicleMoving: true), .vehicleMoving)
        XCTAssertEqual(CarPlayMirrorPlayback.decide(mirrorEnabled: false, broadcast: live, vehicleMoving: false), .mirrorDisabled)
        XCTAssertEqual(CarPlayMirrorPlayback.decide(mirrorEnabled: true, broadcast: .idle, vehicleMoving: false), .notBroadcasting)
        XCTAssertEqual(CarPlayMirrorPlayback.decide(mirrorEnabled: true, broadcast: live, vehicleMoving: false), .play(MirrorHLS.playlistURL()))
    }
}
