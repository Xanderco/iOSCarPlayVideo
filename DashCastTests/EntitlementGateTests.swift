import XCTest
import Combine
@testable import DashCast

@MainActor
final class EntitlementGateTests: XCTestCase {
    private let pro = CurrentValueSubject<Bool, Never>(false)
    private var now: Date = ISO8601DateFormatter().date(from: "2026-11-05T10:00:00Z")!
    private var blocked: [EntitlementGate.Decision] = []
    private lazy var defaults: UserDefaults = {
        let suite = "EntitlementGateTests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        return UserDefaults(suiteName: suite)!
    }()

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func makeGate(limits: EntitlementGate.FreeTierLimits = .standard) -> EntitlementGate {
        EntitlementGate(isProPublisher: pro.eraseToAnyPublisher(),
                        limits: limits,
                        defaults: defaults,
                        calendar: calendar,
                        now: { [unowned self] in self.now },
                        onBlocked: { [unowned self] in self.blocked.append($0) })
    }

    func testStandardFreeTierLimits() {
        XCTAssertEqual(EntitlementGate.FreeTierLimits.standard.maxPlaylistSources, 1)
        XCTAssertEqual(EntitlementGate.FreeTierLimits.standard.dailyCastingMinutes, 15)
    }

    func testFreeUserGetsOnePlaylistSource() {
        let gate = makeGate()
        XCTAssertEqual(gate.check(.addPlaylistSource(existingCount: 0)), .allowed)
        XCTAssertEqual(gate.check(.addPlaylistSource(existingCount: 1)), .playlistLimitReached(limit: 1))
        XCTAssertTrue(blocked.isEmpty, "check() must not present the paywall")
    }

    func testRequestPresentsPaywallWhenBlocked() {
        let gate = makeGate()
        XCTAssertFalse(gate.request(.addPlaylistSource(existingCount: 1)))
        XCTAssertEqual(blocked, [.playlistLimitReached(limit: 1)])
        XCTAssertEqual(gate.lastBlock, .playlistLimitReached(limit: 1))
        XCTAssertNotNil(gate.lastBlock?.message)
    }

    func testProUserIsNeverBlocked() {
        let gate = makeGate()
        pro.send(true)
        XCTAssertTrue(gate.isPro)
        XCTAssertTrue(gate.request(.addPlaylistSource(existingCount: 50)))
        XCTAssertTrue(gate.recordCasting(seconds: 10_000))
        XCTAssertTrue(gate.request(.startCasting))
        XCTAssertEqual(gate.remainingCastingSeconds, .infinity)
        XCTAssertTrue(blocked.isEmpty)
    }

    func testCastingMinutesAccumulateAndBlock() {
        let gate = makeGate()
        XCTAssertEqual(gate.remainingCastingSeconds, 15 * 60)

        XCTAssertTrue(gate.recordCasting(seconds: 10 * 60))
        XCTAssertEqual(gate.remainingCastingSeconds, 5 * 60)
        XCTAssertEqual(gate.check(.startCasting), .allowed)

        XCTAssertFalse(gate.recordCasting(seconds: 6 * 60))
        XCTAssertEqual(gate.remainingCastingSeconds, 0)
        XCTAssertEqual(gate.castingSecondsUsedToday, 15 * 60)
        XCTAssertEqual(gate.check(.startCasting), .dailyCastingLimitReached(minutes: 15))
        XCTAssertEqual(blocked, [.dailyCastingLimitReached(minutes: 15)])
    }

    func testCastingUsagePersistsAcrossLaunchesAndResetsNextDay() {
        let gate = makeGate()
        gate.recordCasting(seconds: 15 * 60)

        let relaunched = makeGate()
        XCTAssertEqual(relaunched.remainingCastingSeconds, 0)

        now = now.addingTimeInterval(24 * 60 * 60)
        XCTAssertEqual(relaunched.remainingCastingSeconds, 15 * 60)
        XCTAssertEqual(relaunched.check(.startCasting), .allowed)
        relaunched.refreshUsage()
        XCTAssertEqual(relaunched.castingSecondsUsedToday, 0)
    }

    func testIgnoresInvalidDurations() {
        let gate = makeGate()
        gate.recordCasting(seconds: -30)
        gate.recordCasting(seconds: .nan)
        XCTAssertEqual(gate.remainingCastingSeconds, 15 * 60)
    }

    func testBecomingProClearsLastBlockAndLosingProRestoresLimits() {
        let gate = makeGate()
        gate.request(.addPlaylistSource(existingCount: 1))
        XCTAssertNotNil(gate.lastBlock)

        pro.send(true)
        XCTAssertNil(gate.lastBlock)

        pro.send(false) // e.g. refund
        XCTAssertFalse(gate.isPro)
        XCTAssertEqual(gate.check(.addPlaylistSource(existingCount: 1)), .playlistLimitReached(limit: 1))
    }

    // MARK: - Enforcement in real features

    private static let m3u = Data("#EXTM3U\n#EXTINF:-1 group-title=\"News\",One\nhttps://stream.example.com/one.m3u8\n".utf8)

    func testPlaylistStoreAllowsOneSourceForFreeUsers() throws {
        let gate = makeGate()
        let store = PlaylistStore(persistence: PersistenceController(userDefaults: defaults), defaults: defaults)
        store.canAddSource = { gate.request(.addPlaylistSource(existingCount: $0)) }
        let first = URL(string: "https://example.com/a.m3u")!

        try store.addPlaylist(data: Self.m3u, sourceURL: first, title: "A")
        // Re-importing the same source is a refresh, not a new source.
        try store.addPlaylist(data: Self.m3u, sourceURL: first, title: "A")
        XCTAssertThrowsError(try store.addPlaylist(data: Self.m3u, sourceURL: URL(string: "https://example.com/b.m3u")!, title: "B")) {
            XCTAssertEqual($0 as? PlaylistStore.ImportError, .proRequired)
        }
        XCTAssertEqual(store.playlists.count, 1)
        XCTAssertEqual(blocked, [.playlistLimitReached(limit: 1)])

        // Buying Pro unlocks unlimited sources.
        pro.send(true)
        try store.addPlaylist(data: Self.m3u, sourceURL: URL(string: "https://example.com/b.m3u")!, title: "B")
        try store.addPlaylist(data: Self.m3u, sourceURL: nil, title: "C")
        XCTAssertEqual(store.playlists.count, 3)
    }

    func testPlayerRefusesToCastWhenFreeAllowanceIsUsedUp() {
        let gate = makeGate()
        let player = VideoPlayerService()
        player.entitlementGate = gate
        let channel = ChannelModel(name: "One", streamURL: URL(string: "https://stream.example.com/one.m3u8")!, groupTitle: "News")

        // `isPlaying` follows AVPlayer's async timeControlStatus since #18 (and never reaches .playing
        // for this fake URL), so assert what the gate controls: whether playback was requested.
        player.load(channel: channel)
        XCTAssertTrue(player.isPlaybackRequested, "Free users can cast while allowance remains")
        player.pause()

        gate.recordCasting(seconds: 15 * 60)
        blocked = []
        player.load(channel: channel)
        XCTAssertFalse(player.isPlaybackRequested)
        XCTAssertEqual(blocked, [.dailyCastingLimitReached(minutes: 15)])

        // Buying Pro unlocks unlimited casting.
        pro.send(true)
        player.play()
        XCTAssertTrue(player.isPlaybackRequested)
        player.pause()
    }

    func testRemainingCastingMinutesConversion() {
        let gate = makeGate()
        XCTAssertEqual(gate.remainingCastingMinutes, 15)

        // 30 seconds used: 870 seconds left -> 15 ceiling minutes
        XCTAssertTrue(gate.recordCasting(seconds: 30))
        XCTAssertEqual(gate.remainingCastingMinutes, 15)

        // 60 seconds used: 840 seconds left -> 14 ceiling minutes
        XCTAssertTrue(gate.recordCasting(seconds: 30))
        XCTAssertEqual(gate.remainingCastingMinutes, 14)

        // Exhaust all seconds: 0 minutes
        XCTAssertFalse(gate.recordCasting(seconds: 840))
        XCTAssertEqual(gate.remainingCastingMinutes, 0)

        // Pro tier reports .max
        pro.send(true)
        XCTAssertEqual(gate.remainingCastingMinutes, .max)
    }

    func testIncrementalCastingTimeAccumulates() {
        let gate = makeGate()
        XCTAssertEqual(gate.remainingCastingMinutes, 15)

        // 5 minutes in small chunks
        XCTAssertTrue(gate.recordCasting(seconds: 150))
        XCTAssertTrue(gate.recordCasting(seconds: 150))
        XCTAssertEqual(gate.remainingCastingSeconds, 600)
        XCTAssertEqual(gate.remainingCastingMinutes, 10)

        // Another 5 minutes
        XCTAssertTrue(gate.recordCasting(seconds: 300))
        XCTAssertEqual(gate.remainingCastingSeconds, 300)
        XCTAssertEqual(gate.remainingCastingMinutes, 5)

        // Final 5 minutes reaching limit
        XCTAssertFalse(gate.recordCasting(seconds: 300))
        XCTAssertEqual(gate.remainingCastingSeconds, 0)
        XCTAssertEqual(gate.remainingCastingMinutes, 0)
        XCTAssertEqual(blocked, [.dailyCastingLimitReached(minutes: 15)])

        // Further casting is refused
        XCTAssertFalse(gate.recordCasting(seconds: 10))
    }

    func testProUserUnlimitedCasting() {
        pro.send(true)
        let gate = makeGate()

        XCTAssertEqual(gate.remainingCastingMinutes, .max)
        XCTAssertEqual(gate.remainingCastingSeconds, .infinity)

        // Simulating hours of casting
        XCTAssertTrue(gate.recordCasting(seconds: 3600 * 5))
        XCTAssertEqual(gate.remainingCastingSeconds, .infinity)
        XCTAssertTrue(blocked.isEmpty)
        XCTAssertEqual(gate.check(.startCasting), .allowed)
    }

    func testPlaylistStoreFileImportEnforcesLimit() throws {
        let gate = makeGate()
        let store = PlaylistStore(persistence: PersistenceController(userDefaults: defaults), defaults: defaults)
        store.canAddSource = { gate.request(.addPlaylistSource(existingCount: $0)) }

        let tempDir = FileManager.default.temporaryDirectory
        let file1 = tempDir.appendingPathComponent("list1_\(UUID().uuidString).m3u")
        let file2 = tempDir.appendingPathComponent("list2_\(UUID().uuidString).m3u")
        try Self.m3u.write(to: file1)
        try Self.m3u.write(to: file2)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
        }

        _ = try store.importPlaylist(fileURL: file1)
        XCTAssertEqual(store.playlists.count, 1)

        XCTAssertThrowsError(try store.importPlaylist(fileURL: file2)) {
            XCTAssertEqual($0 as? PlaylistStore.ImportError, .proRequired)
        }
        XCTAssertEqual(store.playlists.count, 1)

        pro.send(true)
        _ = try store.importPlaylist(fileURL: file2)
        XCTAssertEqual(store.playlists.count, 2)
    }

    func testPlaylistStoreURLImportEnforcesLimit() async throws {
        let gate = makeGate()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PlaylistStubURLProtocol.self]
        let session = URLSession(configuration: config)

        PlaylistStubURLProtocol.reset()
        addTeardownBlock { PlaylistStubURLProtocol.reset() }
        PlaylistStubURLProtocol.stub("https://example.com/one.m3u", status: 200, body: String(decoding: Self.m3u, as: UTF8.self))
        PlaylistStubURLProtocol.stub("https://example.com/two.m3u", status: 200, body: String(decoding: Self.m3u, as: UTF8.self))

        let store = PlaylistStore(persistence: PersistenceController(userDefaults: defaults), defaults: defaults, session: session)
        store.canAddSource = { gate.request(.addPlaylistSource(existingCount: $0)) }

        _ = try await store.importPlaylist(from: "https://example.com/one.m3u", title: "One")
        XCTAssertEqual(store.playlists.count, 1)

        do {
            _ = try await store.importPlaylist(from: "https://example.com/two.m3u", title: "Two")
            XCTFail("Expected proRequired error on second playlist import for free user")
        } catch let error as PlaylistStore.ImportError {
            XCTAssertEqual(error, .proRequired)
        }
        XCTAssertEqual(store.playlists.count, 1)

        // Buying Pro unlocks adding the second playlist
        pro.send(true)
        _ = try await store.importPlaylist(from: "https://example.com/two.m3u", title: "Two")
        XCTAssertEqual(store.playlists.count, 2)
    }

    func testPlaylistStoreReimportingSameURLAllowedForFree() throws {
        let gate = makeGate()
        let store = PlaylistStore(persistence: PersistenceController(userDefaults: defaults), defaults: defaults)
        store.canAddSource = { gate.request(.addPlaylistSource(existingCount: $0)) }
        let url = URL(string: "https://example.com/main.m3u")!

        // Initial import
        try store.addPlaylist(data: Self.m3u, sourceURL: url, title: "Initial Title")
        XCTAssertEqual(store.playlists.count, 1)
        XCTAssertEqual(store.playlists.first?.title, "Initial Title")

        // Re-importing existing URL is permitted as a refresh
        let updatedData = Data("#EXTM3U\n#EXTINF:-1 group-title=\"News\",Updated\nhttps://stream.example.com/updated.m3u8\n".utf8)
        try store.addPlaylist(data: updatedData, sourceURL: url, title: "Updated Title")
        XCTAssertEqual(store.playlists.count, 1)
        XCTAssertEqual(store.playlists.first?.title, "Updated Title")
        XCTAssertEqual(store.playlists.first?.channels.first?.name, "Updated")
        XCTAssertTrue(blocked.isEmpty)
    }

    func testProUnlocksImmediateCastingAfterFreeLimitReached() {
        let gate = makeGate()
        let player = VideoPlayerService()
        player.entitlementGate = gate
        let channel = ChannelModel(name: "Stream", streamURL: URL(string: "https://stream.example.com/live.m3u8")!, groupTitle: "Live")

        // Exhaust free allowance
        gate.recordCasting(seconds: 15 * 60)
        blocked = []

        player.load(channel: channel)
        XCTAssertFalse(player.isPlaybackRequested)
        XCTAssertEqual(blocked, [.dailyCastingLimitReached(minutes: 15)])

        // Purchase Pro
        pro.send(true)
        XCTAssertNil(gate.lastBlock)
        player.play()
        XCTAssertTrue(player.isPlaybackRequested)
        player.pause()
    }

    func testRefundOrRevocationReLocksGate() throws {
        pro.send(true)
        let gate = makeGate()
        let store = PlaylistStore(persistence: PersistenceController(userDefaults: defaults), defaults: defaults)
        store.canAddSource = { gate.request(.addPlaylistSource(existingCount: $0)) }

        try store.addPlaylist(data: Self.m3u, sourceURL: URL(string: "https://example.com/1.m3u")!, title: "1")
        try store.addPlaylist(data: Self.m3u, sourceURL: URL(string: "https://example.com/2.m3u")!, title: "2")
        XCTAssertEqual(store.playlists.count, 2)

        // Refund occurs
        pro.send(false)
        XCTAssertFalse(gate.isPro)

        // Adding 3rd source is blocked
        XCTAssertThrowsError(try store.addPlaylist(data: Self.m3u, sourceURL: URL(string: "https://example.com/3.m3u")!, title: "3")) {
            XCTAssertEqual($0 as? PlaylistStore.ImportError, .proRequired)
        }
        XCTAssertEqual(store.playlists.count, 2)

        // Re-importing existing 1st source is still allowed
        try store.addPlaylist(data: Self.m3u, sourceURL: URL(string: "https://example.com/1.m3u")!, title: "1 Updated")
        XCTAssertEqual(store.playlists.count, 2)
    }

    func testSharedInstancesAreProperlyWired() {
        XCTAssertNotNil(PlaylistStore.shared.canAddSource)
        XCTAssertTrue(VideoPlayerService.shared.entitlementGate === EntitlementGate.shared)
        XCTAssertTrue(CarPlayMirrorController.shared.entitlementGate === EntitlementGate.shared)
    }

    func testCarPlayMirrorControllerEnforcesGate() {
        let gate = makeGate()
        let controller = CarPlayMirrorController()
        controller.entitlementGate = gate

        // Exhaust allowance
        gate.recordCasting(seconds: 15 * 60)
        XCTAssertEqual(gate.remainingCastingSeconds, 0)
        XCTAssertFalse(gate.isPro)

        // When gate allowance is 0, hasAllowance is false
        let hasAllowance = controller.entitlementGate.isPro || controller.entitlementGate.remainingCastingSeconds > 0
        XCTAssertFalse(hasAllowance)

        // Buying Pro restores allowance
        pro.send(true)
        let hasAllowancePro = controller.entitlementGate.isPro || controller.entitlementGate.remainingCastingSeconds > 0
        XCTAssertTrue(hasAllowancePro)
    }
}
