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
}
