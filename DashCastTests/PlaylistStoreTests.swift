import XCTest
@testable import DashCast

/// Serves canned responses for `PlaylistStore.importPlaylist(from:)` without touching the network.
final class PlaylistStubURLProtocol: URLProtocol {
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
        let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "audio/x-mpegurl"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
final class PlaylistStoreTests: XCTestCase {

    private static let twoChannels = """
    #EXTM3U
    #EXTINF:-1 group-title="News",News One
    https://stream.example.com/news1.m3u8
    #EXTINF:-1 group-title="Sports",Sports One
    https://stream.example.com/sports1.m3u8
    """

    private static let threeChannels = """
    #EXTM3U
    #EXTINF:-1 group-title="Movies",Movie A
    https://stream.example.com/movieA.m3u8
    #EXTINF:-1 group-title="News",News Two
    https://stream.example.com/news2.m3u8
    #EXTINF:-1 group-title="Movies",Movie B
    https://stream.example.com/movieB.m3u8
    """

    private struct Env {
        let defaults: UserDefaults
        let persistence: PersistenceController
        let session: URLSession
    }

    /// Fresh, isolated UserDefaults suite + PersistenceController per test.
    private func makeEnv() -> Env {
        let suite = "PlaylistStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: suite)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PlaylistStubURLProtocol.self]
        PlaylistStubURLProtocol.reset()
        return Env(defaults: defaults,
                   persistence: PersistenceController(userDefaults: defaults),
                   session: URLSession(configuration: config))
    }

    private func makeStore(_ env: Env) -> PlaylistStore {
        PlaylistStore(persistence: env.persistence, defaults: env.defaults, session: env.session)
    }

    private func data(_ text: String) -> Data { Data(text.utf8) }

    // MARK: - Add / persist

    func testFreshStoreIsEmpty() {
        let store = makeStore(makeEnv())
        XCTAssertTrue(store.playlists.isEmpty)
        XCTAssertTrue(store.favoriteIDs.isEmpty)
        XCTAssertTrue(store.importedChannels.isEmpty)
        XCTAssertEqual(store.allChannels.count, store.sampleChannels.count)
    }

    func testAddPlaylistStoresChannels() throws {
        let store = makeStore(makeEnv())
        let url = URL(string: "https://lists.example.com/a.m3u")!
        let playlist = try store.addPlaylist(data: data(Self.twoChannels), sourceURL: url, title: "My List")

        XCTAssertEqual(playlist.title, "My List")
        XCTAssertEqual(playlist.url, url)
        XCTAssertEqual(store.playlists.count, 1)
        XCTAssertEqual(store.importedChannels.map(\.name), ["News One", "Sports One"])
        XCTAssertEqual(Array(store.allChannels.prefix(2)).map(\.name), ["News One", "Sports One"],
                       "imported channels come before samples")
    }

    func testTitleDefaultsToHostThenOrdinal() throws {
        let store = makeStore(makeEnv())
        let fromURL = try store.addPlaylist(data: data(Self.twoChannels),
                                            sourceURL: URL(string: "https://lists.example.com/a.m3u"), title: nil)
        XCTAssertEqual(fromURL.title, "lists.example.com")
        let local = try store.addPlaylist(data: data(Self.threeChannels), sourceURL: nil, title: "")
        XCTAssertEqual(local.title, "Playlist 2")
    }

    func testAddPostsDidChangeNotification() throws {
        let store = makeStore(makeEnv())
        let exp = expectation(forNotification: PlaylistStore.didChangeNotification, object: store)
        try store.addPlaylist(data: data(Self.twoChannels), sourceURL: nil, title: "x")
        wait(for: [exp], timeout: 1)
    }

    func testPlaylistsReloadInNewInstance() throws {
        let env = makeEnv()
        let store = makeStore(env)
        try store.addPlaylist(data: data(Self.twoChannels), sourceURL: URL(string: "https://a.example.com/1.m3u"), title: "One")
        try store.addPlaylist(data: data(Self.threeChannels), sourceURL: nil, title: "Two")

        let reloaded = PlaylistStore(persistence: PersistenceController(userDefaults: env.defaults),
                                     defaults: env.defaults, session: env.session)
        XCTAssertEqual(reloaded.playlists.map(\.title), ["One", "Two"])
        XCTAssertEqual(reloaded.playlists.map(\.id), store.playlists.map(\.id))
        XCTAssertEqual(reloaded.playlists[0].url, URL(string: "https://a.example.com/1.m3u"))
        XCTAssertEqual(reloaded.importedChannels.map(\.name),
                       ["News One", "Sports One", "Movie A", "News Two", "Movie B"])
    }

    func testStoresAreIsolatedBetweenSuites() throws {
        let storeA = makeStore(makeEnv())
        try storeA.addPlaylist(data: data(Self.twoChannels), sourceURL: nil, title: "A")
        let storeB = makeStore(makeEnv())
        XCTAssertTrue(storeB.playlists.isEmpty)
    }

    func testReimportSameURLReplacesInsteadOfDuplicating() throws {
        let env = makeEnv()
        let store = makeStore(env)
        let url = URL(string: "https://lists.example.com/same.m3u")!
        let first = try store.addPlaylist(data: data(Self.twoChannels), sourceURL: url, title: "Old")
        let second = try store.addPlaylist(data: data(Self.threeChannels), sourceURL: url, title: "New")

        XCTAssertEqual(store.playlists.count, 1)
        XCTAssertEqual(second.id, first.id, "replacement keeps the playlist identity")
        XCTAssertEqual(store.playlists[0].title, "New")
        XCTAssertEqual(store.importedChannels.map(\.name), ["Movie A", "News Two", "Movie B"])

        let reloaded = makeStore(env)
        XCTAssertEqual(reloaded.playlists.count, 1)
        XCTAssertEqual(reloaded.importedChannels.count, 3)
    }

    func testSameContentWithoutURLIsAddedTwice() throws {
        let store = makeStore(makeEnv())
        try store.addPlaylist(data: data(Self.twoChannels), sourceURL: nil, title: "File")
        try store.addPlaylist(data: data(Self.twoChannels), sourceURL: nil, title: "File")
        XCTAssertEqual(store.playlists.count, 2)
    }

    func testNoChannelsThrowsAndStoresNothing() {
        let env = makeEnv()
        let store = makeStore(env)
        XCTAssertThrowsError(try store.addPlaylist(data: data("#EXTM3U\n#EXTINF:-1,Nothing\n"),
                                                   sourceURL: nil, title: nil)) { error in
            XCTAssertEqual(error as? PlaylistStore.ImportError, .noChannels)
        }
        XCTAssertThrowsError(try store.addPlaylist(data: Data(), sourceURL: nil, title: nil)) { error in
            XCTAssertEqual(error as? PlaylistStore.ImportError, .noChannels)
        }
        XCTAssertTrue(store.playlists.isEmpty)
        XCTAssertTrue(makeStore(env).playlists.isEmpty)
    }

    func testImportErrorsHaveDescriptions() {
        XCTAssertEqual(PlaylistStore.ImportError.httpStatus(404).errorDescription, "The server answered with HTTP 404.")
        for error: PlaylistStore.ImportError in [.invalidURL, .unreadable, .noChannels] {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - Remove

    func testRemovePlaylistPersists() throws {
        let env = makeEnv()
        let store = makeStore(env)
        let keep = try store.addPlaylist(data: data(Self.twoChannels), sourceURL: nil, title: "Keep")
        let drop = try store.addPlaylist(data: data(Self.threeChannels), sourceURL: nil, title: "Drop")

        store.removePlaylist(id: drop.id)
        XCTAssertEqual(store.playlists.map(\.id), [keep.id])
        XCTAssertEqual(makeStore(env).playlists.map(\.id), [keep.id])

        store.removePlaylist(id: UUID()) // unknown id is a no-op
        XCTAssertEqual(store.playlists.count, 1)
    }

    // MARK: - Favorites

    func testFavoritesToggleAndPersist() throws {
        let env = makeEnv()
        let store = makeStore(env)
        try store.addPlaylist(data: data(Self.twoChannels), sourceURL: nil, title: "A")
        let news = store.importedChannels[0]

        XCTAssertFalse(store.isFavorite(news))
        store.toggleFavorite(news)
        XCTAssertTrue(store.isFavorite(news))
        XCTAssertEqual(store.favoriteChannels.map(\.name), ["News One"])

        let reloaded = makeStore(env)
        XCTAssertTrue(reloaded.isFavorite(reloaded.importedChannels[0]))
        XCTAssertEqual(reloaded.favoriteChannels.map(\.name), ["News One"])

        reloaded.toggleFavorite(reloaded.importedChannels[0])
        XCTAssertFalse(reloaded.isFavorite(news))
        XCTAssertTrue(makeStore(env).favoriteIDs.isEmpty)
    }

    func testFavoritesSurviveReimportBecauseTheyAreKeyedByStreamURL() throws {
        let store = makeStore(makeEnv())
        let url = URL(string: "https://lists.example.com/fav.m3u")!
        try store.addPlaylist(data: data(Self.twoChannels), sourceURL: url, title: nil)
        let oldID = store.importedChannels[1].id
        store.toggleFavorite(store.importedChannels[1])

        try store.addPlaylist(data: data(Self.twoChannels), sourceURL: url, title: nil)
        XCTAssertNotEqual(store.importedChannels[1].id, oldID, "channel ids are regenerated on import")
        XCTAssertTrue(store.isFavorite(store.importedChannels[1]))
        XCTAssertEqual(store.favoriteChannels.map(\.name), ["Sports One"])
    }

    // MARK: - Grouping

    func testGroupedChannelsPreservesFirstSeenOrder() throws {
        let store = makeStore(makeEnv())
        try store.addPlaylist(data: data(Self.threeChannels), sourceURL: nil, title: "A")
        try store.addPlaylist(data: data(Self.twoChannels), sourceURL: nil, title: "B")

        let groups = store.groupedChannels(store.importedChannels)
        XCTAssertEqual(groups.map(\.group), ["Movies", "News", "Sports"])
        XCTAssertEqual(groups[0].channels.map(\.name), ["Movie A", "Movie B"])
        XCTAssertEqual(groups[1].channels.map(\.name), ["News Two", "News One"])
        XCTAssertEqual(groups[2].channels.map(\.name), ["Sports One"])
    }

    func testGroupedChannelsDefaultsToAllChannels() throws {
        let store = makeStore(makeEnv())
        try store.addPlaylist(data: data(Self.twoChannels), sourceURL: nil, title: "A")
        let groups = store.groupedChannels()
        XCTAssertEqual(Array(groups.prefix(2)).map(\.group), ["News", "Sports"])
        XCTAssertEqual(groups.reduce(0) { $0 + $1.channels.count }, store.allChannels.count)
    }

    // MARK: - importPlaylist(from:)

    func testImportFromURL200() async throws {
        let env = makeEnv()
        let store = makeStore(env)
        let playlistURL = "https://lists.example.com/iptv/list.m3u"
        PlaylistStubURLProtocol.stub(playlistURL, status: 200, body: """
        #EXTM3U
        #EXTINF:-1 group-title="Live",Absolute
        https://stream.example.com/abs.m3u8
        #EXTINF:-1 group-title="Live",Relative
        streams/rel.m3u8
        """)

        let playlist = try await store.importPlaylist(from: "  \(playlistURL)\n")
        XCTAssertEqual(PlaylistStubURLProtocol.requestedURLs.map(\.absoluteString), [playlistURL])
        XCTAssertEqual(playlist.url?.absoluteString, playlistURL)
        XCTAssertEqual(playlist.title, "lists.example.com")
        XCTAssertEqual(playlist.channels.map(\.streamURL.absoluteString), [
            "https://stream.example.com/abs.m3u8",
            "https://lists.example.com/iptv/streams/rel.m3u8",
        ])
        XCTAssertEqual(makeStore(env).playlists.count, 1)
    }

    func testImportFromURL404ThrowsHTTPStatus() async {
        let store = makeStore(makeEnv())
        let url = "https://lists.example.com/missing.m3u"
        PlaylistStubURLProtocol.stub(url, status: 404, body: "Not Found")
        do {
            try await store.importPlaylist(from: url)
            XCTFail("expected httpStatus(404)")
        } catch {
            XCTAssertEqual(error as? PlaylistStore.ImportError, .httpStatus(404))
        }
        XCTAssertTrue(store.playlists.isEmpty)
    }

    func testImportFromURL200WithoutChannelsThrowsNoChannels() async {
        let store = makeStore(makeEnv())
        let url = "https://lists.example.com/empty.m3u"
        PlaylistStubURLProtocol.stub(url, status: 200, body: "#EXTM3U\n")
        do {
            try await store.importPlaylist(from: url)
            XCTFail("expected noChannels")
        } catch {
            XCTAssertEqual(error as? PlaylistStore.ImportError, .noChannels)
        }
    }

    func testImportFromInvalidURLThrowsWithoutNetwork() async {
        let store = makeStore(makeEnv())
        for bad in ["", "   ", "not a url", "ftp://lists.example.com/a.m3u", "file:///tmp/a.m3u", "lists.example.com/a.m3u"] {
            do {
                try await store.importPlaylist(from: bad)
                XCTFail("expected invalidURL for \(bad)")
            } catch {
                XCTAssertEqual(error as? PlaylistStore.ImportError, .invalidURL, "input: \(bad)")
            }
        }
        XCTAssertTrue(PlaylistStubURLProtocol.requestedURLs.isEmpty)
        XCTAssertTrue(store.playlists.isEmpty)
    }

    func testRefreshAllReimportsURLPlaylists() async throws {
        let store = makeStore(makeEnv())
        let url = "https://lists.example.com/refresh.m3u"
        PlaylistStubURLProtocol.stub(url, status: 200, body: Self.twoChannels)
        try await store.importPlaylist(from: url, title: "Mine")
        try store.addPlaylist(data: data(Self.threeChannels), sourceURL: nil, title: "Local")

        PlaylistStubURLProtocol.stub(url, status: 200, body: Self.threeChannels)
        await store.refreshAll()
        XCTAssertEqual(store.playlists.map(\.title), ["Mine", "Local"])
        XCTAssertEqual(store.playlists[0].channels.map(\.name), ["Movie A", "News Two", "Movie B"])
    }
}
