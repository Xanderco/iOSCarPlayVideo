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

    private let persistence: PersistenceController
    private let session: URLSession
    private let favoritesKey = "dashcast_favorite_channel_ids"
    private let defaults: UserDefaults

    public init(persistence: PersistenceController = .shared,
                defaults: UserDefaults = .standard,
                session: URLSession = .shared) {
        self.persistence = persistence
        self.defaults = defaults
        self.session = session
        self.playlists = persistence.loadPlaylists()
        self.favoriteIDs = Set(defaults.stringArray(forKey: favoritesKey) ?? [])
    }

    // MARK: - Read

    /// Built-in demo channels, always available so the app is never empty.
    public var sampleChannels: [ChannelModel] { IPTVParser.samplePlaylist }

    /// Every channel the user imported, in playlist order.
    public var importedChannels: [ChannelModel] { playlists.flatMap(\.channels) }

    /// Imported channels first, then the samples.
    public var allChannels: [ChannelModel] { importedChannels + sampleChannels }

    public var favoriteChannels: [ChannelModel] {
        allChannels.filter { favoriteIDs.contains(favoriteKey(for: $0)) }
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
