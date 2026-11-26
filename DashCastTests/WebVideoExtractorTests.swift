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
        XCTAssertEqual(service.currentChannel?.name, WebVideoCopy.localizedDefaultTitle())
        XCTAssertEqual(service.currentChannel?.groupTitle, "Web")
        service.pause()
    }

    func testResolveEmptyTitleUsesLocalizedFallback() {
        let url = URL(string: "https://example.com/a.mp4")!
        let untitledReport = WebVideoReport(
            url: url,
            title: "",
            isBlob: false,
            hasEME: false,
            hasVideo: true,
            isMainFrame: true
        )
        let testBundle = Bundle(for: WebVideoExtractorTests.self)
        let result = WebVideoExtractor.resolve(main: untitledReport, frame: nil, pageTitle: "", bundle: testBundle)
        XCTAssertEqual(result, .found(url: url, title: WebVideoCopy.localizedDefaultTitle(bundle: testBundle)))
        XCTAssertEqual(WebVideoCopy.localizedDefaultTitle(bundle: testBundle), WebVideoCopy.defaultVideoTitleString)
    }

    func testWebVideoCopyLocalizationKeysComplete() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectDir
            .appendingPathComponent("DashCast")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])

        for key in WebVideoCopy.allLocalizationKeys {
            let entry = try XCTUnwrap(strings[key], "Missing Localizable.xcstrings entry for: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]], "Missing localizations for: \(key)")
            for lang in ["en", "es"] {
                let unit = try XCTUnwrap(localizations[lang]?["stringUnit"] as? [String: Any], "Missing \(lang) stringUnit for: \(key)")
                let value = try XCTUnwrap(unit["value"] as? String)
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(lang) translation for: \(key)")
            }
        }
    }
}
