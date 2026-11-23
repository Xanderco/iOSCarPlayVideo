import Foundation

public enum CachedStreamStatus: String, Codable {
    case idle
    case downloading
    case ready
    case failed
}

public enum StreamContentType: String, Codable {
    case hls
    case mp4
    case segment
}

public struct CachedStreamItem: Codable, Identifiable, Hashable {
    public let id: String
    public let sourceURL: URL
    public var localRelativePath: String
    public var title: String
    public var groupTitle: String
    public var fileSizeBytes: Int64
    public var durationSeconds: Double
    public var cachedAt: Date
    public var lastAccessedAt: Date
    public var isPinned: Bool
    public var isComplete: Bool
    public var downloadProgress: Double
    public var status: CachedStreamStatus
    public var contentType: StreamContentType
    public var segmentCount: Int
    public var failureReason: String?

    public init(
        id: String = UUID().uuidString,
        sourceURL: URL,
        localRelativePath: String,
        title: String,
        groupTitle: String = "Offline Stream Cache",
        fileSizeBytes: Int64 = 0,
        durationSeconds: Double = 0.0,
        cachedAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        isPinned: Bool = false,
        isComplete: Bool = false,
        downloadProgress: Double = 0.0,
        status: CachedStreamStatus = .idle,
        contentType: StreamContentType = .hls,
        segmentCount: Int = 0,
        failureReason: String? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.localRelativePath = localRelativePath
        self.title = title
        self.groupTitle = groupTitle
        self.fileSizeBytes = fileSizeBytes
        self.durationSeconds = durationSeconds
        self.cachedAt = cachedAt
        self.lastAccessedAt = lastAccessedAt
        self.isPinned = isPinned
        self.isComplete = isComplete
        self.downloadProgress = downloadProgress
        self.status = status
        self.contentType = contentType
        self.segmentCount = segmentCount
        self.failureReason = failureReason
    }

    public func toChannelModel(cacheDirectory: URL) -> ChannelModel {
        let localURL = cacheDirectory.appendingPathComponent(localRelativePath)
        return ChannelModel(
            id: id,
            name: title + " [Offline Cached]",
            streamURL: localURL,
            groupTitle: "Offline Stream Cache",
            logoURL: nil,
            isFavorite: true,
            lastWatched: lastAccessedAt
        )
    }
}

public struct StreamCacheStorageMetrics: Equatable {
    public let currentSizeBytes: Int64
    public let maxQuotaBytes: Int64
    public let itemCount: Int
    public let pinnedItemCount: Int
    public let highwayBufferActive: Bool
    public let forwardBufferSeconds: Double

    public init(
        currentSizeBytes: Int64 = 0,
        maxQuotaBytes: Int64 = 5 * 1024 * 1024 * 1024,
        itemCount: Int = 0,
        pinnedItemCount: Int = 0,
        highwayBufferActive: Bool = true,
        forwardBufferSeconds: Double = 60.0
    ) {
        self.currentSizeBytes = currentSizeBytes
        self.maxQuotaBytes = maxQuotaBytes
        self.itemCount = itemCount
        self.pinnedItemCount = pinnedItemCount
        self.highwayBufferActive = highwayBufferActive
        self.forwardBufferSeconds = forwardBufferSeconds
    }

    public var usagePercentage: Double {
        guard maxQuotaBytes > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(currentSizeBytes) / Double(maxQuotaBytes)))
    }

    public var formattedUsage: String {
        let currentMB = Double(currentSizeBytes) / (1024 * 1024)
        let maxGB = Double(maxQuotaBytes) / (1024 * 1024 * 1024)
        if currentMB >= 1024 {
            let currentGB = currentMB / 1024
            return String(format: "%.2f GB / %.1f GB", currentGB, maxGB)
        } else {
            return String(format: "%.1f MB / %.1f GB", currentMB, maxGB)
        }
    }

    public var formattedQuota: String {
        let maxGB = Double(maxQuotaBytes) / (1024 * 1024 * 1024)
        return String(format: "%.0f GB", maxGB)
    }
}
