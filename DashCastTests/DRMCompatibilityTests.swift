import XCTest
@testable import DashCast

final class DRMCompatibilityTests: XCTestCase {

    var inspector: DRMCompatibilityInspector!

    override func setUp() {
        super.setUp()
        inspector = DRMCompatibilityInspector.shared
    }

    // MARK: - 1. Clean / Compatible Streams

    func testDirectHLSStreamInspection() {
        let urlString = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        let result = inspector.inspect(urlString: urlString)

        XCTAssertEqual(result.streamType, .hlsDirect)
        XCTAssertTrue(result.isCarPlayCompatible)
        XCTAssertFalse(result.detectedCodecs.isEmpty)
        XCTAssertTrue(result.drmProtectionDescription.contains("Clean") || result.drmProtectionDescription.contains("None"))
        XCTAssertTrue(result.resolutionRecommendation.contains("Ready to cast"))
    }

    func testProgressiveMP4StreamInspection() {
        let urlString = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        let result = inspector.inspect(urlString: urlString)

        XCTAssertEqual(result.streamType, .progressive)
        XCTAssertTrue(result.isCarPlayCompatible)
        XCTAssertTrue(result.detectedCodecs.contains(where: { $0.contains("H.264") }))
    }

    func testPersonalMediaServerInspection() {
        let urlString = "http://192.168.1.100:8096/videos/48291/stream.m3u8?api_key=abcdef12345"
        let result = inspector.inspect(urlString: urlString)

        XCTAssertEqual(result.streamType, .mediaServer)
        XCTAssertTrue(result.isCarPlayCompatible)
        XCTAssertTrue(result.technicalSummary.contains("personal media server"))
    }

    // MARK: - 2. Commercial DRM Detection

    func testCommercialDRMDomainsDetected() {
        let netflixUrl = "https://www.netflix.com/watch/80057281"
        let netflixResult = inspector.inspect(urlString: netflixUrl)
        XCTAssertEqual(netflixResult.streamType, .restrictedService)
        XCTAssertFalse(netflixResult.isCarPlayCompatible)
        XCTAssertTrue(netflixResult.drmProtectionDescription.contains("Netflix"))

        let disneyUrl = "https://www.disneyplus.com/video/99120391"
        let disneyResult = inspector.inspect(urlString: disneyUrl)
        XCTAssertEqual(disneyResult.streamType, .restrictedService)
        XCTAssertFalse(disneyResult.isCarPlayCompatible)
        XCTAssertTrue(disneyResult.drmProtectionDescription.contains("Disney+"))

        let primeUrl = "https://www.primevideo.com/detail/0T4X3K2J"
        let primeResult = inspector.inspect(urlString: primeUrl)
        XCTAssertEqual(primeResult.streamType, .restrictedService)
        XCTAssertFalse(primeResult.isCarPlayCompatible)
    }

    func testFairPlayKeyDeliveryParametersDetected() {
        let fpsUrl = "https://stream.example.com/live/hls.m3u8?keyformat=com.apple.streamingkeydelivery&cert=123"
        let result = inspector.inspect(urlString: fpsUrl)

        XCTAssertEqual(result.streamType, .fairPlayDRM)
        XCTAssertFalse(result.isCarPlayCompatible)
        XCTAssertTrue(result.drmProtectionDescription.contains("FairPlay"))
        XCTAssertTrue(result.educationalNotice.contains("Apple restricts CarPlay"))
    }

    func testWidevineParametersDetected() {
        let widevineUrl = "https://stream.example.com/manifest.mpd?widevine=true"
        let result = inspector.inspect(urlString: widevineUrl)

        XCTAssertEqual(result.streamType, .widevineDRM)
        XCTAssertFalse(result.isCarPlayCompatible)
        XCTAssertTrue(result.drmProtectionDescription.contains("Widevine"))
    }

    // MARK: - 3. Unsupported Formats & Errors

    func testUnsupportedContainerFormat() {
        let mkvUrl = "https://media.example.com/movie.mkv"
        let result = inspector.inspect(urlString: mkvUrl)

        XCTAssertEqual(result.streamType, .unsupportedFormat)
        XCTAssertFalse(result.isCarPlayCompatible)
        XCTAssertTrue(result.technicalSummary.contains("MKV"))

        let webmUrl = "https://media.example.com/clip.webm"
        let webmResult = inspector.inspect(urlString: webmUrl)
        XCTAssertEqual(webmResult.streamType, .unsupportedFormat)
        XCTAssertFalse(webmResult.isCarPlayCompatible)
    }

    func testInvalidURLHandling() {
        let invalid = "not a valid url here"
        let result = inspector.inspect(urlString: invalid)

        XCTAssertEqual(result.streamType, .unknown)
        XCTAssertFalse(result.isCarPlayCompatible)
        XCTAssertTrue(result.drmProtectionDescription.contains("Invalid"))
    }

    // MARK: - 4. Reference Sample Catalog

    func testPreconfiguredSampleStreams() {
        let samples = inspector.sampleStreams
        XCTAssertGreaterThanOrEqual(samples.count, 4)

        for sample in samples {
            let res = inspector.inspect(urlString: sample.urlString)
            XCTAssertEqual(res.streamType, sample.expectedType)
            XCTAssertEqual(res.isCarPlayCompatible, !sample.isDRMProtected)
        }
    }

    // MARK: - 5. Deep Link Routing

    func testDeepLinkRoutingForDRMDiagnostics() {
        let url1 = URL(string: "dashcast://drm-diagnostics")!
        let dest1 = DashCastLinks.destination(for: url1)
        XCTAssertEqual(dest1, .drmDiagnostics)

        let url2 = URL(string: "dashcast://stream-diagnostics")!
        let dest2 = DashCastLinks.destination(for: url2)
        XCTAssertEqual(dest2, .streamDiagnostics)
    }

    @MainActor
    func testAppStateDeepLinkOpeningDRMDiagnostics() {
        let state = AppState.shared
        state.showDRMDiagnostics = false

        let handled = state.handleDeepLink(URL(string: "dashcast://drm-diagnostics")!)
        XCTAssertTrue(handled)
        XCTAssertEqual(state.selectedTab, .cast)
        XCTAssertTrue(state.showDRMDiagnostics)
    }
}
