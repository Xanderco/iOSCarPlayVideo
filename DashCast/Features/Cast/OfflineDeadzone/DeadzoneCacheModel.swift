import Foundation

public enum CacheItemStatus: String, Codable {
    case idle
    case downloading
    case ready
    case failed
}

public struct DeadzoneCacheItem: Codable, Identifiable, Hashable {
    public let id: String
    public let sourceURL: URL
    public var localFileName: String
    public var channelName: String
    public var groupTitle: String
    public var fileSizeBytes: Int64
    public var cachedAt: Date
    public var lastAccessedAt: Date
    public var isPinned: Bool
    public var isComplete: Bool
    public var downloadProgress: Double
    public var status: CacheItemStatus
    public var failureReason: String?

    public init(
        id: String = UUID().uuidString,
        sourceURL: URL,
        localFileName: String,
        channelName: String,
        groupTitle: String = "Offline Cache",
        fileSizeBytes: Int64 = 0,
        cachedAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        isPinned: Bool = false,
        isComplete: Bool = false,
        downloadProgress: Double = 0.0,
        status: CacheItemStatus = .idle,
        failureReason: String? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.localFileName = localFileName
        self.channelName = channelName
        self.groupTitle = groupTitle
        self.fileSizeBytes = fileSizeBytes
        self.cachedAt = cachedAt
        self.lastAccessedAt = lastAccessedAt
        self.isPinned = isPinned
        self.isComplete = isComplete
        self.downloadProgress = downloadProgress
        self.status = status
        self.failureReason = failureReason
    }

    public func toChannelModel(cacheDirectory: URL) -> ChannelModel {
        let localURL = cacheDirectory.appendingPathComponent(localFileName)
        return ChannelModel(
            id: id,
            name: channelName + " [Offline Cached]",
            streamURL: localURL,
            groupTitle: "Offline Deadzone Cache",
            logoURL: nil,
            isFavorite: true,
            lastWatched: lastAccessedAt
        )
    }
}

public struct CacheStorageMetrics: Equatable {
    public let currentSizeBytes: Int64
    public let maxSizeBytes: Int64
    public let itemCount: Int
    public let pinnedItemCount: Int
    public let deadzoneActive: Bool

    public init(
        currentSizeBytes: Int64 = 0,
        maxSizeBytes: Int64 = 10 * 1024 * 1024 * 1024,
        itemCount: Int = 0,
        pinnedItemCount: Int = 0,
        deadzoneActive: Bool = false
    ) {
        self.currentSizeBytes = currentSizeBytes
        self.maxSizeBytes = maxSizeBytes
        self.itemCount = itemCount
        self.pinnedItemCount = pinnedItemCount
        self.deadzoneActive = deadzoneActive
    }

    public var usagePercentage: Double {
        guard maxSizeBytes > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(currentSizeBytes) / Double(maxSizeBytes)))
    }

    public var formattedUsage: String {
        let currentMB = Double(currentSizeBytes) / (1024 * 1024)
        let maxGB = Double(maxSizeBytes) / (1024 * 1024 * 1024)
        if currentMB >= 1024 {
            let currentGB = currentMB / 1024
            return String(format: "%.2f GB / %.1f GB", currentGB, maxGB)
        } else {
            return String(format: "%.1f MB / %.1f GB", currentMB, maxGB)
        }
    }
}
