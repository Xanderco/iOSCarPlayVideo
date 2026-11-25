import XCTest
@testable import DashCast

/// Serves canned XMLTV documents without touching the live network.
final class XMLTVStubURLProtocol: URLProtocol {
    struct Stub {
        let status: Int
        let body: Data
    }

    private static let lock = NSLock()
    private static var stubs: [String: Stub] = [:]
    private static var requested: [URL] = []

    static func stub(_ url: String, status: Int, body: String) {
        lock.lock(); defer { lock.unlock() }
        stubs[url] = Stub(status: status, body: Data(body.utf8))
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        stubs = [:]
        requested = []
    }

    static var requestedURLs: [URL] {
        lock.lock(); defer { lock.unlock() }
        return requested
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        Self.lock.lock()
        Self.requested.append(url)
        let stub = Self.stubs[url.absoluteString]
        Self.lock.unlock()

        guard let stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/xml"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
final class XMLTVGuideTests: XCTestCase {

    private static let sampleXMLTV = """
    <?xml version="1.0" encoding="UTF-8"?>
    <tv generator-info-name="DashCastTests">
      <channel id="news1">
        <display-name>World News</display-name>
      </channel>
      <channel id="sport1">
        <display-name>Sports One</display-name>
      </channel>
      <programme start="20261125110000 +0000" stop="20261125120000 +0000" channel="news1">
        <title lang="en">Midday Report</title>
        <desc lang="en">Live world coverage.</desc>
        <category>News</category>
      </programme>
      <programme start="20261125100000 +0000" stop="20261125110000 +0000" channel="news1">
        <title lang="en">Morning Briefing</title>
        <sub-title>Top Headlines</sub-title>
        <desc lang="en">Start your day informed.</desc>
        <category>News</category>
      </programme>
      <programme start="20261125103000 +0000" stop="20261125123000 +0000" channel="sport1">
        <title>Grand Prix Qualifying</title>
        <category>Motorsport</category>
      </programme>
      <programme start="20261125120000 +0000" stop="20261125110000 +0000" channel="news1">
        <title>Invalid Inverted Range</title>
      </programme>
    </tv>
    """

    private func makeService() -> XMLTVGuideService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [XMLTVStubURLProtocol.self]
        XMLTVStubURLProtocol.reset()
        return XMLTVGuideService(session: URLSession(configuration: config))
    }

    private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        var comps = DateComponents()
        comps.calendar = Calendar(identifier: .gregorian)
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        return comps.date!
    }

    // MARK: - M3U EPG Metadata Extraction

    func testM3UExtractsEPGHeaderAndChannelTvgID() {
        let m3u = """
        #EXTM3U url-tvg="https://epg.example.com/primary.xml, guides/secondary.xml" x-tvg-url="https://epg.example.com/fallback.xml"
        #EXTINF:-1 tvg-id="news1" group-title="News",World News
        https://stream.example.com/news.m3u8
        #EXTINF:-1 tvg-id="  " group-title="General",No ID Channel
        https://stream.example.com/noid.m3u8
        #EXTINF:-1 group-title="Sports",Sports Plain
        https://stream.example.com/sports.m3u8
        """
        let base = URL(string: "https://lists.example.com/iptv/playlist.m3u")!
        let parsed = IPTVParser.parseM3UWithMetadata(content: m3u, baseURL: base)

        XCTAssertEqual(parsed.epgURLs.map(\.absoluteString), [
            "https://epg.example.com/primary.xml",
            "https://lists.example.com/iptv/guides/secondary.xml",
            "https://epg.example.com/fallback.xml"
        ])
        XCTAssertEqual(parsed.primaryEPGURL?.absoluteString, "https://epg.example.com/primary.xml")
        XCTAssertEqual(parsed.channels.count, 3)
        XCTAssertEqual(parsed.channels[0].tvgID, "news1")
        XCTAssertNil(parsed.channels[1].tvgID, "whitespace-only tvg-id should normalize to nil")
        XCTAssertNil(parsed.channels[2].tvgID, "tvg-id must not leak across channels")
    }

    func testM3UHeaderDeduplicatesURLsBetweenUrlTvgAndXTvgUrl() {
        let m3u = """
        #EXTM3U url-tvg="https://epg.example.com/guide.xml" x-tvg-url="https://epg.example.com/guide.xml"
        #EXTINF:-1,Ch 1
        https://stream.example.com/1.m3u8
        """
        let parsed = IPTVParser.parseM3UWithMetadata(content: m3u)
        XCTAssertEqual(parsed.epgURLs.map(\.absoluteString), ["https://epg.example.com/guide.xml"])
    }

    func testLegacyChannelAndPlaylistCodableDecodeWithoutEPGFields() throws {
        let legacyJSON = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "title": "Legacy",
          "url": "https://lists.example.com/old.m3u",
          "channels": [
            {
              "id": "ch-1",
              "name": "Legacy TV",
              "streamURL": "https://stream.example.com/legacy.m3u8",
              "groupTitle": "General",
              "isFavorite": false
            }
          ],
          "createdAt": 0
        }
        """
        let decoded = try JSONDecoder().decode(IPTVPlaylist.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(decoded.epgURL)
        XCTAssertNil(decoded.channels.first?.tvgID)
    }

    func testPlaylistStorePersistsEPGURLFromM3U() throws {
        let suite = "XMLTVGuideTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }

        let store = PlaylistStore(
            persistence: PersistenceController(userDefaults: defaults),
            defaults: defaults
        )
        let m3u = """
        #EXTM3U x-tvg-url="https://epg.example.com/guide.xml"
        #EXTINF:-1 tvg-id="news1",World News
        https://stream.example.com/news.m3u8
        """
        let playlist = try store.addPlaylist(data: Data(m3u.utf8), sourceURL: nil, title: "EPG List")
        XCTAssertEqual(playlist.epgURL?.absoluteString, "https://epg.example.com/guide.xml")
        XCTAssertEqual(playlist.channels.first?.tvgID, "news1")

        let reloaded = PlaylistStore(
            persistence: PersistenceController(userDefaults: defaults),
            defaults: defaults
        )
        XCTAssertEqual(reloaded.playlists.first?.epgURL?.absoluteString, "https://epg.example.com/guide.xml")
        XCTAssertEqual(reloaded.playlists.first?.channels.first?.tvgID, "news1")
    }

    // MARK: - XMLTV Parsing & Date Formats

    func testParseXMLTVDecodesChannelsProgrammesAndSortsChronologically() throws {
        let parsed = try XMLTVGuideService.parseXMLTV(data: Data(Self.sampleXMLTV.utf8))

        XCTAssertEqual(parsed.displayNamesByChannelID["news1"], ["World News"])
        XCTAssertEqual(parsed.displayNamesByChannelID["sport1"], ["Sports One"])

        let newsProgrammes = try XCTUnwrap(parsed.programmesByChannelID["news1"])
        XCTAssertEqual(newsProgrammes.count, 2, "invalid inverted programme must be skipped")
        XCTAssertEqual(newsProgrammes.map(\.title), ["Morning Briefing", "Midday Report"])
        XCTAssertEqual(newsProgrammes[0].subtitle, "Top Headlines")
        XCTAssertEqual(newsProgrammes[0].description, "Start your day informed.")
        XCTAssertEqual(newsProgrammes[0].category, "News")
    }

    func testParseXMLTVDateFormats() {
        let expected = utcDate(2026, 11, 25, 10, 30, 0)
        XCTAssertEqual(XMLTVGuideService.parseXMLTVDate("20261125103000 +0000"), expected)
        XCTAssertEqual(XMLTVGuideService.parseXMLTVDate("20261125103000+0000"), expected)
        XCTAssertEqual(XMLTVGuideService.parseXMLTVDate("20261125053000 -0500"), expected)
        XCTAssertEqual(XMLTVGuideService.parseXMLTVDate("20261125103000"), expected)
        XCTAssertEqual(XMLTVGuideService.parseXMLTVDate("202611251030 +0000"), expected)
        XCTAssertEqual(XMLTVGuideService.parseXMLTVDate("2026-11-25T10:30:00Z"), expected)
        XCTAssertNil(XMLTVGuideService.parseXMLTVDate("not-a-date"))
    }

    // MARK: - Now / Next & Progress Calculation

    func testSlotComputesNowNextAndProgress() throws {
        let service = makeService()
        try service.ingest(data: Data(Self.sampleXMLTV.utf8))

        // 10:30 UTC is exactly halfway through Morning Briefing (10:00–11:00)
        let midMorning = utcDate(2026, 11, 25, 10, 30, 0)
        let slot = service.slot(for: "news1", at: midMorning)

        XCTAssertEqual(slot.now?.title, "Morning Briefing")
        XCTAssertEqual(slot.next?.title, "Midday Report")
        XCTAssertEqual(slot.progress ?? -1, 0.5, accuracy: 0.001)
    }

    func testSlotBeforeFirstProgrammeReturnsNextWithoutNow() throws {
        let service = makeService()
        try service.ingest(data: Data(Self.sampleXMLTV.utf8))

        let early = utcDate(2026, 11, 25, 9, 15, 0)
        let slot = service.slot(for: "news1", at: early)

        XCTAssertNil(slot.now)
        XCTAssertEqual(slot.next?.title, "Morning Briefing")
        XCTAssertNil(slot.progress)
    }

    func testSlotAfterAllProgrammesIsEmpty() throws {
        let service = makeService()
        try service.ingest(data: Data(Self.sampleXMLTV.utf8))

        let late = utcDate(2026, 11, 25, 18, 0, 0)
        let slot = service.slot(for: "news1", at: late)

        XCTAssertTrue(slot.isEmpty)
    }

    func testSlotResolvesChannelByCaseInsensitiveTvgIDAndDisplayNameFallback() throws {
        let service = makeService()
        try service.ingest(data: Data(Self.sampleXMLTV.utf8))
        let atTime = utcDate(2026, 11, 25, 11, 0, 0)

        let byTvgID = ChannelModel(
            name: "Different Name",
            streamURL: URL(string: "https://stream.example.com/n.m3u8")!,
            tvgID: "NEWS1"
        )
        XCTAssertEqual(service.slot(for: byTvgID, at: atTime).now?.title, "Midday Report")

        let byDisplayName = ChannelModel(
            name: "  Sports One  ",
            streamURL: URL(string: "https://stream.example.com/s.m3u8")!,
            tvgID: nil
        )
        let sportSlot = service.slot(for: byDisplayName, at: atTime)
        XCTAssertEqual(sportSlot.now?.title, "Grand Prix Qualifying")
        XCTAssertEqual(sportSlot.progress ?? -1, 0.25, accuracy: 0.001)
    }

    // MARK: - Network Loading (Stubbed URLSession)

    func testLoadGuideFromStubbedURLSessionAndCacheBehavior() async throws {
        let service = makeService()
        let epgURLString = "https://epg.example.com/guide.xml"
        let epgURL = URL(string: epgURLString)!
        XMLTVStubURLProtocol.stub(epgURLString, status: 200, body: Self.sampleXMLTV)

        try await service.loadGuide(from: epgURL)
        XCTAssertEqual(XMLTVStubURLProtocol.requestedURLs, [epgURL])
        XCTAssertTrue(service.loadedFeedURLs.contains(epgURL))
        XCTAssertEqual(service.programmesByChannelID["news1"]?.count, 2)

        // Second call without forceRefresh uses cached data
        try await service.loadGuide(from: epgURL)
        XCTAssertEqual(XMLTVStubURLProtocol.requestedURLs.count, 1)

        // forceRefresh triggers network request again
        try await service.loadGuide(from: epgURL, forceRefresh: true)
        XCTAssertEqual(XMLTVStubURLProtocol.requestedURLs.count, 2)
    }

    func testLoadGuideThrowsHTTPStatusOn404() async {
        let service = makeService()
        let epgURLString = "https://epg.example.com/missing.xml"
        XMLTVStubURLProtocol.stub(epgURLString, status: 404, body: "Not Found")

        do {
            try await service.loadGuide(from: URL(string: epgURLString)!)
            XCTFail("Expected HTTP 404 error")
        } catch {
            XCTAssertEqual(error as? XMLTVGuideError, .httpStatus(404))
            XCTAssertNotNil(service.lastError)
        }
    }

    func testLoadGuideThrowsParseErrorOnMalformedXML() async {
        let service = makeService()
        let epgURLString = "https://epg.example.com/broken.xml"
        XMLTVStubURLProtocol.stub(epgURLString, status: 200, body: "<tv><programme></tv>")

        do {
            try await service.loadGuide(from: URL(string: epgURLString)!)
            XCTFail("Expected XML parse failure")
        } catch let error as XMLTVGuideError {
            if case .parseFailed = error {
                XCTAssertNotNil(service.lastError)
            } else {
                XCTFail("Unexpected XMLTVGuideError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoadGuidesLoadsUniquePlaylistEPGURLs() async {
        let service = makeService()
        let epgURLString = "https://epg.example.com/shared.xml"
        let epgURL = URL(string: epgURLString)!
        XMLTVStubURLProtocol.stub(epgURLString, status: 200, body: Self.sampleXMLTV)

        let p1 = IPTVPlaylist(title: "List 1", epgURL: epgURL)
        let p2 = IPTVPlaylist(title: "List 2", epgURL: epgURL)
        let p3 = IPTVPlaylist(title: "List 3", epgURL: nil)

        await service.loadGuides(for: [p1, p2, p3])
        XCTAssertEqual(XMLTVStubURLProtocol.requestedURLs, [epgURL])
        XCTAssertEqual(service.programmesByChannelID["sport1"]?.first?.title, "Grand Prix Qualifying")
    }
}
