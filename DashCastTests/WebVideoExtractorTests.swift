import XCTest
@testable import DashCast

final class WebVideoExtractorTests: XCTestCase {
    private func report(url: String? = nil, isBlob: Bool = false, hasEME: Bool = false, hasVideo: Bool = true) -> WebVideoReport {
        WebVideoReport(url: url.flatMap(URL.init(string:)), title: "Clip", isBlob: isBlob, hasEME: hasEME, hasVideo: hasVideo, isMainFrame: true)
    }

    func testParsesHTTPURLAndFlags() {
        let r = WebVideoReport(dictionary: ["url": "https://cdn.example.com/live.m3u8", "title": "Live", "isBlob": false, "hasEME": false, "hasVideo": true])
        XCTAssertEqual(r?.url?.absoluteString, "https://cdn.example.com/live.m3u8")
        XCTAssertEqual(r?.title, "Live")
        XCTAssertEqual(r?.hasVideo, true)
    }

    func testRejectsNonHTTPURLs() {
        let r = WebVideoReport(dictionary: ["url": "blob:https://example.com/abc", "isBlob": true, "hasVideo": true])
        XCTAssertNil(r?.url)
        XCTAssertEqual(r?.isBlob, true)
        XCTAssertNil(WebVideoReport(dictionary: nil))
        XCTAssertNil(WebVideoReport(dictionary: "nope"))
    }

    func testResolveFoundUsesPageTitle() {
        let result = WebVideoExtractor.resolve(main: report(url: "https://example.com/a.mp4"), frame: nil, pageTitle: "Page")
        XCTAssertEqual(result, .found(url: URL(string: "https://example.com/a.mp4")!, title: "Page"))
    }

    func testResolveFallsBackToIframeReport() {
        let result = WebVideoExtractor.resolve(main: report(hasVideo: false), frame: report(url: "https://player.example.com/v.m3u8"), pageTitle: "")
        XCTAssertEqual(result, .found(url: URL(string: "https://player.example.com/v.m3u8")!, title: "Clip"))
    }

    func testResolveDRMWins() {
        let result = WebVideoExtractor.resolve(main: report(url: "https://example.com/a.m3u8", hasEME: true), frame: nil, pageTitle: "")
        XCTAssertEqual(result, .drmProtected)
    }

    func testResolveBlobWithoutURLIsUnsupported() {
        XCTAssertEqual(WebVideoExtractor.resolve(main: report(isBlob: true), frame: nil, pageTitle: ""), .unsupportedStream)
    }

    func testResolveNoVideo() {
        XCTAssertEqual(WebVideoExtractor.resolve(main: report(hasVideo: false), frame: nil, pageTitle: ""), .noVideo)
        XCTAssertEqual(WebVideoExtractor.resolve(main: nil, frame: nil, pageTitle: ""), .noVideo)
    }

    func testDRMPresetsRemoved() {
        let ids = Set(WebVideoBrowserView.preaddedSources.map(\.id))
        for drm in ["netflix", "prime", "hulu", "disney", "hbomax", "appletv", "peacock", "paramount", "crunchyroll"] {
            XCTAssertFalse(ids.contains(drm), "\(drm) should not be a preset")
        }
    }

    @MainActor
    func testWebViewConfigurationAllowsInlineAndAirPlay() {
        let extractor = WebVideoExtractor()
        let config = extractor.webView.configuration
        XCTAssertTrue(config.allowsInlineMediaPlayback)
        XCTAssertTrue(config.allowsAirPlayForMediaPlayback)
        XCTAssertEqual(config.userContentController.userScripts.count, 2)
    }

    @MainActor
    func testPlayWebVideoEnablesExternalPlayback() {
        let service = VideoPlayerService()
        service.playWebVideo(url: URL(string: "https://example.com/a.m3u8")!, title: "")
        XCTAssertTrue(service.player.allowsExternalPlayback)
        XCTAssertEqual(service.currentChannel?.name, "Web video")
        XCTAssertEqual(service.currentChannel?.groupTitle, "Web")
        service.pause()
    }
}
