import Foundation

public final class DeadzoneCacheStorageEngine {
    public let cacheDirectory: URL
    private let manifestURL: URL
    private let fileManager: FileManager

    public init(
        customDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let customDir = customDirectory {
            self.cacheDirectory = customDir
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.cacheDirectory = appSupport.appendingPathComponent("DashCastDeadzoneCache", isDirectory: true)
        }
        self.manifestURL = self.cacheDirectory.appendingPathComponent("manifest.json")
        ensureDirectoryExists()
    }

    public static let `default` = DeadzoneCacheStorageEngine()

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    public func loadManifest() -> [DeadzoneCacheItem] {
        guard fileManager.fileExists(atPath: manifestURL.path),
              let data = try? Data(contentsOf: manifestURL),
              let items = try? JSONDecoder().decode([DeadzoneCacheItem].self, from: data) else {
            return []
        }
        return items
    }

    public func saveManifest(_ items: [DeadzoneCacheItem]) {
        ensureDirectoryExists()
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }

    public func localFileURL(for fileName: String) -> URL {
        cacheDirectory.appendingPathComponent(fileName)
    }

    public func fileExists(for fileName: String) -> Bool {
        let path = localFileURL(for: fileName).path
        return fileManager.fileExists(atPath: path)
    }

    public func fileSize(for fileName: String) -> Int64 {
        let path = localFileURL(for: fileName).path
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }

    public func writeData(_ data: Data, fileName: String) throws {
        ensureDirectoryExists()
        let destination = localFileURL(for: fileName)
        try data.write(to: destination, options: .atomic)
    }

    public func copyFile(from sourceURL: URL, fileName: String) throws {
        ensureDirectoryExists()
        let destination = localFileURL(for: fileName)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
    }

    public func removeFile(for fileName: String) {
        let destination = localFileURL(for: fileName)
        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination)
        }
    }

    public func clearAllFiles() {
        let items = loadManifest()
        for item in items {
            removeFile(for: item.localFileName)
        }
        if fileManager.fileExists(atPath: manifestURL.path) {
            try? fileManager.removeItem(at: manifestURL)
        }
    }

    /// Enforces storage limit using deterministic LRU (Least Recently Used) eviction.
    /// Pinned items are NEVER evicted.
    /// Returns the list of evicted items.
    public func enforceStorageLimit(
        maxSizeBytes: Int64,
        currentItems: inout [DeadzoneCacheItem]
    ) -> [DeadzoneCacheItem] {
        var totalSize: Int64 = currentItems.reduce(0) { $0 + $1.fileSizeBytes }
        if totalSize <= maxSizeBytes {
            return []
        }

        // Sort candidate unpinned items by lastAccessedAt ascending (oldest first)
        let unpinnedCandidates = currentItems
            .filter { !$0.isPinned && $0.isComplete }
            .sorted { $0.lastAccessedAt < $1.lastAccessedAt }

        var evictedItems: [DeadzoneCacheItem] = []

        for candidate in unpinnedCandidates {
            guard totalSize > maxSizeBytes else { break }

            // Evict file from disk
            removeFile(for: candidate.localFileName)
            evictedItems.append(candidate)
            totalSize -= candidate.fileSizeBytes

            // Remove from active items list
            if let index = currentItems.firstIndex(where: { $0.id == candidate.id }) {
                currentItems.remove(at: index)
            }
        }

        saveManifest(currentItems)
        return evictedItems
    }
}
