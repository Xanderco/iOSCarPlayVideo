import XCTest
import SwiftUI
@testable import DashCast

final class MediaSourcesEntryTests: XCTestCase {

    // MARK: - MediaServerKind Tests

    func testMediaServerKindDisplayNamesAndProperties() {
        XCTAssertEqual(MediaServerKind.jellyfin.displayName, "Jellyfin")
        XCTAssertEqual(MediaServerKind.emby.displayName, "Emby")
        XCTAssertEqual(MediaServerKind.jellyfin.apiPathPrefix, "")
        XCTAssertEqual(MediaServerKind.emby.apiPathPrefix, "/emby")
        XCTAssertEqual(MediaServerKind.jellyfin.authorizationHeaderName, "Authorization")
        XCTAssertEqual(MediaServerKind.emby.authorizationHeaderName, "X-Emby-Authorization")
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
            streamURL: streamURL,
            groupTitle: "\(account.serverName) (Jellyfin)",
            logoURL: nil
        )

        XCTAssertEqual(channel.name, "Grand Tour Season 1 Episode 3")
        XCTAssertEqual(channel.groupTitle, "Basement Jellyfin (Jellyfin)")
        XCTAssertTrue(channel.streamURL.absoluteString.contains("item-777"))
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

    // MARK: - PlaylistQRImportCopy Localization Tests

    func testPlaylistQRImportCopyFormatting() {
        XCTAssertEqual(
            PlaylistQRImportCopy.importingMessage(hostOrURL: "tv.example.org"),
            "Importing tv.example.org…"
        )
        XCTAssertEqual(
            PlaylistQRImportCopy.importedMessage(title: "Road Trip TV", channels: 42),
            "Added \"Road Trip TV\" (42 channels)"
        )
        XCTAssertEqual(
            PlaylistQRImportCopy.invalidPayloadMessage(),
            "That QR code doesn't contain a playlist link."
        )
    }

    @MainActor
    func testPlaylistQRImportCopySwiftUIKeys() {
        XCTAssertEqual(PlaylistQRImportCopy.pasteLinkPlaceholderKey, LocalizedStringKey(PlaylistQRImportCopy.pasteLinkPlaceholderString))
        XCTAssertEqual(PlaylistQRImportCopy.importButtonKey, LocalizedStringKey(PlaylistQRImportCopy.importButtonString))
        XCTAssertEqual(PlaylistQRImportCopy.navigationTitleKey, LocalizedStringKey(PlaylistQRImportCopy.navigationTitleString))
        XCTAssertEqual(PlaylistQRImportCopy.closeKey, LocalizedStringKey(PlaylistQRImportCopy.closeString))
        XCTAssertEqual(PlaylistQRImportCopy.noCameraKey, LocalizedStringKey(PlaylistQRImportCopy.noCameraString))
        XCTAssertEqual(PlaylistQRImportCopy.cameraDeniedKey, LocalizedStringKey(PlaylistQRImportCopy.cameraDeniedString))
        XCTAssertEqual(PlaylistQRImportCopy.openSettingsKey, LocalizedStringKey(PlaylistQRImportCopy.openSettingsString))
        XCTAssertEqual(PlaylistQRImportCopy.waitingForCameraKey, LocalizedStringKey(PlaylistQRImportCopy.waitingForCameraString))
        XCTAssertEqual(PlaylistQRImportCopy.scanInstructionKey, LocalizedStringKey(PlaylistQRImportCopy.scanInstructionString))
        XCTAssertEqual(PlaylistQRImportCopy.doneKey, LocalizedStringKey(PlaylistQRImportCopy.doneString))
        XCTAssertEqual(PlaylistQRImportCopy.scanAgainKey, LocalizedStringKey(PlaylistQRImportCopy.scanAgainString))
    }

    func testPlaylistQRImportCopyLocalizationKeysComplete() throws {
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

        for key in PlaylistQRImportCopy.allLocalizationKeys {
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
