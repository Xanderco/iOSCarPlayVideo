import Foundation
import Combine

/// Single source of truth for the user's IPTV / M3U playlists.
/// Shared by the iPhone UI and the CarPlay scene so both always show the same channels.
@MainActor
public final class PlaylistStore: ObservableObject {
    public static let shared: PlaylistStore = {
        let store = PlaylistStore()
        store.canAddSource = { EntitlementGate.shared.request(.addPlaylistSource(existingCount: $0)) }
        return store
    }()

    /// Free-tier gate for adding a *new* playlist source (re-importing an existing one is always allowed).
    /// Receives the current number of sources. `nil` (tests, previews) means unrestricted.
    public var canAddSource: (@MainActor (Int) -> Bool)?

    /// Posted whenever playlists or favorites change (CarPlay listens to rebuild its templates).
    public static let didChangeNotification = Notification.Name("PlaylistStoreDidChange")

    public enum ImportError: LocalizedError, Equatable {
        case invalidURL
        case httpStatus(Int)
        case unreadable
        case noChannels
        case proRequired

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "That doesn't look like a valid playlist URL."
            case .httpStatus(let code): return "The server answered with HTTP \(code)."
            case .unreadable: return "The playlist file couldn't be read as text."
            case .noChannels: return "No playable channels were found in this playlist."
            case .proRequired: return "The free plan includes 1 playlist source. Unlock DashCast Pro for unlimited sources."
            }
        }
    }

    @Published public private(set) var playlists: [IPTVPlaylist]
    @Published public private(set) var favoriteIDs: Set<String>
    @Published public private(set) var hiddenGroups: Set<String>

    private let persistence: PersistenceController
    private let session: URLSession
    private let favoritesKey = "dashcast_favorite_channel_ids"
    private let hiddenGroupsKey = "dashcast_hidden_channel_groups"
    private let defaults: UserDefaults

    public init(persistence: PersistenceController = .shared,
                defaults: UserDefaults = .standard,
                session: URLSession = .shared) {
        self.persistence = persistence
        self.defaults = defaults
        self.session = session
        self.playlists = persistence.loadPlaylists()
        self.favoriteIDs = Set(defaults.stringArray(forKey: favoritesKey) ?? [])
        self.hiddenGroups = Set(defaults.stringArray(forKey: hiddenGroupsKey) ?? [])
    }

    // MARK: - Read

    /// Built-in demo channels, always available so the app is never empty.
    public var sampleChannels: [ChannelModel] { IPTVParser.samplePlaylist }

    /// Every channel the user imported, in playlist order.
    public var importedChannels: [ChannelModel] { playlists.flatMap(\.channels) }

    /// Imported channels first, then the samples.
    public var allChannels: [ChannelModel] { importedChannels + sampleChannels }

    /// Channels visible after applying `hiddenGroups` filters.
    public var visibleChannels: [ChannelModel] {
        guard !hiddenGroups.isEmpty else { return allChannels }
        return allChannels.filter { !hiddenGroups.contains($0.groupTitle) }
    }

    public var favoriteChannels: [ChannelModel] {
        allChannels.filter { favoriteIDs.contains(favoriteKey(for: $0)) }
    }

    /// Distinct channel group titles across `allChannels` in first-seen order.
    public var availableGroups: [String] {
        groupedChannels(allChannels).map(\.group)
    }

    /// Channels grouped by `group-title`, preserving first-seen order.
    public func groupedChannels(_ channels: [ChannelModel]? = nil) -> [(group: String, channels: [ChannelModel])] {
        var order: [String] = []
        var map: [String: [ChannelModel]] = [:]
        for channel in channels ?? allChannels {
            if map[channel.groupTitle] == nil { order.append(channel.groupTitle) }
            map[channel.groupTitle, default: []].append(channel)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    public func visibleGroupedChannels() -> [(group: String, channels: [ChannelModel])] {
        groupedChannels(visibleChannels)
    }

    public func isGroupHidden(_ group: String) -> Bool {
        hiddenGroups.contains(group)
    }

    public func isFavorite(_ channel: ChannelModel) -> Bool {
        favoriteIDs.contains(favoriteKey(for: channel))
    }

    // MARK: - Write

    @discardableResult
    public func importPlaylist(from urlString: String, title: String? = nil) async throws -> IPTVPlaylist {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            throw ImportError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ImportError.httpStatus(http.statusCode)
        }
        return try addPlaylist(data: data, sourceURL: url, title: title)
    }

    /// Imports a playlist from a local file (Files app, share sheet, AirDrop).
    @discardableResult
    public func importPlaylist(fileURL: URL) throws -> IPTVPlaylist {
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: fileURL)
        return try addPlaylist(data: data, sourceURL: nil,
                               title: fileURL.deletingPathExtension().lastPathComponent)
    }

    /// Parses raw playlist data and stores it. Exposed for tests.
    @discardableResult
    public func addPlaylist(data: Data, sourceURL: URL?, title: String?) throws -> IPTVPlaylist {
        guard let content = IPTVParser.decode(data) else { throw ImportError.unreadable }
        let channels = IPTVParser.parseM3U(content: content, baseURL: sourceURL)
        guard !channels.isEmpty else { throw ImportError.noChannels }

        let name = title?.isEmpty == false
            ? title!
            : (sourceURL?.host ?? "Playlist \(playlists.count + 1)")

        // Re-importing the same URL replaces the old copy instead of duplicating it.
        if let sourceURL, let index = playlists.firstIndex(where: { $0.url == sourceURL }) {
            playlists[index].channels = channels
            playlists[index].title = name
            save()
            return playlists[index]
        }

        if let canAddSource, !canAddSource(playlists.count) {
            throw ImportError.proRequired
        }

        let playlist = IPTVPlaylist(title: name, url: sourceURL, channels: channels)
        playlists.append(playlist)
        save()
        return playlist
    }

    /// Re-downloads every playlist that came from a URL.
    public func refreshAll() async {
        for playlist in playlists {
            guard let url = playlist.url else { continue }
            _ = try? await importPlaylist(from: url.absoluteString, title: playlist.title)
        }
    }

    public func removePlaylist(id: UUID) {
        playlists.removeAll { $0.id == id }
        save()
    }

    public func renamePlaylist(id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = playlists.firstIndex(where: { $0.id == id }),
              playlists[index].title != trimmed else { return }
        playlists[index].title = trimmed
        save()
    }

    public func movePlaylists(fromOffsets: IndexSet, toOffset: Int) {
        let valid = fromOffsets.filter { $0 >= 0 && $0 < playlists.count }
        guard !valid.isEmpty else { return }
        let moving = valid.map { playlists[$0] }
        var remaining: [IPTVPlaylist] = []
        remaining.reserveCapacity(playlists.count - valid.count)
        for (index, playlist) in playlists.enumerated() where !valid.contains(index) {
            remaining.append(playlist)
        }
        let removedBeforeTarget = valid.filter { $0 < toOffset }.count
        let insertionIndex = max(0, min(toOffset - removedBeforeTarget, remaining.count))
        remaining.insert(contentsOf: moving, at: insertionIndex)
        guard remaining.map(\.id) != playlists.map(\.id) else { return }
        playlists = remaining
        save()
    }

    public func setGroupHidden(_ group: String, hidden: Bool) {
        if hidden {
            guard !hiddenGroups.contains(group) else { return }
            hiddenGroups.insert(group)
        } else {
            guard hiddenGroups.contains(group) else { return }
            hiddenGroups.remove(group)
        }
        saveHiddenGroups()
    }

    public func toggleGroupVisibility(_ group: String) {
        setGroupHidden(group, hidden: !hiddenGroups.contains(group))
    }

    public func showAllGroups() {
        guard !hiddenGroups.isEmpty else { return }
        hiddenGroups.removeAll()
        saveHiddenGroups()
    }

    public func exportBackupData() throws -> Data {
        try PlaylistBackupService.encodeBackup(
            playlists: playlists,
            favoriteStreamURLs: Array(favoriteIDs),
            hiddenGroups: Array(hiddenGroups)
        )
    }

    @discardableResult
    public func importBackupData(_ data: Data, replaceExisting: Bool = false) throws -> PlaylistBackupSummary {
        let payload = try PlaylistBackupService.decodeBackup(from: data)

        var nextPlaylists = replaceExisting ? [] : playlists
        var addedCount = 0
        var updatedCount = 0

        for incoming in payload.playlists {
            if let sourceURL = incoming.url,
               let existingIndex = nextPlaylists.firstIndex(where: { $0.url == sourceURL }) {
                nextPlaylists[existingIndex].title = incoming.title
                nextPlaylists[existingIndex].channels = incoming.channels
                updatedCount += 1
            } else if let existingIndex = nextPlaylists.firstIndex(where: { $0.id == incoming.id }) {
                nextPlaylists[existingIndex].title = incoming.title
                nextPlaylists[existingIndex].channels = incoming.channels
                updatedCount += 1
            } else {
                if let canAddSource, !canAddSource(nextPlaylists.count) {
                    throw ImportError.proRequired
                }
                nextPlaylists.append(incoming)
                addedCount += 1
            }
        }

        var nextFavorites = replaceExisting ? Set<String>() : favoriteIDs
        var favoritesAdded = 0
        for url in payload.favoriteStreamURLs {
            if nextFavorites.insert(url).inserted {
                favoritesAdded += 1
            }
        }

        var nextHidden = replaceExisting ? Set<String>() : hiddenGroups
        var hiddenAdded = 0
        for group in payload.hiddenGroups {
            if nextHidden.insert(group).inserted {
                hiddenAdded += 1
            }
        }

        playlists = nextPlaylists
        favoriteIDs = nextFavorites
        hiddenGroups = nextHidden

        persistence.savePlaylists(playlists)
        defaults.set(Array(favoriteIDs).sorted(), forKey: favoritesKey)
        defaults.set(Array(hiddenGroups).sorted(), forKey: hiddenGroupsKey)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)

        return PlaylistBackupSummary(
            playlistsAdded: addedCount,
            playlistsUpdated: updatedCount,
            favoritesAdded: favoritesAdded,
            hiddenGroupsAdded: hiddenAdded
        )
    }

    public func toggleFavorite(_ channel: ChannelModel) {
        let key = favoriteKey(for: channel)
        if favoriteIDs.contains(key) { favoriteIDs.remove(key) } else { favoriteIDs.insert(key) }
        defaults.set(Array(favoriteIDs), forKey: favoritesKey)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    // MARK: - Private

    /// Channel IDs are regenerated on every import, so favorites are keyed by stream URL.
    private func favoriteKey(for channel: ChannelModel) -> String {
        channel.streamURL.absoluteString
    }

    private func save() {
        persistence.savePlaylists(playlists)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private func saveHiddenGroups() {
        defaults.set(Array(hiddenGroups).sorted(), forKey: hiddenGroupsKey)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}

import UniformTypeIdentifiers

public extension PlaylistStore {
    /// Content types accepted by the Files importer for playlists.
    static var playlistContentTypes: [UTType] {
        var types: [UTType] = [.plainText, .text, .data]
        for ext in ["m3u", "m3u8"] {
            if let t = UTType(filenameExtension: ext) { types.insert(t, at: 0) }
        }
        return types
    }
}
