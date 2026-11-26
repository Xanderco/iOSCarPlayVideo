import XCTest
@testable import DashCast

final class CastEngineTests: XCTestCase {
    func testM3UParserBasic() {
        let sampleM3U = """
        #EXTM3U
        #EXTINF:-1 tvg-id="ch1" tvg-name="Channel One" tvg-logo="https://example.com/logo1.png" group-title="Movies",Channel One HD
        https://example.com/stream1.m3u8
        #EXTINF:-1 tvg-id="ch2" tvg-name="Channel Two" group-title="Sports",Channel Two Live
        https://example.com/stream2.m3u8
        """

        let channels = IPTVParser.parseM3U(content: sampleM3U)

        XCTAssertEqual(channels.count, 2)

        let ch1 = channels[0]
        XCTAssertEqual(ch1.name, "Channel One HD")
        XCTAssertEqual(ch1.groupTitle, "Movies")
        XCTAssertEqual(ch1.streamURL.absoluteString, "https://example.com/stream1.m3u8")
        XCTAssertEqual(ch1.logoURL?.absoluteString, "https://example.com/logo1.png")

        let ch2 = channels[1]
        XCTAssertEqual(ch2.name, "Channel Two Live")
        XCTAssertEqual(ch2.groupTitle, "Sports")
        XCTAssertEqual(ch2.streamURL.absoluteString, "https://example.com/stream2.m3u8")
        XCTAssertNil(ch2.logoURL)
    }

    func testM3UParserWithEmptyLinesAndNoAttributes() {
        let raw = """
        #EXTM3U

        #EXTINF:0,Raw News Stream
        https://news.example.com/live.m3u8

        """

        let channels = IPTVParser.parseM3U(content: raw)
        XCTAssertEqual(channels.count, 1)
        XCTAssertEqual(channels.first?.name, "Raw News Stream")
        XCTAssertEqual(channels.first?.groupTitle, "General")
    }

    func testSamplePlaylistNonEmpty() {
        let playlist = IPTVParser.samplePlaylist
        XCTAssertGreaterThan(playlist.count, 0)
        for channel in playlist {
            XCTAssertFalse(channel.name.isEmpty)
            XCTAssertFalse(channel.streamURL.absoluteString.isEmpty)
        }
    }

    /// App Review 5.2: demo content must be DashCast's own bundled videos, never third-party streams.
    func testSamplePlaylistIsOnlyBundledDemoVideos() {
        let playlist = IPTVParser.samplePlaylist
        XCTAssertEqual(playlist.count, 2)
        for channel in playlist {
            XCTAssertTrue(channel.streamURL.isFileURL, "\(channel.name) is not a bundled file")
            XCTAssertEqual(channel.groupTitle, "Demo Videos")
        }
        // Stable ids so favorites/recents survive re-reads.
        XCTAssertEqual(IPTVParser.samplePlaylist.map(\.id), playlist.map(\.id))
    }

    func testCastHomeURLInputValidator() {
        XCTAssertEqual(CastHomeURLInputValidator.normalizedInput("  https://example.com/list.m3u \n"), "https://example.com/list.m3u")
        XCTAssertFalse(CastHomeURLInputValidator.isValidStreamInput(""))
        XCTAssertFalse(CastHomeURLInputValidator.isValidStreamInput("   \n\t "))
        XCTAssertFalse(CastHomeURLInputValidator.isValidStreamInput("not a url"))
        XCTAssertFalse(CastHomeURLInputValidator.isValidStreamInput("ftp://example.com/list.m3u"))
        XCTAssertFalse(CastHomeURLInputValidator.isValidStreamInput("https:///list.m3u"))

        XCTAssertTrue(CastHomeURLInputValidator.isValidStreamInput("  https://example.com/playlist.m3u  "))
        XCTAssertTrue(CastHomeURLInputValidator.isValidStreamInput("HTTP://192.168.1.10:8080/live.m3u8"))

        XCTAssertTrue(CastHomeURLInputValidator.isSingleHLSStreamURL(URL(string: "https://example.com/stream.M3U8")!))
        XCTAssertFalse(CastHomeURLInputValidator.isSingleHLSStreamURL(URL(string: "https://example.com/playlist.m3u")!))
    }

    func testCastHomeCopyLocalizationKeysComplete() throws {
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

        for key in CastHomeCopy.allLocalizationKeys {
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
