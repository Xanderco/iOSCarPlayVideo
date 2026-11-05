import XCTest
@testable import DashCast

final class MediaSourcesEntryTests: XCTestCase {

    // MARK: - MediaServerKind Tests

    func testMediaServerKindDisplayNamesAndPorts() {
        XCTAssertEqual(MediaServerKind.jellyfin.displayName, "Jellyfin")
        XCTAssertEqual(MediaServerKind.emby.displayName, "Emby")
        XCTAssertEqual(MediaServerKind.jellyfin.defaultPort, 8096)
        XCTAssertEqual(MediaServerKind.emby.defaultPort, 8096)
        XCTAssertEqual(MediaServerKind.allCases.count, 2)
    }

    // MARK: - PlaylistQRPayload Tests

    func testPlaylistQRPayloadBasicHTTPS() {
        let input = "https://example.com/playlist.m3u8"
        let parsed = PlaylistQRPayload.playlistURL(from: input)
        XCTAssertEqual(parsed?.absoluteString, "https://example.com/playlist.m3u8")
    }

    func testPlaylistQRPayloadWithURLPrefix() {
        let input1 = "URL:http://192.168.1.50:8000/live.m3u"
        let parsed1 = PlaylistQRPayload.playlistURL(from: input1)
        XCTAssertEqual(parsed1?.absoluteString, "http://192.168.1.50:8000/live.m3u")

        let input2 = "URLTO:https://stream.provider.tv/feed.m3u8"
        let parsed2 = PlaylistQRPayload.playlistURL(from: input2)
        XCTAssertEqual(parsed2?.absoluteString, "https://stream.provider.tv/feed.m3u8")
    }

    func testPlaylistQRPayloadWithWhitespaceAndPunctuation() {
        let input = "  \n  <https://media.server.internal:8443/export/channels.m3u8>;  \n"
        let parsed = PlaylistQRPayload.playlistURL(from: input)
        XCTAssertEqual(parsed?.absoluteString, "https://media.server.internal:8443/export/channels.m3u8")
    }

    func testPlaylistQRPayloadRejectsInvalidSchemes() {
        XCTAssertNil(PlaylistQRPayload.playlistURL(from: "ftp://192.168.1.10/list.m3u"))
        XCTAssertNil(PlaylistQRPayload.playlistURL(from: "smb://nas/share/movies.m3u"))
        XCTAssertNil(PlaylistQRPayload.playlistURL(from: "file:///var/mobile/playlist.m3u"))
        XCTAssertNil(PlaylistQRPayload.playlistURL(from: "WIFI:S:HomeNet;P:password;;"))
        XCTAssertNil(PlaylistQRPayload.playlistURL(from: ""))
        XCTAssertNil(PlaylistQRPayload.playlistURL(from: "    "))
    }

    func testPlaylistQRPayloadWithEmbeddedText() {
        let input = "Scan this in DashCast to import: https://tv.example.org/stream.m3u Enjoy!"
        let parsed = PlaylistQRPayload.playlistURL(from: input)
        XCTAssertEqual(parsed?.absoluteString, "https://tv.example.org/stream.m3u")
    }

    // MARK: - MediaServerAccount Tests

    func testMediaServerAccountModelCodable() throws {
        let account = MediaServerAccount(
            kind: .jellyfin,
            baseURL: URL(string: "http://192.168.1.100:8096")!,
            serverName: "Home Server",
            username: "driver",
            userId: "user-123",
            deviceId: "device-xyz"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(account)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MediaServerAccount.self, from: data)

        XCTAssertEqual(account.id, decoded.id)
        XCTAssertEqual(account.kind, decoded.kind)
        XCTAssertEqual(account.baseURL, decoded.baseURL)
        XCTAssertEqual(account.serverName, decoded.serverName)
        XCTAssertEqual(account.username, decoded.username)
        XCTAssertEqual(account.userId, decoded.userId)
        XCTAssertEqual(account.deviceId, decoded.deviceId)
    }

    // MARK: - MediaItem and ChannelModel Conversion Tests

    func testChannelModelGenerationFromMediaServer() {
        let account = MediaServerAccount(
            kind: .jellyfin,
            baseURL: URL(string: "http://192.168.1.100:8096")!,
            serverName: "Basement Jellyfin",
            username: "alexander",
            userId: "u-456",
            deviceId: "d-789"
        )

        let streamURL = account.baseURL.appendingPathComponent("Videos/item-777/stream.m3u8")
        let channel = ChannelModel(
            name: "Grand Tour Season 1 Episode 3",
            streamURL: streamURL.absoluteString,
            groupTitle: "\(account.serverName) (Jellyfin)",
            logoURL: nil
        )

        XCTAssertEqual(channel.name, "Grand Tour Season 1 Episode 3")
        XCTAssertEqual(channel.groupTitle, "Basement Jellyfin (Jellyfin)")
        XCTAssertTrue(channel.streamURL.contains("item-777"))
    }

    // MARK: - Store Integration Tests

    @MainActor
    func testMediaServerStoreIsolatedOperations() {
        let suite = "MediaSourcesEntryTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let tokenStore = InMemoryMediaServerTokenStore()
        let store = MediaServerStore(defaults: defaults, tokenStore: tokenStore)

        XCTAssertTrue(store.accounts.isEmpty)

        let account = MediaServerAccount(
            kind: .emby,
            baseURL: URL(string: "https://emby.lan:8920")!,
            serverName: "Family Movies",
            username: "passenger",
            userId: "p-01",
            deviceId: "dev-01"
        )

        _ = tokenStore.setToken("auth-token-secret", for: account.id)
        XCTAssertEqual(tokenStore.token(for: account.id), "auth-token-secret")

        store.remove(account)
        XCTAssertTrue(store.accounts.isEmpty)
    }
}
