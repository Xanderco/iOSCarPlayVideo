import XCTest
import Combine
@testable import DashCast

final class OfflineDeadzoneCacheTests: XCTestCase {
    var tempDirectory: URL!
    var storageEngine: DeadzoneCacheStorageEngine!
    var cacheService: DeadzoneCacheService!
    var preloader: MediaPreloaderService!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DashCastTestCache_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        storageEngine = DeadzoneCacheStorageEngine(customDirectory: tempDirectory)
        cacheService = DeadzoneCacheService(storageEngine: storageEngine, initialMaxSizeBytes: 5 * 1024 * 1024) // 5 MB for fast testing
        preloader = MediaPreloaderService(cacheService: cacheService)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        storageEngine = nil
        cacheService = nil
        preloader = nil
        super.tearDown()
    }

    // MARK: - 1. Model & Metrics Tests

    func testDeadzoneCacheItemModelInitializationAndConversion() {
        let sourceURL = URL(string: "https://example.com/live/stream.m3u8")!
        let item = DeadzoneCacheItem(
            sourceURL: sourceURL,
            localFileName: "test_cache.mp4",
            channelName: "Formula 1 Live",
            groupTitle: "Motorsport",
            fileSizeBytes: 1024 * 1024,
            isPinned: true,
            isComplete: true,
            downloadProgress: 1.0,
            status: .ready
        )

        XCTAssertEqual(item.channelName, "Formula 1 Live")
        XCTAssertEqual(item.groupTitle, "Motorsport")
        XCTAssertEqual(item.fileSizeBytes, 1024 * 1024)
        XCTAssertTrue(item.isPinned)
        XCTAssertTrue(item.isComplete)
        XCTAssertEqual(item.status, .ready)

        let channelModel = item.toChannelModel(cacheDirectory: tempDirectory)
        XCTAssertTrue(channelModel.name.contains("Formula 1 Live"))
        XCTAssertTrue(channelModel.streamURL.isFileURL)
        XCTAssertEqual(channelModel.groupTitle, "Offline Deadzone Cache")
    }

    func testCacheStorageMetricsFormatting() {
        let metricsMB = CacheStorageMetrics(
            currentSizeBytes: 500 * 1024 * 1024,
            maxSizeBytes: 10 * 1024 * 1024 * 1024,
            itemCount: 2,
            pinnedItemCount: 1,
            deadzoneActive: false
        )
        XCTAssertEqual(metricsMB.usagePercentage, 0.048828125, accuracy: 0.001)
        XCTAssertTrue(metricsMB.formattedUsage.contains("500.0 MB / 10.0 GB"))

        let metricsGB = CacheStorageMetrics(
            currentSizeBytes: Int64(2.5 * Double(1024 * 1024 * 1024)),
            maxSizeBytes: 50 * 1024 * 1024 * 1024,
            itemCount: 12,
            pinnedItemCount: 3,
            deadzoneActive: true
        )
        XCTAssertEqual(metricsGB.usagePercentage, 0.05, accuracy: 0.001)
        XCTAssertTrue(metricsGB.formattedUsage.contains("2.50 GB / 50.0 GB"))
        XCTAssertTrue(metricsGB.deadzoneActive)
    }

    // MARK: - 2. Storage Engine Operations

    func testStorageEngineDiskOperations() throws {
        let testData = "DashCast Deadzone Test Stream Content".data(using: .utf8)!
        let fileName = "sample_test.mp4"

        try storageEngine.writeData(testData, fileName: fileName)
        XCTAssertTrue(storageEngine.fileExists(for: fileName))
        XCTAssertEqual(storageEngine.fileSize(for: fileName), Int64(testData.count))

        storageEngine.removeFile(for: fileName)
        XCTAssertFalse(storageEngine.fileExists(for: fileName))
    }

    // MARK: - 3. Deterministic LRU Eviction

    func testDeterministicLRUEvictionUnderStoragePressure() throws {
        // Set a tight budget of 3000 bytes
        let budget: Int64 = 3000
        cacheService.maxCacheSizeBytes = budget

        let dummyData = Data(repeating: 0xAA, count: 1000)

        // Item 1: Oldest access date
        let file1 = "item1.mp4"
        try storageEngine.writeData(dummyData, fileName: file1)
        let item1 = cacheService.registerCompletedItem(
            sourceURL: URL(string: "https://stream1.mp4")!,
            localFileName: file1,
            channelName: "Channel 1",
            fileSizeBytes: 1000
        )
        // Set lastAccessedAt to 1 hour ago
        cacheService.touchItem(id: item1.id)
        if let idx = cacheService.cachedItems.firstIndex(where: { $0.id == item1.id }) {
            cacheService.cachedItems[idx].lastAccessedAt = Date().addingTimeInterval(-3600)
            storageEngine.saveManifest(cacheService.cachedItems)
        }

        // Item 2: Medium access date (30 mins ago)
        let file2 = "item2.mp4"
        try storageEngine.writeData(dummyData, fileName: file2)
        let item2 = cacheService.registerCompletedItem(
            sourceURL: URL(string: "https://stream2.mp4")!,
            localFileName: file2,
            channelName: "Channel 2",
            fileSizeBytes: 1000
        )
        if let idx = cacheService.cachedItems.firstIndex(where: { $0.id == item2.id }) {
            cacheService.cachedItems[idx].lastAccessedAt = Date().addingTimeInterval(-1800)
            storageEngine.saveManifest(cacheService.cachedItems)
        }

        // Item 3: Recent access date (5 mins ago)
        let file3 = "item3.mp4"
        try storageEngine.writeData(dummyData, fileName: file3)
        let item3 = cacheService.registerCompletedItem(
            sourceURL: URL(string: "https://stream3.mp4")!,
            localFileName: file3,
            channelName: "Channel 3",
            fileSizeBytes: 1000
        )
        if let idx = cacheService.cachedItems.firstIndex(where: { $0.id == item3.id }) {
            cacheService.cachedItems[idx].lastAccessedAt = Date().addingTimeInterval(-300)
            storageEngine.saveManifest(cacheService.cachedItems)
        }

        XCTAssertEqual(cacheService.currentCacheSizeBytes, 3000)

        // Adding Item 4 (1000 bytes) will push total to 4000, exceeding the 3000 budget!
        let file4 = "item4.mp4"
        try storageEngine.writeData(dummyData, fileName: file4)
        _ = cacheService.registerCompletedItem(
            sourceURL: URL(string: "https://stream4.mp4")!,
            localFileName: file4,
            channelName: "Channel 4",
            fileSizeBytes: 1000
        )

        // Item 1 (oldest: -3600s) should have been evicted deterministically!
        XCTAssertFalse(cacheService.isCached(sourceURL: item1.sourceURL))
        XCTAssertFalse(storageEngine.fileExists(for: file1))

        // Items 2, 3, 4 should remain
        XCTAssertTrue(cacheService.isCached(sourceURL: item2.sourceURL))
        XCTAssertTrue(cacheService.isCached(sourceURL: item3.sourceURL))
        XCTAssertLessThanOrEqual(cacheService.currentCacheSizeBytes, budget)
    }

    func testPinnedItemsImmunityFromEviction() throws {
        let budget: Int64 = 2000
        cacheService.maxCacheSizeBytes = budget

        let dummyData = Data(repeating: 0xBB, count: 1000)

        // Item 1 is PINNED even though it is older
        let file1 = "pinned.mp4"
        try storageEngine.writeData(dummyData, fileName: file1)
        let item1 = cacheService.registerCompletedItem(
            sourceURL: URL(string: "https://pinned.mp4")!,
            localFileName: file1,
            channelName: "Pinned Road Trip Video",
            fileSizeBytes: 1000,
            isPinned: true
        )
        if let idx = cacheService.cachedItems.firstIndex(where: { $0.id == item1.id }) {
            cacheService.cachedItems[idx].lastAccessedAt = Date().addingTimeInterval(-7200)
            storageEngine.saveManifest(cacheService.cachedItems)
        }

        // Item 2 is UNPINNED
        let file2 = "unpinned.mp4"
        try storageEngine.writeData(dummyData, fileName: file2)
        _ = cacheService.registerCompletedItem(
            sourceURL: URL(string: "https://unpinned.mp4")!,
            localFileName: file2,
            channelName: "Unpinned Video",
            fileSizeBytes: 1000,
            isPinned: false
        )

        // Now add Item 3 which forces eviction
        let file3 = "new.mp4"
        try storageEngine.writeData(dummyData, fileName: file3)
        _ = cacheService.registerCompletedItem(
            sourceURL: URL(string: "https://new.mp4")!,
            localFileName: file3,
            channelName: "New Video",
            fileSizeBytes: 1000,
            isPinned: false
        )

        // Pinned item 1 MUST survive!
        XCTAssertTrue(cacheService.isCached(sourceURL: item1.sourceURL))
        XCTAssertTrue(storageEngine.fileExists(for: file1))
        XCTAssertLessThanOrEqual(cacheService.currentCacheSizeBytes, budget)
    }

    // MARK: - 4. 50GB Architecture Bounds & Configuration

    func testDeadzoneCacheServiceLimitClamping() {
        // Test up to 50GB
        let fiftyGB: Int64 = 50 * 1024 * 1024 * 1024
        cacheService.maxCacheSizeBytes = fiftyGB
        XCTAssertEqual(cacheService.maxCacheSizeBytes, fiftyGB)

        // Exceeding 50GB clamps to 50GB
        cacheService.maxCacheSizeBytes = fiftyGB + (10 * 1024 * 1024 * 1024)
        XCTAssertEqual(cacheService.maxCacheSizeBytes, fiftyGB)

        // Less than 500MB clamps to 500MB
        cacheService.maxCacheSizeBytes = 100
        XCTAssertEqual(cacheService.maxCacheSizeBytes, DeadzoneCacheService.minimumCacheBytes)

        // Helper setMaxStorageGigabytes
        cacheService.setMaxStorageGigabytes(25)
        XCTAssertEqual(cacheService.maxCacheSizeBytes, 25 * 1024 * 1024 * 1024)
    }

    // MARK: - 5. Item Lifecycle & Pinning

    func testRegisterTouchAndTogglePin() throws {
        let dummy = "Sample".data(using: .utf8)!
        try storageEngine.writeData(dummy, fileName: "test.mp4")

        let item = cacheService.registerCompletedItem(
            sourceURL: URL(string: "https://dashcast.com/test.mp4")!,
            localFileName: "test.mp4",
            channelName: "Test Channel",
            fileSizeBytes: Int64(dummy.count),
            isPinned: false
        )

        XCTAssertFalse(item.isPinned)
        cacheService.togglePin(id: item.id)
        XCTAssertTrue(cacheService.cachedItems.first(where: { $0.id == item.id })?.isPinned == true)

        let initialDate = cacheService.cachedItems.first(where: { $0.id == item.id })!.lastAccessedAt
        cacheService.touchItem(id: item.id)
        let touchedDate = cacheService.cachedItems.first(where: { $0.id == item.id })!.lastAccessedAt
        XCTAssertGreaterThanOrEqual(touchedDate, initialDate)
    }

    func testEvictSingleItemAndClearAll() throws {
        let dummy = "Sample".data(using: .utf8)!
        try storageEngine.writeData(dummy, fileName: "test.mp4")

        let item = cacheService.registerCompletedItem(
            sourceURL: URL(string: "https://dashcast.com/test.mp4")!,
            localFileName: "test.mp4",
            channelName: "Test Channel",
            fileSizeBytes: Int64(dummy.count)
        )

        XCTAssertTrue(cacheService.isCached(sourceURL: item.sourceURL))

        cacheService.evictItem(id: item.id)
        XCTAssertFalse(cacheService.isCached(sourceURL: item.sourceURL))
        XCTAssertEqual(cacheService.currentCacheSizeBytes, 0)

        // Add 2 items and clear all
        try storageEngine.writeData(dummy, fileName: "a.mp4")
        try storageEngine.writeData(dummy, fileName: "b.mp4")
        _ = cacheService.registerCompletedItem(sourceURL: URL(string: "https://a.mp4")!, localFileName: "a.mp4", channelName: "A")
        _ = cacheService.registerCompletedItem(sourceURL: URL(string: "https://b.mp4")!, localFileName: "b.mp4", channelName: "B")
        XCTAssertEqual(cacheService.cachedItems.count, 2)

        cacheService.clearAllCache()
        XCTAssertEqual(cacheService.cachedItems.count, 0)
        XCTAssertEqual(cacheService.currentCacheSizeBytes, 0)
    }

    // MARK: - 6. Media Preloader Tests

    func testPreloadBundled1080pClips() {
        let preloaded = preloader.preloadBundledClips()
        XCTAssertGreaterThanOrEqual(preloaded.count, 2)

        for item in preloaded {
            XCTAssertTrue(item.isPinned)
            XCTAssertTrue(cacheService.isCached(sourceURL: item.sourceURL))
            XCTAssertNotNil(cacheService.localURL(for: item.sourceURL))
        }

        let offlineChannels = cacheService.allOfflineChannels()
        XCTAssertGreaterThanOrEqual(offlineChannels.count, 2)
    }

    func testPreloadChannelLocalFile() async throws {
        let localFile = tempDirectory.appendingPathComponent("incoming.mp4")
        let dummyData = "Incoming Video File Content".data(using: .utf8)!
        try dummyData.write(to: localFile)

        let channel = ChannelModel(
            name: "Local DashCam Clip",
            streamURL: localFile,
            groupTitle: "Local"
        )

        preloader.preloadChannel(channel)

        // Wait brief task duration
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(cacheService.isCached(sourceURL: localFile))
        XCTAssertNotNil(cacheService.localURL(for: localFile))
    }

    // MARK: - 7. VideoPlayerService Integration & Deadzone Fallback

    @MainActor
    func testVideoPlayerServiceUsesCachedPlayback() throws {
        let dummyData = "H.264 Test Container".data(using: .utf8)!
        let fileName = "cached_playback.mp4"
        try storageEngine.writeData(dummyData, fileName: fileName)

        let streamURL = URL(string: "https://stream.dashcast.com/hls/race.m3u8")!
        let item = cacheService.registerCompletedItem(
            sourceURL: streamURL,
            localFileName: fileName,
            channelName: "Formula 1 Stream",
            fileSizeBytes: Int64(dummyData.count)
        )

        let channel = ChannelModel(
            name: "Formula 1 Stream",
            streamURL: streamURL,
            groupTitle: "Sports"
        )

        // Inject active cache service
        DeadzoneCacheService.shared.registerCompletedItem(
            sourceURL: streamURL,
            localFileName: fileName,
            channelName: "Formula 1 Stream",
            fileSizeBytes: Int64(dummyData.count)
        )

        VideoPlayerService.shared.load(channel: channel)

        XCTAssertTrue(VideoPlayerService.shared.isOfflinePlayback)
        XCTAssertEqual(VideoPlayerService.shared.activeCacheItem?.sourceURL, streamURL)
    }

    @MainActor
    func testDeadzoneFallbackTrigger() {
        // Preload bundled clips so there is at least one fallback
        preloader.preloadBundledClips()

        XCTAssertFalse(cacheService.allOfflineChannels().isEmpty)

        VideoPlayerService.shared.triggerDeadzoneFallback()

        XCTAssertTrue(VideoPlayerService.shared.isDeadzoneFallbackActive)
        XCTAssertTrue(VideoPlayerService.shared.isOfflinePlayback)
    }

    // MARK: - 8. User Preferences Persistence

    func testUserPreferencesWithOfflineCacheSettings() throws {
        var prefs = UserPreferences()
        prefs.offlineCacheMaxGigabytes = 30
        prefs.autoPreloadFavoritesOnWiFi = false
        prefs.allowCellularPreloading = true
        prefs.evictOldestWhenFull = false

        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: encoded)

        XCTAssertEqual(decoded.offlineCacheMaxGigabytes, 30)
        XCTAssertFalse(decoded.autoPreloadFavoritesOnWiFi)
        XCTAssertTrue(decoded.allowCellularPreloading)
        XCTAssertFalse(decoded.evictOldestWhenFull)
    }
}
