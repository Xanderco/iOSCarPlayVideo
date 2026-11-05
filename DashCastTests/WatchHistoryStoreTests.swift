import XCTest
@testable import DashCast

@MainActor
final class WatchHistoryStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "WatchHistoryStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func channel(_ name: String, group: String = "News") -> ChannelModel {
        ChannelModel(name: name, streamURL: URL(string: "https://example.com/\(name).m3u8")!, groupTitle: group)
    }

    func testRecentsAreNewestFirstAndDeduplicatedByStreamURL() {
        let store = WatchHistoryStore(defaults: defaults)
        let a = channel("a"), b = channel("b")
        store.recordStart(a, now: Date(timeIntervalSince1970: 1))
        store.recordStart(b, now: Date(timeIntervalSince1970: 2))
        // Same stream, new ChannelModel id (playlists regenerate ids on import).
        store.recordStart(channel("a"), now: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(store.recents.map(\.channel.name), ["a", "b"])
        XCTAssertEqual(store.entries.count, 2)
    }

    func testContinueWatchingOnlyListsStartedUnfinishedVideos() {
        let store = WatchHistoryStore(defaults: defaults)
        let live = channel("live"), started = channel("started"), done = channel("done"), barely = channel("barely")
        store.recordProgress(live, position: 120, duration: 0)
        store.recordProgress(started, position: 300, duration: 1200)
        store.recordProgress(done, position: 1190, duration: 1200)
        store.recordProgress(barely, position: 3, duration: 1200)

        XCTAssertEqual(store.continueWatching.map(\.channel.name), ["started"])
        XCTAssertEqual(store.entry(for: started)?.progress ?? 0, 0.25, accuracy: 0.0001)
        XCTAssertNil(store.entry(for: live)?.progress)
        XCTAssertTrue(store.entry(for: live)?.isLive ?? false)
    }

    func testHistoryPersistsAndIsCapped() {
        let store = WatchHistoryStore(defaults: defaults)
        for i in 0..<(WatchHistoryStore.maxEntries + 5) {
            store.recordStart(channel("c\(i)"), now: Date(timeIntervalSince1970: Double(i)))
        }
        XCTAssertEqual(store.entries.count, WatchHistoryStore.maxEntries)

        let reloaded = WatchHistoryStore(defaults: defaults)
        XCTAssertEqual(reloaded.entries.count, WatchHistoryStore.maxEntries)
        XCTAssertEqual(reloaded.recents.first?.channel.name, "c\(WatchHistoryStore.maxEntries + 4)")

        reloaded.clear()
        XCTAssertTrue(WatchHistoryStore(defaults: defaults).entries.isEmpty)
    }

    func testLocalFilesNeverLookLive() {
        let store = WatchHistoryStore(defaults: defaults)
        let local = ChannelModel(name: "clip", streamURL: URL(fileURLWithPath: "/tmp/clip.mov"), groupTitle: "Local Videos")
        XCTAssertFalse(store.looksLive(local))
        XCTAssertTrue(store.looksLive(channel("tv")))
    }

    func testQueueNeighborWrapsAround() {
        let list = [channel("1"), channel("2"), channel("3")]
        XCTAssertEqual(PlaybackQueue.neighbor(of: list[2], offset: 1, in: list)?.name, "1")
        XCTAssertEqual(PlaybackQueue.neighbor(of: list[0], offset: -1, in: list)?.name, "3")
        XCTAssertEqual(PlaybackQueue.neighbor(of: list[1], offset: 1, in: list)?.name, "3")
        XCTAssertNil(PlaybackQueue.neighbor(of: list[0], offset: 1, in: [list[0]]))
        XCTAssertNil(PlaybackQueue.neighbor(of: nil, offset: 1, in: list))
    }

    func testTimecodeFormatting() {
        XCTAssertEqual(TimecodeFormatter.string(0), "0:00")
        XCTAssertEqual(TimecodeFormatter.string(65), "1:05")
        XCTAssertEqual(TimecodeFormatter.string(3725), "1:02:05")
        XCTAssertEqual(TimecodeFormatter.string(.nan), "0:00")
    }
}
