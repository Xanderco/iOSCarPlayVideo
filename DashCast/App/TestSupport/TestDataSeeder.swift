import Foundation

/// Seeds deterministic Cast content for UI tests and screenshots (`-seedDemoData`).
/// Uses only bundled media so it works offline.
@MainActor
enum TestDataSeeder {
    static let playlistTitle = "Demo Playlist"

    static func seedPlaylists(store: PlaylistStore = .shared) {
        guard !store.playlists.contains(where: { $0.title == playlistTitle }) else { return }
        guard let playlist = try? store.addPlaylist(data: Data(StubNetwork.demoPlaylistM3U.utf8),
                                                    sourceURL: nil,
                                                    title: playlistTitle) else { return }
        if let first = playlist.channels.first, !store.isFavorite(first) {
            store.toggleFavorite(first)
        }
    }
}
