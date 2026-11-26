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

    // MARK: WebBrowserAlertCopy

    @MainActor
    func testWebBrowserAlertCopyOutcomes() {
        let url = URL(string: "https://example.com/clip.m3u8")!
        let found = WebBrowserAlertCopy.descriptor(forExtractionResult: .found(url: url, title: "Clip"))
        XCTAssertEqual(found.titleKeyName, "Sent to DashCast")
        XCTAssertEqual(found.messageKeyName, "Playing on DashCast player — use AirPlay to send it to your car display.")
        _ = found.title
        _ = found.message

        let drm = WebBrowserAlertCopy.descriptor(forExtractionResult: .drmProtected)
        XCTAssertEqual(drm.titleKeyName, "Protected Video")
        XCTAssertEqual(drm.messageKeyName, "This video is DRM-protected and can't be sent to the car.")
        _ = drm.title
        _ = drm.message

        let unsupported = WebBrowserAlertCopy.descriptor(forExtractionResult: .unsupportedStream)
        XCTAssertEqual(unsupported.titleKeyName, "Can't Hand Off")
        XCTAssertEqual(unsupported.messageKeyName, "This site streams in a way that can't be handed off.")
        _ = unsupported.title
        _ = unsupported.message

        let noVideo = WebBrowserAlertCopy.descriptor(forExtractionResult: .noVideo)
        XCTAssertEqual(noVideo.titleKeyName, "No Video Found")
        XCTAssertEqual(noVideo.messageKeyName, "Start playing a video on the page, then tap Send to car again.")
        _ = noVideo.title
        _ = noVideo.message

        let invalidURL = WebBrowserAlertCopy.descriptor(for: .invalidURL)
        XCTAssertEqual(invalidURL.titleKeyName, "Invalid URL")
        XCTAssertEqual(invalidURL.messageKeyName, "Enter a valid website address to load.")
        _ = invalidURL.title
        _ = invalidURL.message
    }

    func testWebBrowserLocalizationKeysExistInCatalog() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = Bundle(for: WebVideoExtractorTests.self).url(forResource: "Localizable", withExtension: "xcstrings")
            ?? projectDir
                .appendingPathComponent("DashCast")
                .appendingPathComponent("Resources")
                .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])

        for key in WebBrowserAlertCopy.allLocalizationKeys {
            let entry = try XCTUnwrap(strings[key], "Missing key in Localizable.xcstrings: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]])
            let enValue = ((localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            let esValue = ((localizations["es"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            XCTAssertFalse(enValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Missing EN for \(key)")
            XCTAssertFalse(esValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Missing ES for \(key)")
        }
    }
}
