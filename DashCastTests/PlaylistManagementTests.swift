import XCTest
@testable import DashCast

@MainActor
final class PlaylistManagementTests: XCTestCase {

    private static let playlistA = """
    #EXTM3U
    #EXTINF:-1 group-title="News",News 1
    https://stream.example.com/news1.m3u8
    #EXTINF:-1 group-title="Adult",Adult 1
    https://stream.example.com/adult1.m3u8
    """

    private static let playlistB = """
    #EXTM3U
    #EXTINF:-1 group-title="Sports" tvg-logo="https://img.example.com/sp.png",Sports "HD"
    https://stream.example.com/sports1.m3u8
    #EXTINF:-1 group-title="Movies",Movie 1
    https://stream.example.com/movie1.m3u8
    """

    private func makeEnv() -> (defaults: UserDefaults, persistence: PersistenceController, session: URLSession) {
        let suite = "PlaylistManagementTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: suite)
        }
        let config = URLSessionConfiguration.ephemeral
        return (defaults, PersistenceController(userDefaults: defaults), URLSession(configuration: config))
    }

    // MARK: - Rename & Reorder

    func testRenamePlaylistTrimsPersistsAndIgnoresBlank() throws {
        let env = makeEnv()
        let store = PlaylistStore(persistence: env.persistence, defaults: env.defaults, session: env.session)
        let added = try store.addPlaylist(data: Data(Self.playlistA.utf8), sourceURL: nil, title: "Old Name")

        store.renamePlaylist(id: added.id, title: "  Living Room TV  ")
        XCTAssertEqual(store.playlists.first?.title, "Living Room TV")

        // Blank or whitespace-only titles are ignored.
        store.renamePlaylist(id: added.id, title: "   \n ")
        XCTAssertEqual(store.playlists.first?.title, "Living Room TV")

        let reloaded = PlaylistStore(persistence: PersistenceController(userDefaults: env.defaults),
                                     defaults: env.defaults, session: env.session)
        XCTAssertEqual(reloaded.playlists.first?.title, "Living Room TV")
    }

    func testMovePlaylistsReordersAndPersistsAcrossInstances() throws {
        let env = makeEnv()
        let store = PlaylistStore(persistence: env.persistence, defaults: env.defaults, session: env.session)
        try store.addPlaylist(data: Data(Self.playlistA.utf8), sourceURL: nil, title: "First")
        try store.addPlaylist(data: Data(Self.playlistB.utf8), sourceURL: nil, title: "Second")
        try store.addPlaylist(data: Data(Self.playlistA.utf8), sourceURL: nil, title: "Third")

        // Move "First" (index 0) to the end (toOffset 3).
        store.movePlaylists(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(store.playlists.map(\.title), ["Second", "Third", "First"])

        // Move "First" (now index 2) back to index 0.
        store.movePlaylists(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(store.playlists.map(\.title), ["First", "Second", "Third"])

        let reloaded = PlaylistStore(persistence: PersistenceController(userDefaults: env.defaults),
                                     defaults: env.defaults, session: env.session)
        XCTAssertEqual(reloaded.playlists.map(\.title), ["First", "Second", "Third"])
    }

    // MARK: - Group Hiding

    func testHideAndShowChannelGroupsFiltersVisibleChannelsAndPersists() throws {
        let env = makeEnv()
        let store = PlaylistStore(persistence: env.persistence, defaults: env.defaults, session: env.session)
        try store.addPlaylist(data: Data(Self.playlistA.utf8), sourceURL: nil, title: "A")
        try store.addPlaylist(data: Data(Self.playlistB.utf8), sourceURL: nil, title: "B")

        XCTAssertTrue(store.availableGroups.contains("Adult"))
        XCTAssertTrue(store.visibleChannels.contains(where: { $0.groupTitle == "Adult" }))

        store.setGroupHidden("Adult", hidden: true)
        XCTAssertTrue(store.isGroupHidden("Adult"))
        XCTAssertFalse(store.visibleChannels.contains(where: { $0.groupTitle == "Adult" }))
        XCTAssertFalse(store.visibleGroupedChannels().map(\.group).contains("Adult"))
        // Raw allChannels stays intact so un-hiding restores immediately.
        XCTAssertTrue(store.allChannels.contains(where: { $0.groupTitle == "Adult" }))

        let reloaded = PlaylistStore(persistence: PersistenceController(userDefaults: env.defaults),
                                     defaults: env.defaults, session: env.session)
        XCTAssertTrue(reloaded.isGroupHidden("Adult"))
        XCTAssertFalse(reloaded.visibleChannels.contains(where: { $0.groupTitle == "Adult" }))

        reloaded.showAllGroups()
        XCTAssertTrue(reloaded.hiddenGroups.isEmpty)
        XCTAssertTrue(reloaded.visibleChannels.contains(where: { $0.groupTitle == "Adult" }))
    }

    // MARK: - M3U Export & JSON Backup

    func testExportM3URoundTripsThroughIPTVParser() throws {
        let env = makeEnv()
        let store = PlaylistStore(persistence: env.persistence, defaults: env.defaults, session: env.session)
        let playlist = try store.addPlaylist(data: Data(Self.playlistB.utf8), sourceURL: nil, title: "Exportable")

        let m3u = PlaylistBackupService.exportM3U(playlist: playlist)
        let reparsed = IPTVParser.parseM3U(content: m3u)
        XCTAssertEqual(reparsed.count, 2)
        XCTAssertEqual(reparsed[0].groupTitle, "Sports")
        XCTAssertEqual(reparsed[0].logoURL?.absoluteString, "https://img.example.com/sp.png")
        XCTAssertEqual(reparsed[0].streamURL.absoluteString, "https://stream.example.com/sports1.m3u8")
        XCTAssertEqual(reparsed[1].name, "Movie 1")
    }

    func testBackupExportAndImportRoundTripMergeAndReplace() throws {
        let env1 = makeEnv()
        let sourceStore = PlaylistStore(persistence: env1.persistence, defaults: env1.defaults, session: env1.session)
        let p1 = try sourceStore.addPlaylist(
            data: Data(Self.playlistA.utf8),
            sourceURL: URL(string: "https://lists.example.com/a.m3u"),
            title: "Alpha"
        )
        sourceStore.toggleFavorite(p1.channels[0])
        sourceStore.setGroupHidden("Adult", hidden: true)

        let backupData = try sourceStore.exportBackupData()

        // Merge into a store that already has a different playlist.
        let env2 = makeEnv()
        let targetStore = PlaylistStore(persistence: env2.persistence, defaults: env2.defaults, session: env2.session)
        try targetStore.addPlaylist(
            data: Data(Self.playlistB.utf8),
            sourceURL: URL(string: "https://lists.example.com/b.m3u"),
            title: "Beta"
        )

        let mergeSummary = try targetStore.importBackupData(backupData, replaceExisting: false)
        XCTAssertEqual(mergeSummary.playlistsAdded, 1)
        XCTAssertEqual(mergeSummary.playlistsUpdated, 0)
        XCTAssertEqual(mergeSummary.favoritesAdded, 1)
        XCTAssertEqual(mergeSummary.hiddenGroupsAdded, 1)
        XCTAssertEqual(targetStore.playlists.map(\.title), ["Beta", "Alpha"])
        XCTAssertTrue(targetStore.isGroupHidden("Adult"))
        XCTAssertEqual(targetStore.favoriteChannels.map(\.name), ["News 1"])

        // Replace existing clears "Beta" and restores only "Alpha".
        let replaceSummary = try targetStore.importBackupData(backupData, replaceExisting: true)
        XCTAssertEqual(replaceSummary.playlistsAdded, 1)
        XCTAssertEqual(targetStore.playlists.map(\.title), ["Alpha"])
    }

    func testBackupImportRespectsEntitlementGateAtomically() throws {
        let env = makeEnv()
        let store = PlaylistStore(persistence: env.persistence, defaults: env.defaults, session: env.session)
        let p1 = try store.addPlaylist(data: Data(Self.playlistA.utf8), sourceURL: nil, title: "One")
        let p2 = try store.addPlaylist(data: Data(Self.playlistB.utf8), sourceURL: nil, title: "Two")
        let twoPlaylistBackup = try PlaylistBackupService.encodeBackup(
            playlists: [p1, p2],
            favoriteStreamURLs: [],
            hiddenGroups: []
        )

        let freeEnv = makeEnv()
        let freeStore = PlaylistStore(persistence: freeEnv.persistence, defaults: freeEnv.defaults, session: freeEnv.session)
        freeStore.canAddSource = { count in count < 1 }

        XCTAssertThrowsError(try freeStore.importBackupData(twoPlaylistBackup)) { error in
            XCTAssertEqual(error as? PlaylistStore.ImportError, .proRequired)
        }
        XCTAssertTrue(freeStore.playlists.isEmpty, "failed backup import must not leave partial playlists behind")
    }

    func testBackupDecodeRejectsInvalidUnsupportedOrEmptyPayloads() throws {
        XCTAssertThrowsError(try PlaylistBackupService.decodeBackup(from: Data("not-json".utf8))) { error in
            XCTAssertEqual(error as? PlaylistBackupError, .invalidFormat)
        }

        let futureVersionJSON = """
        {"version": 99, "exportedAt": "2026-11-25T00:00:00Z", "playlists": [], "favoriteStreamURLs": [], "hiddenGroups": []}
        """
        XCTAssertThrowsError(try PlaylistBackupService.decodeBackup(from: Data(futureVersionJSON.utf8))) { error in
            XCTAssertEqual(error as? PlaylistBackupError, .unsupportedVersion(99))
        }

        let emptyBackupJSON = """
        {"version": 1, "exportedAt": "2026-11-25T00:00:00Z", "playlists": [], "favoriteStreamURLs": [], "hiddenGroups": []}
        """
        XCTAssertThrowsError(try PlaylistBackupService.decodeBackup(from: Data(emptyBackupJSON.utf8))) { error in
            XCTAssertEqual(error as? PlaylistBackupError, .emptyBackup)
        }
    }
}
