import XCTest
import AVFoundation
@testable import DashCast

final class MediaContainerProbeTests: XCTestCase {

    // MARK: - Container Classification

    func testClassifiesUnsupportedContainersByURLExtension() {
        let expectations: [(String, MediaContainerKind)] = [
            ("https://media.example.com/movies/film.mkv", .mkv),
            ("https://media.example.com/movies/clip.AVI", .avi),
            ("https://media.example.com/movies/demo.webm", .webm),
            ("https://media.example.com/movies/stream.flv", .flv),
            ("https://media.example.com/live/channel.ts", .ts),
            ("https://media.example.com/movies/archive.wmv", .wmv),
            ("https://media.example.com/movies/clip.ogg", .ogg)
        ]

        for (raw, expected) in expectations {
            let url = URL(string: raw)!
            let kind = MediaContainerProbe.classify(url: url)
            XCTAssertEqual(kind, expected, "Expected \(expected) for \(raw)")
            XCTAssertTrue(kind.isUnsupportedContainer)
            XCTAssertFalse(kind.isNativelySupportedByAVPlayer)
        }
    }

    func testClassifiesNativeContainersAndHLSEndpoints() {
        let expectations: [(String, MediaContainerKind)] = [
            ("https://media.example.com/movies/film.mp4", .mp4),
            ("https://media.example.com/movies/film.m4v", .m4v),
            ("https://media.example.com/movies/film.mov", .mov),
            ("https://media.example.com/live/master.m3u8", .hls),
            ("http://jf.local:8096/Videos/m2/master.m3u8?api_key=abc", .hls),
            ("http://plex.local:32400/video/:/transcode/universal/start.m3u8?protocol=hls", .hls)
        ]

        for (raw, expected) in expectations {
            let url = URL(string: raw)!
            let kind = MediaContainerProbe.classify(url: url)
            XCTAssertEqual(kind, expected, "Expected \(expected) for \(raw)")
            XCTAssertFalse(kind.isUnsupportedContainer)
            XCTAssertTrue(kind.isNativelySupportedByAVPlayer)
        }
    }

    func testClassifiesExplicitContainerAndQueryParameters() {
        let directStreamURL = URL(string: "http://jf.local:8096/Videos/m1/stream?static=true&Container=mkv&api_key=tok")!
        XCTAssertEqual(MediaContainerProbe.classify(url: directStreamURL), .mkv)

        let genericURL = URL(string: "http://jf.local:8096/Videos/m1/stream?static=true")!
        XCTAssertEqual(MediaContainerProbe.classify(url: genericURL, explicitContainer: "matroska,webm"), .mkv)
        XCTAssertEqual(MediaContainerProbe.classify(url: genericURL, explicitContainer: "mov,mp4,m4a,3gp"), .mov)
        XCTAssertEqual(MediaContainerProbe.classify(url: genericURL), .unknown)
    }

    // MARK: - Error Diagnosis

    func testDiagnosesUnsupportedContainerWithTranscodeGuidance() {
        let mkvURL = URL(string: "http://jf.local:8096/Videos/item1/stream?static=true&Container=mkv&api_key=tok")!
        let decodeError = NSError(domain: AVFoundationErrorDomain, code: AVError.fileFormatNotRecognized.rawValue)

        let withFallback = MediaContainerProbe.diagnose(
            url: mkvURL,
            error: decodeError,
            supportsServerTranscode: true
        )
        XCTAssertEqual(withFallback.container, .mkv)
        XCTAssertFalse(withFallback.isNativeContainer)
        XCTAssertTrue(withFallback.isDecodeFailure)
        XCTAssertTrue(withFallback.canOfferServerTranscode)
        XCTAssertTrue(withFallback.userFacingReason.contains("MKV"))
        XCTAssertTrue(withFallback.userFacingReason.contains("Retry via Server Transcode"))

        let withoutFallback = MediaContainerProbe.diagnose(
            url: URL(string: "https://cdn.example.com/movie.webm")!,
            error: decodeError,
            supportsServerTranscode: false
        )
        XCTAssertEqual(withoutFallback.container, .webm)
        XCTAssertFalse(withoutFallback.canOfferServerTranscode)
        XCTAssertTrue(withoutFallback.userFacingReason.contains("WebM"))
        XCTAssertTrue(withoutFallback.userFacingReason.contains("HLS"))
    }

    func testDiagnosesAVFoundationDecodeErrorOnMP4WithTranscodeOption() {
        let mp4URL = URL(string: "http://jf.local:8096/Videos/item2/stream?static=true&Container=mp4&api_key=tok")!
        let underlying = NSError(domain: NSOSStatusErrorDomain, code: -12848)
        let decodeError = NSError(
            domain: AVFoundationErrorDomain,
            code: AVError.decodeFailed.rawValue,
            userInfo: [NSUnderlyingErrorKey: underlying]
        )

        let diagnosis = MediaContainerProbe.diagnose(
            url: mp4URL,
            error: decodeError,
            supportsServerTranscode: true
        )
        XCTAssertEqual(diagnosis.container, .mp4)
        XCTAssertTrue(diagnosis.isDecodeFailure)
        XCTAssertTrue(diagnosis.canOfferServerTranscode)
        XCTAssertEqual(diagnosis.technicalCause, "avfoundation_decode_error")
    }

    func testNetworkErrorIsNotMisclassifiedAsDecodeFailure() {
        let mkvURL = URL(string: "http://jf.local:8096/Videos/item1/stream?static=true&Container=mkv&api_key=tok")!
        let netError = NSError(
            domain: AVFoundationErrorDomain,
            code: AVError.unknown.rawValue,
            userInfo: [
                NSUnderlyingErrorKey: NSError(
                    domain: NSURLErrorDomain,
                    code: NSURLErrorNotConnectedToInternet,
                    userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
                )
            ]
        )

        let diagnosis = MediaContainerProbe.diagnose(
            url: mkvURL,
            error: netError,
            supportsServerTranscode: true
        )
        XCTAssertFalse(diagnosis.isDecodeFailure)
        XCTAssertFalse(diagnosis.canOfferServerTranscode)
        XCTAssertTrue(diagnosis.userFacingReason.hasPrefix("Network error:"))
    }

    func testAlreadyHLSStreamNeverOffersRecursiveTranscode() {
        let hlsURL = URL(string: "http://jf.local:8096/Videos/item1/master.m3u8?api_key=tok")!
        let decodeError = NSError(domain: AVFoundationErrorDomain, code: AVError.decodeFailed.rawValue)

        let diagnosis = MediaContainerProbe.diagnose(
            url: hlsURL,
            error: decodeError,
            supportsServerTranscode: true
        )
        XCTAssertEqual(diagnosis.container, .hls)
        XCTAssertFalse(diagnosis.canOfferServerTranscode)
    }

    // MARK: - Server HLS Transcode URL Builders

    func testJellyfinAndEmbyHLSTranscodeURLBuilder() throws {
        let jf = MediaServerClient(
            kind: .jellyfin,
            baseURL: URL(string: "http://jf.local:8096")!,
            deviceId: "dev-1",
            accessToken: "tok-1",
            userId: "u-1"
        )
        let item = MediaItem(id: "vid-99", name: "Test", type: "Movie", container: "mp4",
                             mediaSources: [MediaSourceInfo(id: "src-99", container: "mp4")])
        let hls = try jf.hlsTranscodeURL(for: item, playSessionId: "ps-1")
        XCTAssertEqual(hls.path, "/Videos/vid-99/master.m3u8")
        let items = URLComponents(url: hls, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "MediaSourceId" })?.value, "src-99")
        XCTAssertEqual(items.first(where: { $0.name == "PlaySessionId" })?.value, "ps-1")
        XCTAssertEqual(items.first(where: { $0.name == "api_key" })?.value, "tok-1")
        XCTAssertNil(items.first(where: { $0.name == "static" }))
    }

    func testPlexHLSTranscodeURLBuilder() throws {
        let url = try XCTUnwrap(MediaServerClient.plexHLSTranscodeURL(
            baseURL: URL(string: "https://plex.example.com:32400/")!,
            ratingKey: "4242",
            token: "plex-tok",
            deviceId: "iphone-1"
        ))
        XCTAssertEqual(url.path, "/video/:/transcode/universal/start.m3u8")
        let q = Dictionary(
            uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
                .compactMap { item in item.value.map { (item.name, $0) } }
        )
        XCTAssertEqual(q["path"], "/library/metadata/4242")
        XCTAssertEqual(q["protocol"], "hls")
        XCTAssertEqual(q["directPlay"], "0")
        XCTAssertEqual(q["directStream"], "1")
        XCTAssertEqual(q["X-Plex-Client-Identifier"], "iphone-1")
        XCTAssertEqual(q["X-Plex-Token"], "plex-tok")
    }

    func testDerivesHLSTranscodeFromDirectStreamURLs() throws {
        let embyDirect = URL(string: "https://media.home/emby/Videos/abc/stream?static=true&Container=mkv&MediaSourceId=ms1&DeviceId=d1&api_key=k1")!
        let embyHLS = try XCTUnwrap(MediaServerClient.hlsTranscodeURL(fromDirectStreamURL: embyDirect))
        XCTAssertEqual(embyHLS.path, "/emby/Videos/abc/master.m3u8")
        let embyQ = URLComponents(url: embyHLS, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertNil(embyQ.first(where: { $0.name == "static" }))
        XCTAssertNil(embyQ.first(where: { $0.name == "Container" }))
        XCTAssertEqual(embyQ.first(where: { $0.name == "api_key" })?.value, "k1")

        let plexDirect = URL(string: "http://plex.local:32400/library/metadata/777?X-Plex-Token=ptok")!
        let plexHLS = try XCTUnwrap(MediaServerClient.hlsTranscodeURL(fromDirectStreamURL: plexDirect, deviceId: "dev-9"))
        XCTAssertEqual(plexHLS.path, "/video/:/transcode/universal/start.m3u8")

        // Already HLS -> nil
        XCTAssertNil(MediaServerClient.hlsTranscodeURL(fromDirectStreamURL: embyHLS))
        XCTAssertNil(MediaServerClient.hlsTranscodeURL(fromDirectStreamURL: plexHLS))
    }

    // MARK: - VideoPlayerService Fallback Flow

    @MainActor
    func testVideoPlayerServiceOffersAndRetriesServerTranscodeOnFailure() async throws {
        let service = VideoPlayerService()
        let tempMKV = FileManager.default.temporaryDirectory
            .appendingPathComponent("probe-test-\(UUID().uuidString).mkv")
        try Data("not-a-valid-mkv-payload".utf8).write(to: tempMKV)
        defer { try? FileManager.default.removeItem(at: tempMKV) }

        let fallbackHLS = URL(string: "http://jf.local:8096/Videos/m99/master.m3u8?MediaSourceId=m99&DeviceId=d1&api_key=tok")!
        let channel = ChannelModel(id: "mediaserver-test-m99", name: "Test MKV", streamURL: tempMKV, groupTitle: "Home")

        service.load(channel: channel, transcodeFallbackURL: fallbackHLS)
        XCTAssertEqual(service.transcodeFallbackURL, fallbackHLS)
        XCTAssertFalse(service.canRetryViaServerTranscode, "Button stays hidden until playback fails")

        let deadline = Date().addingTimeInterval(10)
        while service.playbackError == nil && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertNotNil(service.playbackError)
        XCTAssertEqual(service.probeResult?.container, .mkv)
        XCTAssertTrue(service.canRetryViaServerTranscode)

        let retried = service.retryViaServerTranscode()
        XCTAssertTrue(retried)
        XCTAssertEqual(service.currentChannel?.id, channel.id)
        XCTAssertEqual(service.currentChannel?.streamURL, fallbackHLS)
        XCTAssertNil(service.transcodeFallbackURL)
        XCTAssertNil(service.playbackError)

        service.stop()
    }
}
