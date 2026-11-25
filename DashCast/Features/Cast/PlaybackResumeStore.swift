import Foundation

/// Persists playback timestamps for VOD streams and local videos so passengers can
/// resume where they left off. Live streams (`duration <= 0`) and items at or past
/// 95% completion are never persisted/resumed.
@MainActor
public final class PlaybackResumeStore: ObservableObject {
    public static let shared = PlaybackResumeStore()

    /// Completion ratio at or above which resume memory is cleared automatically.
    nonisolated public static let completionThreshold: Double = 0.95
    nonisolated public static let defaultMaxEntries: Int = 100
    nonisolated public static let defaultStorageKey = "dashcast_playback_resume_positions"

    public struct Entry: Codable, Equatable, Sendable {
        public let key: String
        public var positionSeconds: Double
        public var durationSeconds: Double
        public var updatedAt: Date

        public init(key: String, positionSeconds: Double, durationSeconds: Double, updatedAt: Date = Date()) {
            self.key = key
            self.positionSeconds = positionSeconds
            self.durationSeconds = durationSeconds
            self.updatedAt = updatedAt
        }
    }

    @Published public private(set) var entries: [String: Entry] = [:]

    private let defaults: UserDefaults
    private let storageKey: String
    private let maxEntries: Int

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = PlaybackResumeStore.defaultStorageKey,
        maxEntries: Int = PlaybackResumeStore.defaultMaxEntries
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.maxEntries = max(1, maxEntries)
        loadEntries()
    }

    /// Stable storage key for a channel. Local files key on their filename so resume
    /// positions survive iOS app container path changes across updates, while remote
    /// streams key on their URL.
    nonisolated public static func itemKey(for channel: ChannelModel) -> String {
        if channel.streamURL.isFileURL {
            return "file:\(channel.streamURL.lastPathComponent)"
        }
        return channel.streamURL.absoluteString
    }

    /// Returns true only for finite, positive-duration VOD/local items strictly below
    /// the completion threshold.
    nonisolated public static func isResumable(
        position: Double,
        duration: Double,
        completionThreshold: Double = PlaybackResumeStore.completionThreshold
    ) -> Bool {
        guard duration.isFinite, duration > 0, position.isFinite, position > 0 else {
            return false
        }
        return (position / duration) < completionThreshold
    }

    /// Saves the playback position for a VOD or local video, or clears it when completed
    /// (>= 95%) or reset to 0. Live streams (`duration <= 0`) are ignored.
    public func savePosition(_ position: Double, duration: Double, for channel: ChannelModel, now: Date = Date()) {
        guard channel.id != CarPlayMirrorPlayback.channelID else { return }
        guard duration.isFinite, duration > 0 else { return }

        let key = Self.itemKey(for: channel)
        guard Self.isResumable(position: position, duration: duration) else {
            if entries.removeValue(forKey: key) != nil {
                persistEntries()
            }
            return
        }

        entries[key] = Entry(
            key: key,
            positionSeconds: position,
            durationSeconds: duration,
            updatedAt: now
        )
        trimToMaxEntriesIfNeeded()
        persistEntries()
    }

    /// Returns the saved resume timestamp in seconds for a VOD/local item, or `nil` if
    /// none exists or the item was already completed.
    public func resumePosition(for channel: ChannelModel) -> Double? {
        guard channel.id != CarPlayMirrorPlayback.channelID else { return nil }
        let key = Self.itemKey(for: channel)
        guard let entry = entries[key] else { return nil }
        guard Self.isResumable(position: entry.positionSeconds, duration: entry.durationSeconds) else {
            return nil
        }
        return entry.positionSeconds
    }

    public func clearPosition(for channel: ChannelModel) {
        let key = Self.itemKey(for: channel)
        if entries.removeValue(forKey: key) != nil {
            persistEntries()
        }
    }

    public func clearAll() {
        guard !entries.isEmpty else { return }
        entries.removeAll()
        defaults.removeObject(forKey: storageKey)
    }

    // MARK: - Persistence

    private func trimToMaxEntriesIfNeeded() {
        guard entries.count > maxEntries else { return }
        let sortedKeys = entries.values
            .sorted { $0.updatedAt < $1.updatedAt }
            .map(\.key)
        let overflow = entries.count - maxEntries
        for key in sortedKeys.prefix(overflow) {
            entries.removeValue(forKey: key)
        }
    }

    private func loadEntries() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            entries = [:]
            return
        }
        entries = decoded.filter { Self.isResumable(position: $0.value.positionSeconds, duration: $0.value.durationSeconds) }
    }

    private func persistEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
