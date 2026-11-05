import XCTest
@testable import DashCast

/// Fixtures are embedded as Swift strings / byte arrays so the test target needs no bundle resources.
final class IPTVParserTests: XCTestCase {

    // MARK: - Fixtures

    private static let basic = """
    #EXTM3U x-tvg-url="https://epg.example.com/guide.xml"
    #EXTINF:-1 tvg-id="news1" tvg-logo="https://cdn.example.com/news.png" group-title="News",World News
    https://stream.example.com/live/news.m3u8
    #EXTINF:-1 tvg-id="sport1" group-title="Sports",Sports One
    https://stream.example.com/live/sport.m3u8
    #EXTINF:-1 group-title="News",Local News
    https://stream.example.com/live/local.m3u8
    """

    private static let commas = """
    #EXTM3U
    #EXTINF:-1 tvg-name="Noticias, Bogotá" group-title="News, Local",Noticias, Edición Nocturna
    https://stream.example.com/live/noticias.m3u8
    #EXTINF:-1 tvg-name="Fallback, Name" group-title="Misc",
    https://stream.example.com/live/fallback.m3u8
    #EXTINF:-1,Hello, World, Again
    https://stream.example.com/live/hello.m3u8
    """

    private static let extgrp = """
    #EXTM3U
    #EXTINF:-1,Documentary One
    #EXTGRP:Documentaries
    https://stream.example.com/doc1.m3u8
    #EXTINF:-1 group-title="Attr Wins",Documentary Two
    #EXTGRP:Ignored
    https://stream.example.com/doc2.m3u8
    #EXTINF:-1,No Group
    https://stream.example.com/nogroup.m3u8
    """

    private static let relative = """
    #EXTM3U
    #EXTINF:-1 group-title="Local",Relative One
    streams/one.m3u8
    #EXTINF:-1 group-title="Local",Root Relative
    /abs/two.m3u8
    #EXTINF:-1 group-title="Local",Parent Relative
    ../up/three.m3u8
    #EXTINF:-1 group-title="Local",Absolute
    https://other.example.org/four.m3u8
    """

    private static let missingExtinf = """
    #EXTM3U
    https://stream.example.com/live/bare_channel.m3u8
    #EXTVLCOPT:http-user-agent=Mozilla
    #EXTINF:-1 group-title="Movies",Titled
    https://stream.example.com/live/titled.m3u8
    https://stream.example.com/live/second_bare.ts
    """

    private func parse(_ text: String, baseURL: URL? = nil) -> [ChannelModel] {
        IPTVParser.parseM3U(content: text, baseURL: baseURL)
    }

    // MARK: - Basic

    func testBasicPlaylistParsesNamesGroupsLogosAndURLs() {
        let channels = parse(Self.basic)
        XCTAssertEqual(channels.map(\.name), ["World News", "Sports One", "Local News"])
        XCTAssertEqual(channels.map(\.groupTitle), ["News", "Sports", "News"])
        XCTAssertEqual(channels[0].logoURL, URL(string: "https://cdn.example.com/news.png"))
        XCTAssertNil(channels[1].logoURL, "logo must not leak from the previous entry")
        XCTAssertEqual(channels[0].streamURL.absoluteString, "https://stream.example.com/live/news.m3u8")
        XCTAssertEqual(Set(channels.map(\.id)).count, 3, "every channel gets a unique id")
    }

    func testEmptyAndHeaderOnlyContentYieldsNoChannels() {
        XCTAssertTrue(parse("").isEmpty)
        XCTAssertTrue(parse("#EXTM3U\n\n   \n").isEmpty)
    }

    // MARK: - Encoding

    func testDecodeStripsUTF8BOMAndParsesCRLF() throws {
        let body = "#EXTM3U\r\n#EXTINF:-1 tvg-logo=\"https://cdn.example.com/a.png\" group-title=\"Movies\",Movie A\r\nhttps://stream.example.com/a.m3u8\r\n#EXTINF:-1 group-title=\"Movies\",Movie B\r\nhttps://stream.example.com/b.m3u8\r\n"
        let data = Data([0xEF, 0xBB, 0xBF]) + Data(body.utf8)

        let text = try XCTUnwrap(IPTVParser.decode(data))
        XCTAssertFalse(text.hasPrefix("\u{FEFF}"), "BOM must be stripped")
        XCTAssertTrue(text.hasPrefix("#EXTM3U"))

        let channels = parse(text)
        XCTAssertEqual(channels.map(\.name), ["Movie A", "Movie B"])
        XCTAssertEqual(channels.map(\.groupTitle), ["Movies", "Movies"])
        XCTAssertEqual(channels.map(\.streamURL.absoluteString),
                       ["https://stream.example.com/a.m3u8", "https://stream.example.com/b.m3u8"])
        XCTAssertFalse(channels.contains { $0.name.contains("\r") || $0.streamURL.absoluteString.contains("%0D") })
        XCTAssertEqual(channels[0].logoURL, URL(string: "https://cdn.example.com/a.png"))
    }

    func testParseStripsBOMWhenGivenStringDirectly() {
        let channels = parse("\u{FEFF}#EXTM3U\n#EXTINF:-1,BOM Channel\nhttps://s.example.com/x.m3u8")
        XCTAssertEqual(channels.map(\.name), ["BOM Channel"])
    }

    func testBareCarriageReturnLineEndings() {
        let channels = parse("#EXTM3U\r#EXTINF:-1,Old Mac\rhttps://s.example.com/mac.m3u8\r")
        XCTAssertEqual(channels.map(\.name), ["Old Mac"])
    }

    func testDecodeFallsBackToLatin1() throws {
        // "Señal Café TV" / "Español" encoded as ISO-8859-1 (0xF1 = ñ, 0xE9 = é) — invalid UTF-8.
        var data = Data("#EXTM3U\n#EXTINF:-1 group-title=\"Espa".utf8)
        data.append(0xF1)
        data.append(contentsOf: Array("ol\",Se".utf8))
        data.append(0xF1)
        data.append(contentsOf: Array("al Caf".utf8))
        data.append(0xE9)
        data.append(contentsOf: Array(" TV\nhttps://stream.example.com/latin.m3u8\n".utf8))
        XCTAssertNil(String(data: data, encoding: .utf8), "fixture must be invalid UTF-8")

        let text = try XCTUnwrap(IPTVParser.decode(data))
        let channels = parse(text)
        XCTAssertEqual(channels.count, 1)
        XCTAssertEqual(channels.first?.name, "Señal Café TV")
        XCTAssertEqual(channels.first?.groupTitle, "Español")
    }

    func testDecodeKeepsValidUTF8() throws {
        let text = try XCTUnwrap(IPTVParser.decode(Data("#EXTINF:-1,Bogotá ñ 東京\n".utf8)))
        XCTAssertTrue(text.contains("Bogotá ñ 東京"))
    }

    // MARK: - Commas

    func testCommasInsideQuotedAttributesDoNotSplitTitle() {
        let channels = parse(Self.commas)
        XCTAssertEqual(channels.count, 3)
        XCTAssertEqual(channels[0].name, "Noticias, Edición Nocturna")
        XCTAssertEqual(channels[0].groupTitle, "News, Local")
    }

    func testEmptyTitleFallsBackToTvgName() {
        let channels = parse(Self.commas)
        XCTAssertEqual(channels[1].name, "Fallback, Name")
        XCTAssertEqual(channels[1].groupTitle, "Misc")
    }

    func testTitleWithMultipleCommasKeepsEverythingAfterFirst() {
        let channels = parse(Self.commas)
        XCTAssertEqual(channels[2].name, "Hello, World, Again")
        XCTAssertEqual(channels[2].groupTitle, "General")
    }

    func testDisplayTitleHelper() {
        XCTAssertEqual(IPTVParser.displayTitle(fromExtinf: "#EXTINF:-1 a=\"x,y\",Title, Z"), "Title, Z")
        XCTAssertNil(IPTVParser.displayTitle(fromExtinf: "#EXTINF:-1 a=\"x,y\""))
    }

    func testLowercaseTagsAreRecognised() {
        let channels = parse("#extm3u\n#extinf:-1 group-title=\"Lower\",lower case\n#extgrp:Other\nhttps://s.example.com/l.m3u8")
        XCTAssertEqual(channels.first?.name, "lower case")
        XCTAssertEqual(channels.first?.groupTitle, "Lower")
    }

    // MARK: - #EXTGRP

    func testExtgrpUsedWhenNoGroupTitleAttribute() {
        let channels = parse(Self.extgrp)
        XCTAssertEqual(channels.map(\.name), ["Documentary One", "Documentary Two", "No Group"])
        XCTAssertEqual(channels[0].groupTitle, "Documentaries")
        XCTAssertEqual(channels[1].groupTitle, "Attr Wins", "group-title attribute takes precedence over #EXTGRP")
        XCTAssertEqual(channels[2].groupTitle, "General", "#EXTGRP must not leak to the next entry")
    }

    // MARK: - Relative URLs

    func testRelativeURLsResolveAgainstBaseURL() {
        let base = URL(string: "https://lists.example.com/iptv/sub/playlist.m3u")!
        let channels = parse(Self.relative, baseURL: base)
        XCTAssertEqual(channels.map(\.streamURL.absoluteString), [
            "https://lists.example.com/iptv/sub/streams/one.m3u8",
            "https://lists.example.com/abs/two.m3u8",
            "https://lists.example.com/iptv/up/three.m3u8",
            "https://other.example.org/four.m3u8",
        ])
        XCTAssertEqual(channels.map(\.name), ["Relative One", "Root Relative", "Parent Relative", "Absolute"])
    }

    func testRelativeURLsWithoutBaseAreDropped() {
        let channels = parse(Self.relative)
        XCTAssertEqual(channels.map(\.name), ["Absolute"])
    }

    func testRelativeEntryWithoutBaseDoesNotLeakMetadataToNextEntry() {
        let text = "#EXTINF:-1 group-title=\"G\" tvg-logo=\"https://l.example.com/x.png\",Dropped\nrel/x.m3u8\nhttps://s.example.com/kept.m3u8"
        let channels = parse(text)
        XCTAssertEqual(channels.count, 1)
        XCTAssertEqual(channels[0].name, "kept")
        XCTAssertEqual(channels[0].groupTitle, "General")
        XCTAssertNil(channels[0].logoURL)
    }

    // MARK: - Missing #EXTINF

    func testEntriesWithoutExtinfUseFilenameAndGeneralGroup() {
        let channels = parse(Self.missingExtinf)
        XCTAssertEqual(channels.map(\.name), ["bare_channel", "Titled", "second_bare"])
        XCTAssertEqual(channels.map(\.groupTitle), ["General", "Movies", "General"])
        XCTAssertEqual(channels[0].streamURL.absoluteString, "https://stream.example.com/live/bare_channel.m3u8")
    }

    func testSurroundingWhitespaceIsTrimmed() {
        let channels = parse("  #EXTINF:-1 , Spaced Out  \n   https://s.example.com/spaced.m3u8   \n")
        XCTAssertEqual(channels.first?.name, "Spaced Out")
        XCTAssertEqual(channels.first?.streamURL.absoluteString, "https://s.example.com/spaced.m3u8")
    }
}
