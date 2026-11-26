import XCTest
@testable import DashCast

final class PersistenceTests: XCTestCase {
    var testDefaults: UserDefaults!
    var persistence: PersistenceController!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "DashCastTestDefaults")
        testDefaults.removePersistentDomain(forName: "DashCastTestDefaults")
        persistence = PersistenceController(userDefaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "DashCastTestDefaults")
        super.tearDown()
    }

    func testSaveAndLoadTrips() {
        let trip = TripModel(
            id: UUID(),
            distanceMeters: 4200,
            averageSpeedKmh: 45,
            maxSpeedKmh: 75,
            drivingScore: 98
        )
        persistence.saveTrips([trip])

        let loaded = persistence.loadTrips()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, trip.id)
        XCTAssertEqual(loaded.first?.distanceMeters, 4200)

        persistence.clearTrips()
        XCTAssertTrue(persistence.loadTrips().isEmpty)
    }

    func testClearPlaylistsClearsPersistence() {
        let playlist = IPTVPlaylist(
            title: "Road Streams",
            channels: [
                ChannelModel(name: "Demo", streamURL: URL(string: "https://example.com/live.m3u8")!)
            ]
        )
        persistence.savePlaylists([playlist])
        XCTAssertEqual(persistence.loadPlaylists().count, 1)

        persistence.clearPlaylists()
        XCTAssertTrue(persistence.loadPlaylists().isEmpty)
    }

    @MainActor
    func testPlaylistStoreClearPlaylistsRemovesAllAndNotifies() {
        let store = PlaylistStore(persistence: persistence, defaults: testDefaults)
        let m3u = """
        #EXTM3U
        #EXTINF:-1,Stream 1
        https://example.com/1.m3u8
        """
        XCTAssertNoThrow(try store.addPlaylist(data: Data(m3u.utf8), sourceURL: nil, title: "Test"))
        XCTAssertEqual(store.playlists.count, 1)
        XCTAssertEqual(persistence.loadPlaylists().count, 1)

        let expectation = expectation(forNotification: PlaylistStore.didChangeNotification, object: store)
        store.clearPlaylists()
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(store.playlists.isEmpty)
        XCTAssertTrue(persistence.loadPlaylists().isEmpty)
        XCTAssertFalse(store.sampleChannels.isEmpty)
    }

    func testDataPrivacyAndGuideLocalizationKeysExistInCatalog() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectDir
            .appendingPathComponent("DashCast")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = try XCTUnwrap(json?["strings"] as? [String: [String: Any]])

        let expectedKeys = [
            "Car Display Guide",
            "Data & Privacy",
            "All trips and playlists stay on your device.",
            "Clear Trip History",
            "Clear Playlists",
            "%lld saved",
            "Clear all saved trips?",
            "This removes your saved drive routes and trip history from this device.",
            "Clear all imported playlists?",
            "This removes your imported playlists from this device. Built-in demo videos remain available."
        ]

        for key in expectedKeys {
            let entry = try XCTUnwrap(strings[key], "Missing Localizable.xcstrings key: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]])
            let enValue = (localizations["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
            let esValue = (localizations["es"]?["stringUnit"] as? [String: Any])?["value"] as? String
            XCTAssertFalse(enValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Empty EN value for \(key)")
            XCTAssertFalse(esValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Empty ES value for \(key)")
        }
    }
}
