import XCTest
@testable import DashCast

@MainActor
final class LaunchConfigurationTests: XCTestCase {
    func testUnitTestHostIsNotInUITestMode() {
        // The unit-test host app is launched without test arguments, so none of the
        // UI-test hooks may be active (they would wipe defaults / stub the network).
        XCTAssertFalse(LaunchConfiguration.isUITesting)
        XCTAssertFalse(LaunchConfiguration.shouldStubNetwork)
        XCTAssertFalse(LaunchConfiguration.shouldSeedDemoData)
    }

    func testArgumentNamesAreStable() {
        // UI tests and Scripts/ rely on these exact strings.
        XCTAssertEqual(LaunchConfiguration.uiTestingArgument, "-uiTesting")
        XCTAssertEqual(LaunchConfiguration.legacyUITestingArgument, "-UITests")
        XCTAssertEqual(LaunchConfiguration.seedDemoDataArgument, "-seedDemoData")
        XCTAssertEqual(LaunchConfiguration.stubNetworkArgument, "-stubNetwork")
    }

    func testSeederAddsDemoPlaylistAndOneFavoriteIdempotently() {
        let defaults = makeIsolatedDefaults()
        let store = PlaylistStore(persistence: PersistenceController(userDefaults: defaults),
                                  defaults: defaults, session: StubNetwork.makeSession())

        TestDataSeeder.seedPlaylists(store: store)
        TestDataSeeder.seedPlaylists(store: store)

        XCTAssertEqual(store.playlists.count, 1, "Seeding twice must not duplicate the playlist")
        XCTAssertEqual(store.playlists.first?.title, TestDataSeeder.playlistTitle)
        XCTAssertEqual(store.playlists.first?.channels.count, 3)
        // Favorites are keyed by stream URL; Stub Channel 1 plays the bundled night_drive clip,
        // which the built-in sample channel uses too, so the favorite shows up for both.
        XCTAssertEqual(store.favoriteChannels.first?.name, "Stub Channel 1")
        XCTAssertTrue(store.favoriteChannels.allSatisfy { $0.streamURL == store.playlists[0].channels[0].streamURL })
    }
}
