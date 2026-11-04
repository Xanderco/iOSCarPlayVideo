import XCTest
import SwiftUI
@testable import DashCast

@MainActor
final class OfflineMediaLibraryTests: XCTestCase {

    var tempStorageDir: URL!
    var engine: DeadzoneCacheStorageEngine!
    var cacheService: DeadzoneCacheService!

    override func setUp() {
        super.setUp()
        let uniqueID = UUID().uuidString
        tempStorageDir = FileManager.default.temporaryDirectory.appendingPathComponent("TestCache_\(uniqueID)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempStorageDir, withIntermediateDirectories: true)
        engine = DeadzoneCacheStorageEngine(customDirectory: tempStorageDir)
        cacheService = DeadzoneCacheService(storageEngine: engine, initialMaxSizeBytes: 2 * 1024 * 1024 * 1024)
    }

    override func tearDown() {
        if let dir = tempStorageDir {
            try? FileManager.default.removeItem(at: dir)
        }
        super.tearDown()
    }

    // MARK: - Model & Metrics Tests

    func testDeadzoneCacheModelDefaultsAndConversion() {
        let sourceURL = URL(string: "https://example.com/test_stream.m3u8")!
        let item = DeadzoneCacheItem(
            sourceURL: sourceURL,
            localFileName: "cached_test.mp4",
            channelName: "Track Lap 4K",
            groupTitle: "Racing",
            fileSizeBytes: 524288000, // 500 MB
            isPinned: true,
            isComplete: true,
            downloadProgress: 1.0,
            status: .ready
        )

        XCTAssertEqual(item.channelName, "Track Lap 4K")
        XCTAssertEqual(item.groupTitle, "Racing")
        XCTAssertTrue(item.isPinned)
        XCTAssertTrue(item.isComplete)
        XCTAssertEqual(item.formattedSize, "500.0 MB")

        let channel = item.toChannelModel(cacheDirectory: tempStorageDir)
        XCTAssertTrue(channel.name.contains("Track Lap 4K"))
        XCTAssertTrue(channel.name.contains("[Offline Cached]"))
        XCTAssertEqual(channel.groupTitle, "Offline Deadzone Cache")
        XCTAssertEqual(channel.streamURL, tempStorageDir.appendingPathComponent("cached_test.mp4"))
    }

    func testCacheStorageMetricsCalculations() {
        let metrics = CacheStorageMetrics(
            currentSizeBytes: 2 * 1024 * 1024 * 1024, // 2 GB
            maxSizeBytes: 10 * 1024 * 1024 * 1024,    // 10 GB
            itemCount: 4,
            pinnedItemCount: 2,
            deadzoneActive: true
        )

        XCTAssertEqual(metrics.usagePercentage, 0.20, accuracy: 0.001)
        XCTAssertEqual(metrics.itemCount, 4)
        XCTAssertEqual(metrics.pinnedItemCount, 2)
        XCTAssertTrue(metrics.deadzoneActive)
        XCTAssertTrue(metrics.formattedUsage.contains("2.00 GB of 10.00 GB used (20%)"))
    }

    func testZeroMaxStorageMetricsSafety() {
        let metrics = CacheStorageMetrics(currentSizeBytes: 0, maxSizeBytes: 0)
        XCTAssertEqual(metrics.usagePercentage, 0.0)
    }

    // MARK: - Service Lifecycle & Cache Management Tests

    func testRegisterCompletedItemAndMetricsUpdate() {
        // Create dummy local file in temp storage
        let dummyFileName = "video_clip_1.mp4"
        let fileURL = tempStorageDir.appendingPathComponent(dummyFileName)
        let sampleData = Data(repeating: 0xAA, count: 1024 * 1024 * 10) // 10 MB
        try? sampleData.write(to: fileURL)

        let sourceURL = URL(string: "https://example.com/video1.m3u8")!
        let registered = cacheService.registerCompletedItem(
            sourceURL: sourceURL,
            localFileName: dummyFileName,
            channelName: "Night Drive Clip",
            groupTitle: "Automotive",
            fileSizeBytes: 10 * 1024 * 1024,
            isPinned: false
        )

        XCTAssertEqual(registered.localFileName, dummyFileName)
        XCTAssertTrue(cacheService.isCached(sourceURL: sourceURL))
        XCTAssertNotNil(cacheService.localURL(for: sourceURL))
        XCTAssertEqual(cacheService.cachedItems.count, 1)
        XCTAssertEqual(cacheService.metrics.itemCount, 1)
        XCTAssertEqual(cacheService.metrics.pinnedItemCount, 0)
    }

    func testPinToggleAndPreservation() {
        let dummyFileName = "pinned_video.mp4"
        let fileURL = tempStorageDir.appendingPathComponent(dummyFileName)
        try? Data(repeating: 0xBB, count: 1024).write(to: fileURL)

        let item = cacheService.registerCompletedItem(
            sourceURL: URL(string: "https://example.com/pinned.m3u8")!,
            localFileName: dummyFileName,
            channelName: "Essential Track Video",
            fileSizeBytes: 1024,
            isPinned: false
        )

        XCTAssertFalse(item.isPinned)
        cacheService.togglePin(id: item.id)

        let updated = cacheService.cachedItems.first { $0.id == item.id }
        XCTAssertEqual(updated?.isPinned, true)
        XCTAssertEqual(cacheService.metrics.pinnedItemCount, 1)

        // Toggle back
        cacheService.togglePin(id: item.id)
        let unpinned = cacheService.cachedItems.first { $0.id == item.id }
        XCTAssertEqual(unpinned?.isPinned, false)
        XCTAssertEqual(cacheService.metrics.pinnedItemCount, 0)
    }

    func testClearAllUnpinnedLeavesPinnedIntact() {
        // File 1: Pinned
        let f1 = "pinned.mp4"
        try? Data(repeating: 0x11, count: 1000).write(to: tempStorageDir.appendingPathComponent(f1))
        let item1 = cacheService.registerCompletedItem(
            sourceURL: URL(string: "https://example.com/1.m3u8")!,
            localFileName: f1,
            channelName: "Pinned Item",
            fileSizeBytes: 1000,
            isPinned: true
        )

        // File 2: Unpinned
        let f2 = "unpinned.mp4"
        try? Data(repeating: 0x22, count: 2000).write(to: tempStorageDir.appendingPathComponent(f2))
        _ = cacheService.registerCompletedItem(
            sourceURL: URL(string: "https://example.com/2.m3u8")!,
            localFileName: f2,
            channelName: "Unpinned Item",
            fileSizeBytes: 2000,
            isPinned: false
        )

        XCTAssertEqual(cacheService.cachedItems.count, 2)

        cacheService.clearAllUnpinned()

        XCTAssertEqual(cacheService.cachedItems.count, 1)
        XCTAssertEqual(cacheService.cachedItems.first?.id, item1.id)
        XCTAssertTrue(engine.fileExists(for: f1))
        XCTAssertFalse(engine.fileExists(for: f2))
    }

    func testLRUEvictionUnderQuota() {
        // Set small quota: 500 MB
        cacheService.maxCacheSizeBytes = 500 * 1024 * 1024

        // Add 3 files of 200 MB each (Total 600 MB > 500 MB)
        for i in 1...3 {
            let fn = "clip_\(i).mp4"
            let path = tempStorageDir.appendingPathComponent(fn)
            try? Data(repeating: 0x33, count: 100).write(to: path)
            cacheService.registerCompletedItem(
                sourceURL: URL(string: "https://example.com/clip_\(i).m3u8")!,
                localFileName: fn,
                channelName: "Clip \(i)",
                fileSizeBytes: 200 * 1024 * 1024,
                isPinned: false
            )
        }

        // Cache service should enforce eviction to fit under 500 MB
        let totalSize = cacheService.currentCacheSizeBytes
        XCTAssertLessThanOrEqual(totalSize, 500 * 1024 * 1024)
        XCTAssertEqual(cacheService.cachedItems.count, 2)
    }

    func testDeadzoneActiveModeSwitch() {
        XCTAssertFalse(cacheService.isDeadzoneActive)
        cacheService.isDeadzoneActive = true
        XCTAssertTrue(cacheService.isDeadzoneActive)
        XCTAssertTrue(cacheService.metrics.deadzoneActive)
    }

    // MARK: - User Preferences Storage Quota Tests

    func testUserPreferencesOfflineCacheSettings() {
        var prefs = UserPreferences()
        XCTAssertEqual(prefs.offlineCacheMaxGigabytes, 10)
        XCTAssertTrue(prefs.autoPreloadFavoritesOnWiFi)
        XCTAssertFalse(prefs.allowCellularPreloading)
        XCTAssertTrue(prefs.evictOldestWhenFull)

        prefs.offlineCacheMaxGigabytes = 20
        prefs.allowCellularPreloading = true

        let data = try? JSONEncoder().encode(prefs)
        XCTAssertNotNil(data)

        let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data!)
        XCTAssertEqual(decoded?.offlineCacheMaxGigabytes, 20)
        XCTAssertEqual(decoded?.allowCellularPreloading, true)
    }

    // MARK: - UI Views Initialization & Ergonomic Standards

    func testOfflineMediaLibraryViewInitialization() {
        let view = OfflineMediaLibraryView()
        XCTAssertNotNil(view.body)
    }

    func testOfflineCacheSettingsViewInitialization() {
        let settingsView = OfflineCacheSettingsView()
        XCTAssertNotNil(settingsView.body)
    }
}
