import XCTest
@testable import DashCast

/// Playlist import through the app's own `StubNetwork` (the same stub the UI tests use
/// with `-stubNetwork`). No real network is touched.
@MainActor
final class StubNetworkPlaylistTests: XCTestCase {
    private var session: URLSession!

    override func setUp() async throws {
        StubNetwork.reset()
        session = StubNetwork.makeSession()
    }

    override func tearDown() async throws {
        StubNetwork.reset()
        session.invalidateAndCancel()
    }

    private func makeStore() -> PlaylistStore {
        let defaults = makeIsolatedDefaults()
        return PlaylistStore(persistence: PersistenceController(userDefaults: defaults),
                             defaults: defaults, session: session)
    }

    func testDemoPlaylistImportsThreeChannelsWithLocalStreams() async throws {
        let store = makeStore()
        let playlist = try await store.importPlaylist(from: StubNetwork.url("/playlist.m3u").absoluteString)

        XCTAssertEqual(playlist.channels.map(\.name), ["Stub Channel 1", "Stub Channel 2", "Stub Channel 3"])
        XCTAssertEqual(playlist.title, StubNetwork.host, "Title defaults to the host")
        XCTAssertEqual(store.groupedChannels(store.importedChannels).map(\.group), ["Stub News", "Stub Sports"])
        XCTAssertTrue(playlist.channels[0].streamURL.isFileURL, "Stub channel 1 must play a bundled file")
        XCTAssertTrue(playlist.channels[1].streamURL.isFileURL, "Stub channel 2 must play a bundled file")
        XCTAssertEqual(StubNetwork.requestLog.count, 1)
    }

    func testHTTP404And500AreReportedAsHTTPStatus() async {
        let store = makeStore()
        for (path, code) in [("/missing.m3u", 404), ("/server-error.m3u", 500)] {
            do {
                _ = try await store.importPlaylist(from: StubNetwork.url(path).absoluteString)
                XCTFail("Expected HTTP \(code) for \(path)")
            } catch {
                XCTAssertEqual(error as? PlaylistStore.ImportError, .httpStatus(code))
            }
        }
        XCTAssertTrue(store.playlists.isEmpty)
    }

    func testHeaderOnlyPlaylistThrowsNoChannels() async {
        let store = makeStore()
        do {
            _ = try await store.importPlaylist(from: StubNetwork.url("/empty.m3u").absoluteString)
            XCTFail("Expected noChannels")
        } catch {
            XCTAssertEqual(error as? PlaylistStore.ImportError, .noChannels)
        }
    }

    func testUnknownHostFailsOfflineInsteadOfReachingTheInternet() async {
        let store = makeStore()
        do {
            _ = try await store.importPlaylist(from: "https://example.com/list.m3u")
            XCTFail("Unknown hosts must not resolve")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
    }

    func testPerTestOverrideWinsOverBuiltInFixture() async throws {
        let url = StubNetwork.url("/playlist.m3u")
        StubNetwork.stub(url.absoluteString, .init(text: "#EXTM3U\n#EXTINF:-1,Only One\nhttps://\(StubNetwork.host)/one.mp4\n"))
        let playlist = try await makeStore().importPlaylist(from: url.absoluteString, title: "Custom")
        XCTAssertEqual(playlist.channels.map(\.name), ["Only One"])
        XCTAssertEqual(playlist.title, "Custom")
    }

    func testCanInitOnlyHandlesHTTP() {
        XCTAssertTrue(StubNetwork.canInit(with: URLRequest(url: URL(string: "https://a.b")!)))
        XCTAssertTrue(StubNetwork.canInit(with: URLRequest(url: URL(string: "http://a.b")!)))
        XCTAssertFalse(StubNetwork.canInit(with: URLRequest(url: URL(fileURLWithPath: "/tmp/x"))))
    }

    func testStubPageFixtureServesHTML() async throws {
        let (data, response) = try await session.data(from: StubNetwork.url("/page.html"))
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("<video"))
    }
}
