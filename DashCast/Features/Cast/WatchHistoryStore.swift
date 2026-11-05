import Foundation
import Combine

/// Remembers what the user watched (Recently Watched) and where they stopped in
/// on-demand videos (Continue Watching). Everything stays on device in UserDefaults.
///
/// Listens to `VideoPlayerService` so every playback path (Home, Library, browser
/// hand-off, CarPlay) is recorded without the callers having to opt in.
@MainActor
public final class WatchHistoryStore: ObservableObject {
    public static let shared = WatchHistoryStore()

    public struct Entry: Codable, Identifiable, Hashable {
        public var channel: ChannelModel
        public var lastWatched: Date
        /// Seconds into the video. 0 for live streams.
        public var position: Double
        /// Total length in seconds. 0 means live / unknown.
        public var duration: Double

        public var id: String { channel.streamURL.absoluteString }

        public var isLive: Bool { duration <= 0 }

        /// 0...1 progress for on-demand items, nil for live streams.
        public var progress: Double? {
            guard duration > 0 else { return nil }
            return min(max(position / duration, 0), 1)
        }

        /// Worth offering "Continue Watching": started, not basically finished.
        public var isResumable: Bool {
            guard let progress else { return false }
            return position >= WatchHistoryStore.minimumResumeSeconds && progress < 0.95
        }
    }

    /// Positions shorter than this are not worth resuming.
    nonisolated public static let minimumResumeSeconds: Double = 10
    nonisolated public static let maxEntries = 30

    @Published public private(set) var entries: [Entry] = []

    private let defaults: UserDefaults
    private let storageKey = "dashcast_watch_history_v1"
    private var cancellables = Set<AnyCancellable>()
    private var isObserving = false
    private var lastSavedAt = Date.distantPast

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = decoded
        }
    }

    // MARK: - Read

    /// Most recent first.
    public var recents: [Entry] { entries.sorted { $0.lastWatched > $1.lastWatched } }

    public var continueWatching: [Entry] { recents.filter(\.isResumable) }

    public func entry(for channel: ChannelModel) -> Entry? {
        entries.first { $0.id == channel.streamURL.absoluteString }
    }

    /// Best guess whether a channel is a live stream (for the LIVE badge before it plays).
    public func looksLive(_ channel: ChannelModel) -> Bool {
        if channel.streamURL.isFileURL { return false }
        if let entry = entry(for: channel), entry.duration > 0 { return false }
        return true
    }

    // MARK: - Write

    /// Records that `channel` started playing (moves it to the top of recents).
    public func recordStart(_ channel: ChannelModel, now: Date = Date()) {
        if let index = entries.firstIndex(where: { $0.id == channel.streamURL.absoluteString }) {
            entries[index].channel = channel
            entries[index].lastWatched = now
        } else {
            entries.append(Entry(channel: channel, lastWatched: now, position: 0, duration: 0))
        }
        trim()
        persist()
    }

    /// Updates the saved position for `channel`.
    public func recordProgress(_ channel: ChannelModel, position: Double, duration: Double, now: Date = Date()) {
        guard position.isFinite, duration.isFinite else { return }
        guard let index = entries.firstIndex(where: { $0.id == channel.streamURL.absoluteString }) else {
            entries.append(Entry(channel: channel, lastWatched: now, position: position, duration: duration))
            trim()
            persist()
            return
        }
        entries[index].position = max(0, position)
        entries[index].duration = max(0, duration)
        entries[index].lastWatched = now
        persist()
    }

    public func remove(_ entry: Entry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    public func clear() {
        entries = []
        persist()
    }

    // MARK: - Player integration

    /// Starts recording plays and positions from the shared player. Safe to call repeatedly.
    public func startObserving(_ player: VideoPlayerService = .shared) {
        guard !isObserving else { return }
        isObserving = true

        player.$currentChannel
            .removeDuplicates()
            .sink { [weak self] channel in
                MainActor.assumeIsolated {
                    guard let self, let channel else { return }
                    self.recordStart(channel)
                }
            }
            .store(in: &cancellables)

        player.$currentTime
            .sink { [weak self, weak player] time in
                MainActor.assumeIsolated {
                    guard let self, let player, let channel = player.currentChannel else { return }
                    // Throttle disk writes to every 5 s of playback.
                    let now = Date()
                    guard now.timeIntervalSince(self.lastSavedAt) >= 5 else { return }
                    self.lastSavedAt = now
                    self.recordProgress(channel, position: time, duration: player.duration, now: now)
                }
            }
            .store(in: &cancellables)
    }

    /// Plays `channel`, jumping back to the saved position for on-demand videos.
    public func play(_ channel: ChannelModel, on player: VideoPlayerService = .shared) {
        let resumeAt = entry(for: channel).flatMap { $0.isResumable ? $0.position : nil }
        player.load(channel: channel)
        if let resumeAt {
            player.seek(to: resumeAt)
        }
    }

    // MARK: - Private

    private func trim() {
        guard entries.count > Self.maxEntries else { return }
        entries = Array(recents.prefix(Self.maxEntries))
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: storageKey)
        }
    }
}

/// Works out the channel list the user is "inside" so Player and Car Mode can offer
/// one-tap previous / next and an Up Next list.
@MainActor
public enum PlaybackQueue {
    /// Channels that share the current channel's group, across all sources.
    public static func siblings(of channel: ChannelModel?,
                                store: PlaylistStore = .shared,
                                localVideos: [ChannelModel] = LocalVideoManager.shared.localVideos) -> [ChannelModel] {
        guard let channel else { return [] }
        let pool = store.allChannels + localVideos
        let group = pool.filter { $0.groupTitle == channel.groupTitle }
        return group.isEmpty ? [channel] : group
    }

    /// The channel after (`offset` = 1) or before (`offset` = -1) `channel`, wrapping around.
    public static func neighbor(of channel: ChannelModel?, offset: Int,
                                in list: [ChannelModel]) -> ChannelModel? {
        guard let channel, list.count > 1,
              let index = list.firstIndex(where: { $0.streamURL == channel.streamURL }) else { return nil }
        let next = (index + offset % list.count + list.count) % list.count
        return list[next]
    }
}
