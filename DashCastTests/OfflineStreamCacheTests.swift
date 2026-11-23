import XCTest
import CoreMedia
@testable import DashCast

final class OfflineStreamCacheTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        let uniqueName = "TestCache_\(UUID().uuidString)"
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueName, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let temp = tempDirectory {
            try? FileManager.default.removeItem(at: temp)
        }
        super.tearDown()
    }

    // MARK: - Model & Conversion Tests

    func testCachedStreamItemCreationAndModelConversion() {
        let sourceURL = URL(string: "https://example.com/live/stream.m3u8")!
        let item = CachedStreamItem(
            sourceURL: sourceURL,
            localRelativePath: "stream_123/playlist.m3u8",
            title: "CarPlay Racing Stream",
            groupTitle: "Motorsport",
            fileSizeBytes: 1024 * 1024 * 15, // 15 MB
            durationSeconds: 120.0,
            isPinned: true,
            isComplete: true,
            downloadProgress: 1.0,
            status: .ready,
            contentType: .hls,
            segmentCount: 12
        )

        XCTAssertEqual(item.title, "CarPlay Racing Stream")
        XCTAssertEqual(item.contentType, .hls)
        XCTAssertEqual(item.segmentCount, 12)
        XCTAssertTrue(item.isPinned)
        XCTAssertTrue(item.isComplete)
        XCTAssertEqual(item.fileSizeBytes, 15 * 1024 * 1024)

        let channel = item.toChannelModel(cacheDirectory: tempDirectory)
        XCTAssertEqual(channel.id, item.id)
        XCTAssertEqual(channel.name, "CarPlay Racing Stream [Offline Cached]")
        XCTAssertEqual(channel.groupTitle, "Offline Stream Cache")
        XCTAssertTrue(channel.isFavorite)
        XCTAssertTrue(channel.streamURL.isFileURL)
        XCTAssertEqual(channel.streamURL.lastPathComponent, "playlist.m3u8")
    }

    func testQuotaStorageMetricsCalculationAndFormatting() {
        // 500 MB used of 5 GB quota
        let metrics1 = StreamCacheStorageMetrics(
            currentSizeBytes: 500 * 1024 * 1024,
            maxQuotaBytes: 5 * 1024 * 1024 * 1024,
            itemCount: 4,
            pinnedItemCount: 1,
            highwayBufferActive: true,
            forwardBufferSeconds: 60.0
        )

        XCTAssertEqual(metrics1.usagePercentage, 0.09765625, accuracy: 0.01)
        XCTAssertEqual(metrics1.formattedQuota, "5 GB")
        XCTAssertTrue(metrics1.formattedUsage.contains("500.0 MB / 5.0 GB"))
        XCTAssertTrue(metrics1.highwayBufferActive)
        XCTAssertEqual(metrics1.forwardBufferSeconds, 60.0)

        // 2.5 GB used of 10 GB quota
        let metrics2 = StreamCacheStorageMetrics(
            currentSizeBytes: Int64(2.5 * 1024 * 1024 * 1024),
            maxQuotaBytes: 10 * 1024 * 1024 * 1024,
            itemCount: 10,
            pinnedItemCount: 3,
            highwayBufferActive: true,
            forwardBufferSeconds: 60.0
        )

        XCTAssertEqual(metrics2.usagePercentage, 0.25, accuracy: 0.01)
        XCTAssertEqual(metrics2.formattedQuota, "10 GB")
        XCTAssertTrue(metrics2.formattedUsage.contains("2.50 GB / 10.0 GB"))
    }

    // MARK: - Cache Eviction & 1-Tap Clear Tests

    @MainActor
    func testLRUEvictionUnderStorageQuota() {
        // Quota set to 2.5 MB
        let service = OfflineStreamCacheService(
            customCacheDirectory: tempDirectory,
            initialQuotaBytes: Int64(2.5 * 1024 * 1024)
        )

        let url1 = URL(string: "https://example.com/stream1.m3u8")!
        let url2 = URL(string: "https://example.com/stream2.m3u8")!
        let url3 = URL(string: "https://example.com/stream3.m3u8")!

        // Create 3 dummy files (1 MB each = 3 MB total, exceeding 2.5 MB quota)
        let file1 = tempDirectory.appendingPathComponent("file1.ts")
        let file2 = tempDirectory.appendingPathComponent("file2.ts")
        let file3 = tempDirectory.appendingPathComponent("file3.ts")

        let dummyData = Data(repeating: 0xAA, count: 1024 * 1024)
        try? dummyData.write(to: file1)
        try? dummyData.write(to: file2)
        try? dummyData.write(to: file3)

        // Register item 1 (oldest accessed date)
        let item1 = service.registerCompletedItem(
            sourceURL: url1,
            localRelativePath: "file1.ts",
            title: "Stream 1",
            fileSizeBytes: 1024 * 1024,
            isPinned: false
        )

        // Register item 2
        _ = service.registerCompletedItem(
            sourceURL: url2,
            localRelativePath: "file2.ts",
            title: "Stream 2",
            fileSizeBytes: 1024 * 1024,
            isPinned: false
        )

        // Register item 3 (triggers eviction of oldest: item1)
        _ = service.registerCompletedItem(
            sourceURL: url3,
            localRelativePath: "file3.ts",
            title: "Stream 3",
            fileSizeBytes: 1024 * 1024,
            isPinned: false
        )

        // Item 1 must have been evicted to keep total under 2.5 MB
        XCTAssertFalse(service.isCached(sourceURL: url1))
        XCTAssertTrue(service.isCached(sourceURL: url2))
        XCTAssertTrue(service.isCached(sourceURL: url3))
        XCTAssertLessThanOrEqual(service.currentCacheSizeBytes, service.quotaSizeBytes)
        XCTAssertEqual(service.items.count, 2)
    }

    @MainActor
    func testPinnedItemsSurviveQuotaEviction() {
        let service = OfflineStreamCacheService(
            customCacheDirectory: tempDirectory,
            initialQuotaBytes: Int64(1.5 * 1024 * 1024)
        )

        let urlPinned = URL(string: "https://example.com/pinned.m3u8")!
        let urlUnpinned = URL(string: "https://example.com/unpinned.m3u8")!

        let file1 = tempDirectory.appendingPathComponent("pinned.ts")
        let file2 = tempDirectory.appendingPathComponent("unpinned.ts")

        let dummyData = Data(repeating: 0xBB, count: 1024 * 1024)
        try? dummyData.write(to: file1)
        try? dummyData.write(to: file2)

        // Register pinned item (1 MB)
        _ = service.registerCompletedItem(
            sourceURL: urlPinned,
            localRelativePath: "pinned.ts",
            title: "Pinned Stream",
            fileSizeBytes: 1024 * 1024,
            isPinned: true
        )

        // Register unpinned item (1 MB) -> total 2 MB, exceeding 1.5 MB quota
        _ = service.registerCompletedItem(
            sourceURL: urlUnpinned,
            localRelativePath: "unpinned.ts",
            title: "Unpinned Stream",
            fileSizeBytes: 1024 * 1024,
            isPinned: false
        )

        // Pinned item MUST survive eviction
        XCTAssertTrue(service.isCached(sourceURL: urlPinned))
        // The unpinned item is evicted
        XCTAssertFalse(service.isCached(sourceURL: urlUnpinned))
    }

    @MainActor
    func testOneTapClearCacheRemovesOnlyUnpinnedItems() {
        let service = OfflineStreamCacheService(
            customCacheDirectory: tempDirectory,
            initialQuotaBytes: 10 * 1024 * 1024
        )

        let url1 = URL(string: "https://example.com/unpinned1.m3u8")!
        let url2 = URL(string: "https://example.com/pinned1.m3u8")!

        let file1 = tempDirectory.appendingPathComponent("unpinned1.ts")
        let file2 = tempDirectory.appendingPathComponent("pinned1.ts")

        let dummyData = Data(repeating: 0xCC, count: 512 * 1024)
        try? dummyData.write(to: file1)
        try? dummyData.write(to: file2)

        _ = service.registerCompletedItem(
            sourceURL: url1,
            localRelativePath: "unpinned1.ts",
            title: "Unpinned 1",
            fileSizeBytes: 512 * 1024,
            isPinned: false
        )

        _ = service.registerCompletedItem(
            sourceURL: url2,
            localRelativePath: "pinned1.ts",
            title: "Pinned 1",
            fileSizeBytes: 512 * 1024,
            isPinned: true
        )

        XCTAssertEqual(service.items.count, 2)

        // 1-Tap Clear Unpinned Cache
        service.clearUnpinnedCache()

        XCTAssertEqual(service.items.count, 1)
        XCTAssertFalse(service.isCached(sourceURL: url1))
        XCTAssertTrue(service.isCached(sourceURL: url2))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file2.path))
    }

    // MARK: - Rolling Highway Buffer Controller Tests

    func testRollingHighwayBufferPreferredDurations() {
        XCTAssertEqual(RollingHighwayBufferController.preferredBufferDuration(for: .liveMirror), 1.0)
        XCTAssertEqual(RollingHighwayBufferController.preferredBufferDuration(for: .standard), 15.0)
        XCTAssertEqual(RollingHighwayBufferController.preferredBufferDuration(for: .highwayDeadzone), 60.0)
        XCTAssertEqual(RollingHighwayBufferController.highwayTargetDuration, 60.0)
    }

    func testForwardBufferCalculationFromLoadedTimeRanges() {
        // Simulate a loaded time range starting at 10.0s with duration 45.0s (ends at 55.0s)
        let range = CMTimeRange(start: CMTime(seconds: 10.0, preferredTimescale: 600),
                                duration: CMTime(seconds: 45.0, preferredTimescale: 600))
        let ranges = [NSValue(timeRange: range)]

        // At current time 15.0s, forward buffer is 55.0 - 15.0 = 40.0s
        let forward1 = RollingHighwayBufferController.calculateForwardBufferSeconds(
            loadedTimeRanges: ranges,
            currentTimeSeconds: 15.0
        )
        XCTAssertEqual(forward1, 40.0, accuracy: 0.1)

        // At current time 50.0s, forward buffer is 55.0 - 50.0 = 5.0s
        let forward2 = RollingHighwayBufferController.calculateForwardBufferSeconds(
            loadedTimeRanges: ranges,
            currentTimeSeconds: 50.0
        )
        XCTAssertEqual(forward2, 5.0, accuracy: 0.1)

        // Outside loaded range (e.g. currentTime 60.0s)
        let forward3 = RollingHighwayBufferController.calculateForwardBufferSeconds(
            loadedTimeRanges: ranges,
            currentTimeSeconds: 60.0
        )
        XCTAssertEqual(forward3, 0.0)
    }

    func testBufferHealthClassification() {
        XCTAssertEqual(RollingHighwayBufferController.evaluateBufferHealth(forwardSeconds: 0.0), .empty)
        XCTAssertEqual(RollingHighwayBufferController.evaluateBufferHealth(forwardSeconds: 5.5), .critical)
        XCTAssertEqual(RollingHighwayBufferController.evaluateBufferHealth(forwardSeconds: 18.0), .adequate)
        XCTAssertEqual(RollingHighwayBufferController.evaluateBufferHealth(forwardSeconds: 45.0), .highwayProtected)
        XCTAssertEqual(RollingHighwayBufferController.evaluateBufferHealth(forwardSeconds: 65.0), .highwayProtected)
    }

    func testFallbackTriggerWhenBufferStalled() {
        // Stall of 3.5s triggers fallback
        XCTAssertTrue(RollingHighwayBufferController.shouldFallbackToOfflineCache(
            bufferHealth: .critical,
            stallDurationSeconds: 3.5
        ))

        // Minor buffer jitter (< 3.0s) with adequate buffer does not trigger fallback
        XCTAssertFalse(RollingHighwayBufferController.shouldFallbackToOfflineCache(
            bufferHealth: .adequate,
            stallDurationSeconds: 1.0
        ))

        // Empty buffer stalled for 1.8s triggers urgent deadzone fallback
        XCTAssertTrue(RollingHighwayBufferController.shouldFallbackToOfflineCache(
            bufferHealth: .empty,
            stallDurationSeconds: 1.8
        ))
    }

    // MARK: - User Preferences & Persistence Tests

    func testUserPreferencesHighwayBufferSettings() throws {
        let prefs = UserPreferences(
            useMilesPerHour: true,
            isProLifetimeUnlocked: true,
            highwayBufferEnabled: true,
            streamCacheQuotaGigabytes: 10
        )

        XCTAssertTrue(prefs.highwayBufferEnabled)
        XCTAssertEqual(prefs.streamCacheQuotaGigabytes, 10)

        let encoder = JSONEncoder()
        let data = try encoder.encode(prefs)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserPreferences.self, from: data)

        XCTAssertEqual(decoded.highwayBufferEnabled, true)
        XCTAssertEqual(decoded.streamCacheQuotaGigabytes, 10)
    }
}
