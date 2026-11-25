import XCTest
@testable import DashCast

/// Routes every request of a stubbed URLSession through a per-test handler.
final class MediaServerStubURLProtocol: URLProtocol {
    struct Recorded {
        let request: URLRequest
        let body: Data?
    }

    static var handler: ((URLRequest, Data?) throws -> (Int, Data))?
    static var recorded: [Recorded] = []
    private static let lock = NSLock()

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handler = nil
        recorded = []
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MediaServerStubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.readBody(request)
        Self.lock.lock()
        Self.recorded.append(Recorded(request: request, body: body))
        let handler = Self.handler
        Self.lock.unlock()

        do {
            guard let handler else { throw URLError(.badServerResponse) }
            let (status, data) = try handler(request, body)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func readBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open(); defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

final class MediaServerClientTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        MediaServerStubURLProtocol.reset()
        session = MediaServerStubURLProtocol.makeSession()
    }

    override func tearDown() {
        MediaServerStubURLProtocol.reset()
        session = nil
        super.tearDown()
    }

    private func json(_ string: String) -> Data { Data(string.utf8) }

    private func makeClient(kind: MediaServerKind = .jellyfin,
                            base: String = "http://media.local:8096",
                            token: String? = "TOKEN123",
                            userId: String? = "user1") -> MediaServerClient {
        MediaServerClient(kind: kind, baseURL: URL(string: base)!, deviceId: "device-1",
                          accessToken: token, userId: userId, session: session)
    }

    private func query(_ url: URL?) -> [String: String] {
        var result: [String: String] = [:]
        for item in URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
            result[item.name] = item.value
        }
        return result
    }

    // MARK: Auth

    func testAuthenticateByNameJellyfin() async throws {
        MediaServerStubURLProtocol.handler = { request, _ in
            (200, Data(#"{"User":{"Id":"u-42","Name":"alex"},"AccessToken":"abc123","ServerId":"srv-1"}"#.utf8))
        }
        let client = makeClient(token: nil, userId: nil)
        let result = try await client.authenticate(username: "alex", password: "p@ss \"word\"")

        XCTAssertEqual(result.accessToken, "abc123")
        XCTAssertEqual(result.user.id, "u-42")
        XCTAssertEqual(client.accessToken, "abc123")
        XCTAssertEqual(client.userId, "u-42")

        let recorded = try XCTUnwrap(MediaServerStubURLProtocol.recorded.first)
        XCTAssertEqual(recorded.request.httpMethod, "POST")
        XCTAssertEqual(recorded.request.url?.absoluteString, "http://media.local:8096/Users/AuthenticateByName")
        let auth = try XCTUnwrap(recorded.request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(auth.hasPrefix("MediaBrowser Client=\"DashCast\""))
        XCTAssertTrue(auth.contains("DeviceId=\"device-1\""))
        XCTAssertFalse(auth.contains("Token="), "No token before sign-in")

        let body = try XCTUnwrap(recorded.body)
        let payload = try JSONSerialization.jsonObject(with: body) as? [String: String]
        XCTAssertEqual(payload?["Username"], "alex")
        XCTAssertEqual(payload?["Pw"], "p@ss \"word\"")
    }

    func testAuthenticateEmbyUsesPrefixAndEmbyHeader() async throws {
        MediaServerStubURLProtocol.handler = { _, _ in
            (200, Data(#"{"User":{"Id":"e1"},"AccessToken":"tok"}"#.utf8))
        }
        let client = makeClient(kind: .emby, base: "https://emby.example.com/", token: nil, userId: nil)
        _ = try await client.authenticate(username: "a", password: "b")

        let request = try XCTUnwrap(MediaServerStubURLProtocol.recorded.first?.request)
        XCTAssertEqual(request.url?.absoluteString, "https://emby.example.com/emby/Users/AuthenticateByName")
        XCTAssertNotNil(request.value(forHTTPHeaderField: "X-Emby-Authorization"))
    }

    func testAuthenticateWrongPasswordMapsToInvalidCredentials() async {
        MediaServerStubURLProtocol.handler = { _, _ in (401, Data()) }
        let client = makeClient(token: nil, userId: nil)
        do {
            try await client.authenticate(username: "a", password: "wrong")
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? MediaServerError, .invalidCredentials)
        }
        XCTAssertNil(client.accessToken)
    }

    func testRequestsRequireSignIn() async {
        let client = makeClient(token: nil, userId: nil)
        do {
            _ = try await client.libraries()
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? MediaServerError, .notAuthenticated)
        }
        XCTAssertTrue(MediaServerStubURLProtocol.recorded.isEmpty)
    }

    // MARK: Libraries & items

    func testLibrariesSendsTokenAndDecodes() async throws {
        MediaServerStubURLProtocol.handler = { _, _ in
            (200, Data(#"""
            {"Items":[
              {"Id":"lib-m","Name":"Movies","Type":"CollectionFolder","CollectionType":"movies"},
              {"Id":"lib-t","Name":"Shows","Type":"CollectionFolder","CollectionType":"tvshows"}
            ],"TotalRecordCount":2}
            """#.utf8))
        }
        let libraries = try await makeClient().libraries()

        XCTAssertEqual(libraries.map(\.name), ["Movies", "Shows"])
        XCTAssertEqual(libraries.last?.collectionType, "tvshows")
        let request = try XCTUnwrap(MediaServerStubURLProtocol.recorded.first?.request)
        XCTAssertEqual(request.url?.path, "/Users/user1/Views")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Emby-Token"), "TOKEN123")
        XCTAssertTrue(request.value(forHTTPHeaderField: "Authorization")?.contains("Token=\"TOKEN123\"") ?? false)
    }

    func testItemsQueryAndResumePosition() async throws {
        MediaServerStubURLProtocol.handler = { _, _ in
            (200, Data(#"""
            {"Items":[{"Id":"m1","Name":"Heat","Type":"Movie","ProductionYear":1995,
              "RunTimeTicks":102000000000,"Container":"mp4",
              "UserData":{"PlaybackPositionTicks":6000000000,"Played":false},
              "ImageTags":{"Primary":"tag1"},
              "MediaSources":[{"Id":"ms1","Container":"mp4"}]}]}
            """#.utf8))
        }
        let items = try await makeClient().items(parentId: "lib-m")

        let movie = try XCTUnwrap(items.first)
        XCTAssertEqual(movie.resumePositionSeconds, 600, accuracy: 0.001)
        XCTAssertEqual(movie.runtimeSeconds ?? 0, 10_200, accuracy: 0.001)
        XCTAssertTrue(movie.isPlayable)

        let url = MediaServerStubURLProtocol.recorded.first?.request.url
        XCTAssertEqual(url?.path, "/Users/user1/Items")
        let q = query(url)
        XCTAssertEqual(q["ParentId"], "lib-m")
        XCTAssertEqual(q["Recursive"], "true")
        XCTAssertEqual(q["SortBy"], "SortName")
        XCTAssertTrue(q["IncludeItemTypes"]?.contains("Series") ?? false)
        XCTAssertTrue(q["Fields"]?.contains("UserData") ?? false)
    }

    // MARK: Series / seasons / episodes

    func testEpisodesAreSortedBySeasonThenEpisode() async throws {
        MediaServerStubURLProtocol.handler = { _, _ in
            (200, Data(#"""
            {"Items":[
              {"Id":"e5","Name":"S2E1","Type":"Episode","ParentIndexNumber":2,"IndexNumber":1,"SeasonId":"s2","SeriesName":"Show"},
              {"Id":"e3","Name":"S1E10","Type":"Episode","ParentIndexNumber":1,"IndexNumber":10,"SeasonId":"s1"},
              {"Id":"e1","Name":"S1E1","Type":"Episode","ParentIndexNumber":1,"IndexNumber":1,"SeasonId":"s1"},
              {"Id":"e2","Name":"S1E2","Type":"Episode","ParentIndexNumber":1,"IndexNumber":2,"SeasonId":"s1"},
              {"Id":"e9","Name":"Special","Type":"Episode","SeasonId":"s0"}
            ]}
            """#.utf8))
        }
        let episodes = try await makeClient().episodes(seriesId: "ser1", seasonId: "s1")

        XCTAssertEqual(episodes.map(\.id), ["e1", "e2", "e3", "e5", "e9"])
        XCTAssertEqual(episodes.first?.episodeLabel, "S1E1")
        let url = MediaServerStubURLProtocol.recorded.first?.request.url
        XCTAssertEqual(url?.path, "/Shows/ser1/Episodes")
        XCTAssertEqual(query(url)["SeasonId"], "s1")
        XCTAssertEqual(query(url)["UserId"], "user1")
    }

    func testSeasonsSortedAndGroupedWithEpisodes() async throws {
        MediaServerStubURLProtocol.handler = { request, _ in
            if request.url?.path.hasSuffix("/Seasons") == true {
                return (200, Data(#"""
                {"Items":[{"Id":"s2","Name":"Season 2","Type":"Season","IndexNumber":2},
                          {"Id":"s0","Name":"Specials","Type":"Season","IndexNumber":0},
                          {"Id":"s1","Name":"Season 1","Type":"Season","IndexNumber":1}]}
                """#.utf8))
            }
            return (200, Data(#"""
            {"Items":[{"Id":"b","Name":"B","Type":"Episode","ParentIndexNumber":2,"IndexNumber":1,"SeasonId":"s2"},
                      {"Id":"a","Name":"A","Type":"Episode","ParentIndexNumber":1,"IndexNumber":1,"SeasonId":"s1"}]}
            """#.utf8))
        }
        let client = makeClient()
        let seasons = try await client.seasons(seriesId: "ser1")
        XCTAssertEqual(seasons.map(\.id), ["s0", "s1", "s2"])

        let episodes = try await client.episodes(seriesId: "ser1")
        let groups = MediaSeasonGroup.group(episodes: episodes, seasons: seasons)
        XCTAssertEqual(groups.map(\.title), ["Season 1", "Season 2"], "Empty seasons are hidden")
        XCTAssertEqual(groups.first?.episodes.map(\.id), ["a"])
    }

    func testHTTPErrorIsSurfaced() async {
        MediaServerStubURLProtocol.handler = { _, _ in (500, Data()) }
        do {
            _ = try await makeClient().libraries()
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? MediaServerError, .httpStatus(500))
        }
    }

    // MARK: URL building

    func testDirectPlayStreamURL() throws {
        let client = makeClient(base: "https://media.example.com/jf/")
        let item = MediaItem(id: "m1", name: "Heat", type: "Movie", container: "mp4",
                             mediaSources: [MediaSourceInfo(id: "ms1", container: "mp4")])
        let url = try client.streamURL(for: item, playSessionId: "ps1")

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.path, "/jf/Videos/m1/stream")
        let q = query(url)
        XCTAssertEqual(q["static"], "true")
        XCTAssertEqual(q["api_key"], "TOKEN123")
        XCTAssertEqual(q["MediaSourceId"], "ms1")
        XCTAssertEqual(q["PlaySessionId"], "ps1")
        XCTAssertEqual(q["DeviceId"], "device-1")
    }

    func testHLSStreamURLForNonNativeContainer() throws {
        let client = makeClient(kind: .emby, base: "http://10.0.0.2:8096")
        let item = MediaItem(id: "m2", name: "Film", type: "Movie", container: "mkv")
        XCTAssertEqual(MediaStreamMode.preferred(for: item), .hls)

        let url = try client.streamURL(for: item)
        XCTAssertEqual(url.path, "/emby/Videos/m2/master.m3u8")
        let q = query(url)
        XCTAssertEqual(q["api_key"], "TOKEN123")
        XCTAssertEqual(q["MediaSourceId"], "m2")
        XCTAssertNotNil(q["VideoCodec"])
        XCTAssertNil(q["static"])
    }

    func testStreamURLRequiresToken() {
        let client = makeClient(token: nil)
        XCTAssertThrowsError(try client.streamURL(for: MediaItem(id: "x", name: "x"))) {
            XCTAssertEqual($0 as? MediaServerError, .notAuthenticated)
        }
    }

    func testImageURL() {
        let client = makeClient()
        XCTAssertNil(client.imageURL(for: MediaItem(id: "x", name: "x")))
        let url = client.imageURL(for: MediaItem(id: "x", name: "x", imageTags: ["Primary": "abc"]), maxWidth: 300)
        XCTAssertEqual(url?.path, "/Items/x/Images/Primary")
        XCTAssertEqual(query(url)["tag"], "abc")
        XCTAssertEqual(query(url)["maxWidth"], "300")
    }

    func testNormalizedServerURL() {
        XCTAssertEqual(MediaServerClient.normalizedServerURL("media.local:8096/", kind: .jellyfin)?.absoluteString,
                       "http://media.local:8096")
        XCTAssertEqual(MediaServerClient.normalizedServerURL(" https://x.com/emby/ ", kind: .emby)?.absoluteString,
                       "https://x.com")
        XCTAssertEqual(MediaServerClient.normalizedServerURL("https://x.com/jellyfin", kind: .jellyfin)?.absoluteString,
                       "https://x.com/jellyfin")
        XCTAssertNil(MediaServerClient.normalizedServerURL("", kind: .jellyfin))
        XCTAssertNil(MediaServerClient.normalizedServerURL("not a url", kind: .jellyfin))
    }

    func testTicksConversion() {
        XCTAssertEqual(MediaTicks.ticks(fromSeconds: 1.5), 15_000_000)
        XCTAssertEqual(MediaTicks.seconds(fromTicks: 25_000_000), 2.5, accuracy: 0.0001)
        XCTAssertEqual(MediaTicks.ticks(fromSeconds: .nan), 0)
    }

    // MARK: Playback reporting

    func testReportPlaybackProgressBody() async throws {
        MediaServerStubURLProtocol.handler = { _, _ in (204, Data()) }
        let report = MediaServerClient.PlaybackReport(itemId: "m1", mediaSourceId: "ms1", playSessionId: "ps1",
                                                      positionTicks: MediaTicks.ticks(fromSeconds: 42),
                                                      isPaused: true, playMethod: "DirectPlay")
        try await makeClient().reportPlayback(.progress, report: report)

        let recorded = try XCTUnwrap(MediaServerStubURLProtocol.recorded.first)
        XCTAssertEqual(recorded.request.httpMethod, "POST")
        XCTAssertEqual(recorded.request.url?.path, "/Sessions/Playing/Progress")
        let body = try XCTUnwrap(recorded.body)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["ItemId"] as? String, "m1")
        XCTAssertEqual((payload["PositionTicks"] as? NSNumber)?.int64Value, 420_000_000)
        XCTAssertEqual(payload["IsPaused"] as? Bool, true)
        XCTAssertEqual(payload["PlaySessionId"] as? String, "ps1")
    }
}

// MARK: - Store, channel mapping & QR payloads

final class MediaServerStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        MediaServerStubURLProtocol.reset()
        suiteName = "MediaServerStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        MediaServerStubURLProtocol.reset()
        super.tearDown()
    }

    @MainActor
    func testSignInKeepsTokenOutOfUserDefaults() async throws {
        MediaServerStubURLProtocol.handler = { request, _ in
            if request.url?.path == "/System/Info/Public" {
                return (200, Data(#"{"ServerName":"Living Room","Id":"srv"}"#.utf8))
            }
            return (200, Data(#"{"User":{"Id":"u1","Name":"alex"},"AccessToken":"SECRET-TOKEN"}"#.utf8))
        }
        let tokens = InMemoryMediaServerTokenStore()
        let store = MediaServerStore(defaults: defaults, tokenStore: tokens,
                                     session: MediaServerStubURLProtocol.makeSession())

        let account = try await store.signIn(kind: .jellyfin, serverAddress: "192.168.1.5:8096",
                                             username: "alex", password: "pw")

        XCTAssertEqual(account.serverName, "Living Room")
        XCTAssertEqual(account.baseURL.absoluteString, "http://192.168.1.5:8096")
        XCTAssertEqual(tokens.token(for: account.id), "SECRET-TOKEN")
        XCTAssertEqual(store.client(for: account).accessToken, "SECRET-TOKEN")

        for (_, value) in defaults.dictionaryRepresentation() {
            if let data = value as? Data, let text = String(data: data, encoding: .utf8) {
                XCTAssertFalse(text.contains("SECRET-TOKEN"))
            }
            if let text = value as? String { XCTAssertFalse(text.contains("SECRET-TOKEN")) }
        }

        // Reloading from defaults restores the account (and the token from the token store).
        let reloaded = MediaServerStore(defaults: defaults, tokenStore: tokens)
        XCTAssertEqual(reloaded.accounts, [account])

        store.remove(account)
        XCTAssertNil(tokens.token(for: account.id))
        XCTAssertTrue(store.accounts.isEmpty)
    }

    @MainActor
    func testSignInRejectsBadAddress() async {
        let store = MediaServerStore(defaults: defaults, tokenStore: InMemoryMediaServerTokenStore(),
                                     session: MediaServerStubURLProtocol.makeSession())
        do {
            try await store.signIn(kind: .emby, serverAddress: "   ", username: "a", password: "b")
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? MediaServerError, .invalidServerURL)
        }
    }

    func testKeychainTokenStoreRoundTrip() throws {
        let store = KeychainMediaServerTokenStore(service: "com.xanderco.dashcast.tests.\(UUID().uuidString)")
        let id = UUID()
        guard store.setToken("t1", for: id) else {
            throw XCTSkip("Keychain unavailable in this (unsigned) test host")
        }
        XCTAssertEqual(store.token(for: id), "t1")
        XCTAssertTrue(store.setToken("t2", for: id))
        XCTAssertEqual(store.token(for: id), "t2")
        store.removeToken(for: id)
        XCTAssertNil(store.token(for: id))
    }

    @MainActor
    func testChannelForEpisode() throws {
        let account = MediaServerAccount(kind: .jellyfin, baseURL: URL(string: "http://h:8096")!,
                                         serverName: "Home", username: "a", userId: "u", deviceId: "d")
        let client = MediaServerClient(account: account, accessToken: "tok")
        let episode = MediaItem(id: "e1", name: "Pilot", type: "Episode", seriesName: "Show",
                                indexNumber: 1, parentIndexNumber: 1, container: "mkv")
        let channel = try MediaServerPlaybackCoordinator.channel(for: episode, account: account,
                                                                 client: client, playSessionId: "ps")
        XCTAssertEqual(channel.name, "Show · S1E1 · Pilot")
        XCTAssertEqual(channel.groupTitle, "Home")
        XCTAssertEqual(channel.streamURL.path, "/Videos/e1/master.m3u8")
        XCTAssertTrue(channel.id.hasSuffix("-e1"))
    }

    func testQRPayloadParsing() {
        XCTAssertEqual(PlaylistQRPayload.playlistURL(from: "https://iptv.example.com/list.m3u8")?.absoluteString,
                       "https://iptv.example.com/list.m3u8")
        XCTAssertEqual(PlaylistQRPayload.playlistURL(from: "  URL:http://a.b/c.m3u \n")?.absoluteString,
                       "http://a.b/c.m3u")
        XCTAssertEqual(PlaylistQRPayload.playlistURL(from: "My list: http://x.y/p.m3u;")?.absoluteString,
                       "http://x.y/p.m3u")
        XCTAssertNil(PlaylistQRPayload.playlistURL(from: "WIFI:S:home;T:WPA;P:secret;;"))
        XCTAssertNil(PlaylistQRPayload.playlistURL(from: "ftp://x.y/p.m3u"))
        XCTAssertNil(PlaylistQRPayload.playlistURL(from: ""))
    }
}

// MARK: - Xtream Codes & Plex Tests

final class XtreamAndPlexMediaServerTests: XCTestCase {
    private var session: URLSession!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        MediaServerStubURLProtocol.reset()
        session = MediaServerStubURLProtocol.makeSession()
        suiteName = "XtreamAndPlexTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        MediaServerStubURLProtocol.reset()
        session = nil
        super.tearDown()
    }

    private func query(_ url: URL?) -> [String: String] {
        var result: [String: String] = [:]
        for item in URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
            result[item.name] = item.value
        }
        return result
    }

    // MARK: URL normalization

    func testNormalizedServerURLForXtreamAndPlex() {
        XCTAssertEqual(
            MediaServerClient.normalizedServerURL("http://iptv.example.com:8080/player_api.php", kind: .xtream)?.absoluteString,
            "http://iptv.example.com:8080"
        )
        XCTAssertEqual(
            MediaServerClient.normalizedServerURL("iptv.example.com:8080/get.php", kind: .xtream)?.absoluteString,
            "http://iptv.example.com:8080"
        )
        XCTAssertEqual(
            MediaServerClient.normalizedServerURL("192.168.1.20:32400/web/", kind: .plex)?.absoluteString,
            "http://192.168.1.20:32400"
        )
    }

    // MARK: Xtream Codes API & Stream URLs

    func testXtreamAuthenticateSuccessAndRejection() async throws {
        MediaServerStubURLProtocol.handler = { _, _ in
            (200, Data(#"""
            {
              "user_info": {"username": "driver", "status": "Active", "auth": 1, "exp_date": "1800000000"},
              "server_info": {"url": "stream.example.com", "port": "8080", "server_protocol": "http"}
            }
            """#.utf8))
        }
        let client = MediaServerClient(kind: .xtream,
                                       baseURL: URL(string: "http://stream.example.com:8080")!,
                                       deviceId: "dev-1",
                                       session: session)
        let auth = try await client.authenticateXtream(username: "driver", password: "xt-password")
        XCTAssertTrue(auth.isAuthorized)
        XCTAssertEqual(auth.userInfo?.username, "driver")
        XCTAssertEqual(client.userId, "driver")
        XCTAssertEqual(client.accessToken, "xt-password")

        let reqURL = MediaServerStubURLProtocol.recorded.first?.request.url
        XCTAssertEqual(reqURL?.path, "/player_api.php")
        XCTAssertEqual(query(reqURL)["username"], "driver")
        XCTAssertEqual(query(reqURL)["password"], "xt-password")

        // Auth = 0 should reject credentials and clear token
        MediaServerStubURLProtocol.handler = { _, _ in
            (200, Data(#"{"user_info": {"username": "driver", "status": "Disabled", "auth": 0}}"#.utf8))
        }
        do {
            try await client.authenticateXtream(username: "driver", password: "bad")
            XCTFail("Expected invalidCredentials")
        } catch {
            XCTAssertEqual(error as? MediaServerError, .invalidCredentials)
        }
        XCTAssertNil(client.accessToken)
    }

    func testXtreamJSONDecodingAndUnifiedBrowse() async throws {
        MediaServerStubURLProtocol.handler = { request, _ in
            let action = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "action" })?.value
            switch action {
            case "get_live_categories":
                return (200, Data(#"[{"category_id": 10, "category_name": "Sports", "parent_id": 0}]"#.utf8))
            case "get_live_streams":
                return (200, Data(#"[{"stream_id": 501, "name": "Track Feed HD", "stream_icon": "https://cdn.example.com/logo.png", "category_id": "10", "container_extension": "ts"}]"#.utf8))
            case "get_vod_categories":
                return (200, Data(#"[{"category_id": "20", "category_name": "Documentaries"}]"#.utf8))
            case "get_vod_streams":
                return (200, Data(#"[{"stream_id": 702, "name": "Le Mans", "stream_icon": "https://cdn.example.com/vod.jpg", "category_id": "20", "container_extension": "mp4"}]"#.utf8))
            case "get_series_info":
                return (200, Data(#"""
                {
                  "seasons": [{"season_number": 1, "name": "Season 1"}],
                  "episodes": {
                    "1": [{"id": "9001", "episode_num": 1, "season": 1, "title": "Episode One", "container_extension": "mp4"}]
                  },
                  "info": {"name": "Motorsport Docs"}
                }
                """#.utf8))
            default:
                return (200, Data("[]".utf8))
            }
        }

        let client = MediaServerClient(kind: .xtream,
                                       baseURL: URL(string: "http://xt.example.com:8080")!,
                                       deviceId: "dev-1",
                                       accessToken: "secret-pw",
                                       userId: "alice",
                                       session: session)

        let libs = try await client.libraries()
        XCTAssertEqual(libs.map(\.id), ["xtream:live", "xtream:vod", "xtream:series"])

        let liveCats = try await client.items(parentId: "xtream:live")
        XCTAssertEqual(liveCats.first?.id, "xtream:live:cat:10")
        XCTAssertEqual(liveCats.first?.isFolder, true)

        let liveStreams = try await client.items(parentId: "xtream:live:cat:10")
        let channel = try XCTUnwrap(liveStreams.first)
        XCTAssertEqual(channel.name, "Track Feed HD")
        XCTAssertEqual(try client.streamURL(for: channel).absoluteString,
                       "http://xt.example.com:8080/live/alice/secret-pw/501.ts")
        XCTAssertEqual(client.imageURL(for: channel)?.absoluteString, "https://cdn.example.com/logo.png")

        let vodCats = try await client.items(parentId: "xtream:vod")
        XCTAssertEqual(vodCats.first?.id, "xtream:vod:cat:20")

        let vodItems = try await client.items(parentId: "xtream:vod:cat:20")
        let movie = try XCTUnwrap(vodItems.first)
        XCTAssertEqual(try client.streamURL(for: movie).absoluteString,
                       "http://xt.example.com:8080/movie/alice/secret-pw/702.mp4")

        let seasons = try await client.seasons(seriesId: "xtream:series:show:44")
        XCTAssertEqual(seasons.first?.indexNumber, 1)

        let episodes = try await client.episodes(seriesId: "xtream:series:show:44")
        let ep = try XCTUnwrap(episodes.first)
        XCTAssertEqual(ep.episodeLabel, "S1E1")
        XCTAssertEqual(try client.streamURL(for: ep).absoluteString,
                       "http://xt.example.com:8080/series/alice/secret-pw/9001.mp4")
    }

    func testXtreamStreamURLConstructionAndAuthGuard() throws {
        let client = MediaServerClient(kind: .xtream,
                                       baseURL: URL(string: "https://panel.example.com/portal")!,
                                       deviceId: "dev-1",
                                       accessToken: "pass123",
                                       userId: "user1")
        XCTAssertEqual(
            try client.xtreamStreamURL(kind: .live, streamId: "99").absoluteString,
            "https://panel.example.com/portal/live/user1/pass123/99.m3u8"
        )
        XCTAssertEqual(
            try client.xtreamStreamURL(kind: .movie, streamId: "42", containerExtension: ".mkv").absoluteString,
            "https://panel.example.com/portal/movie/user1/pass123/42.mkv"
        )
        XCTAssertEqual(
            try client.xtreamStreamURL(kind: .series, streamId: "77", containerExtension: "mp4").absoluteString,
            "https://panel.example.com/portal/series/user1/pass123/77.mp4"
        )

        let unauth = MediaServerClient(kind: .xtream,
                                       baseURL: URL(string: "https://panel.example.com")!,
                                       deviceId: "dev-1")
        XCTAssertThrowsError(try unauth.xtreamStreamURL(kind: .live, streamId: "1")) {
            XCTAssertEqual($0 as? MediaServerError, .notAuthenticated)
        }
    }

    // MARK: Plex API, Section Parsing & Stream URLs

    func testPlexAuthenticateHeadersAndFailureMapping() async throws {
        MediaServerStubURLProtocol.handler = { _, _ in
            (200, Data(#"""
            {"MediaContainer":{"friendlyName":"Garage Plex","machineIdentifier":"mach-9","version":"1.41.0","myPlexUsername":"alex"}}
            """#.utf8))
        }
        let client = MediaServerClient(kind: .plex,
                                       baseURL: URL(string: "http://192.168.1.50:32400")!,
                                       deviceId: "dev-plex",
                                       session: session)
        let identity = try await client.authenticatePlex(token: "PLEX-TOK-1")
        XCTAssertEqual(identity.friendlyName, "Garage Plex")
        XCTAssertEqual(client.accessToken, "PLEX-TOK-1")
        XCTAssertEqual(client.userId, "alex")

        let req = try XCTUnwrap(MediaServerStubURLProtocol.recorded.first?.request)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Plex-Token"), "PLEX-TOK-1")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Plex-Client-Identifier"), "dev-plex")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Accept"), "application/json")

        MediaServerStubURLProtocol.handler = { _, _ in (401, Data()) }
        do {
            try await client.authenticatePlex(token: "bad-tok")
            XCTFail("Expected invalidCredentials")
        } catch {
            XCTAssertEqual(error as? MediaServerError, .invalidCredentials)
        }
        XCTAssertNil(client.accessToken)
    }

    func testPlexSectionsItemsAndStreamURLs() async throws {
        MediaServerStubURLProtocol.handler = { request, _ in
            switch request.url?.path {
            case "/library/sections":
                return (200, Data(#"""
                {"MediaContainer":{"Directory":[
                  {"key":"1","title":"Movies","type":"movie"},
                  {"key":"2","title":"TV Shows","type":"show"}
                ]}}
                """#.utf8))
            case "/library/sections/1/all":
                return (200, Data(#"""
                {"MediaContainer":{"Metadata":[
                  {
                    "ratingKey":"101","type":"movie","title":"Senna","year":2010,
                    "duration":6360000,"viewOffset":300000,"viewCount":0,
                    "thumb":"/library/metadata/101/thumb/1700",
                    "Media":[{"id":201,"container":"mp4","Part":[{"id":301,"key":"/library/parts/301/1700/file.mp4","container":"mp4"}]}]
                  },
                  {
                    "ratingKey":"102","type":"movie","title":"Rush","year":2013,
                    "Media":[{"id":202,"container":"mkv","Part":[{"id":302,"key":"/library/parts/302/1701/file.mkv","container":"mkv"}]}]
                  }
                ]}}
                """#.utf8))
            case "/library/metadata/200/children":
                return (200, Data(#"""
                {"MediaContainer":{"Metadata":[
                  {"ratingKey":"201","type":"season","title":"Season 1","index":1}
                ]}}
                """#.utf8))
            case "/library/metadata/200/allLeaves":
                return (200, Data(#"""
                {"MediaContainer":{"Metadata":[
                  {"ratingKey":"202","type":"episode","title":"Pilot","index":1,"parentIndex":1,"parentRatingKey":"201","grandparentTitle":"Drive Series",
                   "Media":[{"id":500,"container":"mp4","Part":[{"id":501,"key":"/library/parts/501/1/ep.mp4","container":"mp4"}]}]}
                ]}}
                """#.utf8))
            default:
                return (204, Data())
            }
        }

        let client = MediaServerClient(kind: .plex,
                                       baseURL: URL(string: "http://plex.local:32400")!,
                                       deviceId: "dev-1",
                                       accessToken: "PLEXSECRET",
                                       userId: "alex",
                                       session: session)

        let libs = try await client.libraries()
        XCTAssertEqual(libs.map(\.name), ["Movies", "TV Shows"])
        XCTAssertEqual(libs.first?.collectionType, "movies")
        XCTAssertEqual(libs.last?.collectionType, "tvshows")

        let movies = try await client.items(parentId: "1")
        XCTAssertEqual(movies.count, 2)

        let mp4Movie = movies[0]
        XCTAssertEqual(mp4Movie.resumePositionSeconds, 300, accuracy: 0.001)
        XCTAssertEqual(mp4Movie.runtimeSeconds ?? 0, 6360, accuracy: 0.001)
        let directURL = try client.streamURL(for: mp4Movie)
        XCTAssertEqual(directURL.path, "/library/parts/301/1700/file.mp4")
        XCTAssertEqual(query(directURL)["X-Plex-Token"], "PLEXSECRET")

        let thumbURL = client.imageURL(for: mp4Movie)
        XCTAssertEqual(thumbURL?.path, "/library/metadata/101/thumb/1700")
        XCTAssertEqual(query(thumbURL)["X-Plex-Token"], "PLEXSECRET")

        let mkvMovie = movies[1]
        let hlsURL = try client.streamURL(for: mkvMovie)
        XCTAssertEqual(hlsURL.path, "/video/:/transcode/universal/start.m3u8")
        XCTAssertEqual(query(hlsURL)["path"], "/library/metadata/102")
        XCTAssertEqual(query(hlsURL)["X-Plex-Token"], "PLEXSECRET")

        let seasons = try await client.seasons(seriesId: "200")
        XCTAssertEqual(seasons.map(\.id), ["201"])
        let episodes = try await client.episodes(seriesId: "200")
        XCTAssertEqual(episodes.first?.episodeLabel, "S1E1")

        let report = MediaServerClient.PlaybackReport(itemId: "101", mediaSourceId: "/library/parts/301/1700/file.mp4",
                                                      playSessionId: "ps1", positionTicks: MediaTicks.ticks(fromSeconds: 45),
                                                      isPaused: false, playMethod: "DirectPlay")
        try await client.reportPlayback(.progress, report: report)
        let timelineReq = try XCTUnwrap(MediaServerStubURLProtocol.recorded.last?.request)
        XCTAssertEqual(timelineReq.url?.path, "/:/timeline")
        XCTAssertEqual(query(timelineReq.url)["state"], "playing")
        XCTAssertEqual(query(timelineReq.url)["time"], "45000")
    }

    // MARK: Keychain / TokenStore Isolation

    @MainActor
    func testPlexAndXtreamKeepSecretsOutOfUserDefaults() async throws {
        MediaServerStubURLProtocol.handler = { request, _ in
            if request.url?.path == "/player_api.php" {
                return (200, Data(#"{"user_info":{"username":"xtuser","status":"Active","auth":1},"server_info":{"url":"xt.example.com"}}"#.utf8))
            }
            return (200, Data(#"{"MediaContainer":{"friendlyName":"Home Plex","machineIdentifier":"plex-1","myPlexUsername":"plexuser"}}"#.utf8))
        }

        let tokens = InMemoryMediaServerTokenStore()
        let store = MediaServerStore(defaults: defaults, tokenStore: tokens, session: session)

        let plexAccount = try await store.signInPlex(serverAddress: "192.168.1.99:32400", token: "TOP-SECRET-PLEX-TOKEN")
        let xtreamAccount = try await store.signIn(kind: .xtream, serverAddress: "http://xt.example.com:8080",
                                                   username: "xtuser", password: "TOP-SECRET-XTREAM-PASS")

        XCTAssertEqual(plexAccount.kind, .plex)
        XCTAssertEqual(plexAccount.serverName, "Home Plex")
        XCTAssertEqual(tokens.token(for: plexAccount.id), "TOP-SECRET-PLEX-TOKEN")

        XCTAssertEqual(xtreamAccount.kind, .xtream)
        XCTAssertEqual(tokens.token(for: xtreamAccount.id), "TOP-SECRET-XTREAM-PASS")

        for (_, value) in defaults.dictionaryRepresentation() {
            if let data = value as? Data, let text = String(data: data, encoding: .utf8) {
                XCTAssertFalse(text.contains("TOP-SECRET-PLEX-TOKEN"))
                XCTAssertFalse(text.contains("TOP-SECRET-XTREAM-PASS"))
            }
            if let text = value as? String {
                XCTAssertFalse(text.contains("TOP-SECRET-PLEX-TOKEN"))
                XCTAssertFalse(text.contains("TOP-SECRET-XTREAM-PASS"))
            }
        }

        let reloaded = MediaServerStore(defaults: defaults, tokenStore: tokens)
        XCTAssertEqual(reloaded.accounts.count, 2)
        XCTAssertEqual(reloaded.client(for: xtreamAccount).accessToken, "TOP-SECRET-XTREAM-PASS")

        store.remove(plexAccount)
        store.remove(xtreamAccount)
        XCTAssertNil(tokens.token(for: plexAccount.id))
        XCTAssertNil(tokens.token(for: xtreamAccount.id))
        XCTAssertTrue(store.accounts.isEmpty)
    }
}
