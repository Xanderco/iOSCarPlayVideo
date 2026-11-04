import Foundation
import Combine

@MainActor
public final class DeadzoneCacheService: ObservableObject {
    public static let shared = DeadzoneCacheService()

    /// Absolute maximum cache allowed by architecture: 50GB
    public static let absoluteMaxCacheBytes: Int64 = 50 * 1024 * 1024 * 1024
    /// Minimum cache allowed: 500MB
    public static let minimumCacheBytes: Int64 = 500 * 1024 * 1024

    @Published public private(set) var cachedItems: [DeadzoneCacheItem] = []
    @Published public private(set) var currentCacheSizeBytes: Int64 = 0
    @Published public var maxCacheSizeBytes: Int64 {
        didSet {
            let clamped = min(Self.absoluteMaxCacheBytes, max(Self.minimumCacheBytes, maxCacheSizeBytes))
            if clamped != maxCacheSizeBytes {
                maxCacheSizeBytes = clamped
            }
            enforceEviction()
            updateMetrics()
        }
    }
    @Published public var isDeadzoneActive: Bool = false {
        didSet {
            updateMetrics()
        }
    }
    @Published public private(set) var metrics: CacheStorageMetrics

    public let storageEngine: DeadzoneCacheStorageEngine

    public init(
        storageEngine: DeadzoneCacheStorageEngine = .default,
        initialMaxSizeBytes: Int64 = 10 * 1024 * 1024 * 1024
    ) {
        self.storageEngine = storageEngine
        self.maxCacheSizeBytes = min(Self.absoluteMaxCacheBytes, max(Self.minimumCacheBytes, initialMaxSizeBytes))
        self.metrics = CacheStorageMetrics(maxSizeBytes: initialMaxSizeBytes)

        loadInitialCache()
    }

    public func setMaxStorageGigabytes(_ gigabytes: Int) {
        let bytes = Int64(gigabytes) * 1024 * 1024 * 1024
        self.maxCacheSizeBytes = bytes
    }

    private func loadInitialCache() {
        var items = storageEngine.loadManifest()
        // Validate disk integrity: recalculate actual byte sizes
        for index in items.indices {
            if items[index].isComplete {
                let actualSize = storageEngine.fileSize(for: items[index].localFileName)
                if actualSize > 0 {
                    items[index].fileSizeBytes = actualSize
                }
            }
        }
        self.cachedItems = items
        self.currentCacheSizeBytes = items.filter { $0.isComplete }.reduce(0) { $0 + $1.fileSizeBytes }
        enforceEviction()
        updateMetrics()
    }

    private func updateMetrics() {
        self.currentCacheSizeBytes = cachedItems.filter { $0.isComplete }.reduce(0) { $0 + $1.fileSizeBytes }
        let pinnedCount = cachedItems.filter { $0.isPinned }.count
        self.metrics = CacheStorageMetrics(
            currentSizeBytes: currentCacheSizeBytes,
            maxSizeBytes: maxCacheSizeBytes,
            itemCount: cachedItems.filter { $0.isComplete }.count,
            pinnedItemCount: pinnedCount,
            deadzoneActive: isDeadzoneActive
        )
    }

    @discardableResult
    public func registerCompletedItem(
        sourceURL: URL,
        localFileName: String,
        channelName: String,
        groupTitle: String = "Offline Cache",
        fileSizeBytes: Int64? = nil,
        isPinned: Bool = false
    ) -> DeadzoneCacheItem {
        let size = fileSizeBytes ?? storageEngine.fileSize(for: localFileName)

        // Remove existing item with same sourceURL if present
        if let existingIndex = cachedItems.firstIndex(where: { $0.sourceURL == sourceURL }) {
            storageEngine.removeFile(for: cachedItems[existingIndex].localFileName)
            cachedItems.remove(at: existingIndex)
        }

        var newItem = DeadzoneCacheItem(
            sourceURL: sourceURL,
            localFileName: localFileName,
            channelName: channelName,
            groupTitle: groupTitle,
            fileSizeBytes: size,
            cachedAt: Date(),
            lastAccessedAt: Date(),
            isPinned: isPinned,
            isComplete: true,
            downloadProgress: 1.0,
            status: .ready
        )

        cachedItems.append(newItem)
        enforceEviction()
        storageEngine.saveManifest(cachedItems)
        updateMetrics()
        return newItem
    }

    public func touchItem(id: String) {
        if let index = cachedItems.firstIndex(where: { $0.id == id }) {
            cachedItems[index].lastAccessedAt = Date()
            storageEngine.saveManifest(cachedItems)
        }
    }

    public func togglePin(id: String) {
        if let index = cachedItems.firstIndex(where: { $0.id == id }) {
            cachedItems[index].isPinned.toggle()
            storageEngine.saveManifest(cachedItems)
            updateMetrics()
        }
    }

    public func evictItem(id: String) {
        if let index = cachedItems.firstIndex(where: { $0.id == id }) {
            let item = cachedItems.remove(at: index)
            storageEngine.removeFile(for: item.localFileName)
            storageEngine.saveManifest(cachedItems)
            updateMetrics()
        }
    }

    public func clearAllCache() {
        storageEngine.clearAllFiles()
        cachedItems.removeAll()
        updateMetrics()
    }

    public func evictUnpinned() {
        let unpinned = cachedItems.filter { !$0.isPinned }
        for item in unpinned {
            storageEngine.removeFile(for: item.localFileName)
        }
        cachedItems.removeAll { !$0.isPinned }
        storageEngine.saveManifest(cachedItems)
        updateMetrics()
    }

    @discardableResult
    public func enforceEviction() -> [DeadzoneCacheItem] {
        let evicted = storageEngine.enforceStorageLimit(
            maxSizeBytes: maxCacheSizeBytes,
            currentItems: &cachedItems
        )
        if !evicted.isEmpty {
            updateMetrics()
        }
        return evicted
    }

    // MARK: - Query & Playback Resolution

    public func isCached(sourceURL: URL) -> Bool {
        guard let item = cachedItems.first(where: { $0.sourceURL == sourceURL && $0.isComplete }) else {
            return false
        }
        return storageEngine.fileExists(for: item.localFileName)
    }

    public func localURL(for sourceURL: URL) -> URL? {
        guard let item = cachedItems.first(where: { $0.sourceURL == sourceURL && $0.isComplete }) else {
            return nil
        }
        guard storageEngine.fileExists(for: item.localFileName) else {
            return nil
        }
        return storageEngine.localFileURL(for: item.localFileName)
    }

    public func item(for sourceURL: URL) -> DeadzoneCacheItem? {
        cachedItems.first(where: { $0.sourceURL == sourceURL && $0.isComplete })
    }

    public func allOfflineChannels() -> [ChannelModel] {
        cachedItems
            .filter { $0.isComplete && storageEngine.fileExists(for: $0.localFileName) }
            .map { $0.toChannelModel(cacheDirectory: storageEngine.cacheDirectory) }
    }

    public func firstAvailableOfflineChannel() -> ChannelModel? {
        allOfflineChannels().first
    }
}
