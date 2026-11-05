import CarPlay
import MediaPlayer
import UIKit

/// CarPlay scene. Shows the user's imported playlists (from `PlaylistStore.shared`),
/// their favorites and a short info tab. Selecting a channel starts playback through
/// `VideoPlayerService.shared` and shows the system Now Playing screen.
///
/// NOTE: CarPlay only shows this app once Apple grants a CarPlay entitlement.
/// See Docs/CarPlay.md.
///
/// `UIResponder` is `@MainActor`, so this whole class (and every closure it creates
/// for CarPlay templates) runs on the main actor.
@MainActor
public final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    public var interfaceController: CPInterfaceController?

    private var libraryTemplate: CPListTemplate?
    private var favoritesTemplate: CPListTemplate?
    private var playlistObserver: NSObjectProtocol?
    private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []

    // MARK: - Scene lifecycle

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let library = CPListTemplate(title: "Library", sections: [])
        library.tabTitle = "Library"
        library.tabImage = UIImage(systemName: "tv.fill")
        library.emptyViewTitleVariants = ["No channels"]
        library.emptyViewSubtitleVariants = ["Import an M3U playlist on your iPhone"]
        libraryTemplate = library

        let favorites = CPListTemplate(title: "Favorites", sections: [])
        favorites.tabTitle = "Favorites"
        favorites.tabImage = UIImage(systemName: "heart.fill")
        favoritesTemplate = favorites

        let tabBar = CPTabBarTemplate(templates: [library, favorites, makeInfoTemplate()])

        rebuildTemplates()
        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)

        playlistObserver = NotificationCenter.default.addObserver(
            forName: PlaylistStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuildTemplates()
            }
        }

        configureRemoteCommands()
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        if let playlistObserver {
            NotificationCenter.default.removeObserver(playlistObserver)
        }
        playlistObserver = nil
        removeRemoteCommands()
        libraryTemplate = nil
        favoritesTemplate = nil
        self.interfaceController = nil
    }

    // MARK: - Templates

    /// Rebuilds Library and Favorites from the current playlist store.
    private func rebuildTemplates() {
        let store = PlaylistStore.shared
        libraryTemplate?.updateSections(makeLibrarySections(store: store))
        favoritesTemplate?.updateSections(makeFavoritesSections(store: store))
    }

    /// Library root: one row per group. Tapping a group pushes its channel list.
    private func makeLibrarySections(store: PlaylistStore) -> [CPListSection] {
        let maxItems = Int(CPListTemplate.maximumItemCount)
        let groups = store.groupedChannels(store.allChannels)
        guard !groups.isEmpty else { return [] }

        let items: [CPListItem] = groups.prefix(maxItems).map { entry in
            let group = entry.group
            let channels = entry.channels
            let item = CPListItem(
                text: group.isEmpty ? "Other" : group,
                detailText: channels.count == 1 ? "1 channel" : "\(channels.count) channels",
                image: UIImage(systemName: "folder.fill")
            )
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.pushGroup(title: group.isEmpty ? "Other" : group, channels: channels)
                completion()
            }
            return item
        }
        return [CPListSection(items: items)]
    }

    private func makeFavoritesSections(store: PlaylistStore) -> [CPListSection] {
        let favorites = store.favoriteChannels
        guard !favorites.isEmpty else {
            let empty = CPListItem(
                text: "No Favorites Yet",
                detailText: "Tap the heart on a channel on your iPhone",
                image: UIImage(systemName: "heart")
            )
            empty.handler = { _, completion in completion() }
            return [CPListSection(items: [empty])]
        }
        // Favorites are sectioned by group, within CarPlay's section and item limits.
        let maxSections = Int(CPListTemplate.maximumSectionCount)
        var remaining = Int(CPListTemplate.maximumItemCount)
        var sections: [CPListSection] = []
        for entry in store.groupedChannels(favorites).prefix(maxSections) where remaining > 0 {
            let items = entry.channels.prefix(remaining).map { makeChannelItem($0, showGroup: false) }
            remaining -= items.count
            sections.append(CPListSection(items: Array(items),
                                          header: entry.group.isEmpty ? "Other" : entry.group,
                                          sectionIndexTitle: nil))
        }
        return sections
    }

    /// One section of channels, capped at CarPlay's item limit.
    private func channelSections(_ channels: [ChannelModel], showGroup: Bool) -> [CPListSection] {
        let maxItems = Int(CPListTemplate.maximumItemCount)
        let items = channels.prefix(maxItems).map { makeChannelItem($0, showGroup: showGroup) }
        return [CPListSection(items: Array(items))]
    }

    private func makeChannelItem(_ channel: ChannelModel, showGroup: Bool) -> CPListItem {
        let item = CPListItem(
            text: channel.name,
            detailText: showGroup ? channel.groupTitle : nil,
            image: UIImage(systemName: "play.tv.fill")
        )
        item.isPlaying = VideoPlayerService.shared.currentChannel?.streamURL == channel.streamURL
        item.handler = { [weak self] _, completion in
            self?.play(channel)
            completion()
        }
        return item
    }

    private func pushGroup(title: String, channels: [ChannelModel]) {
        guard let interfaceController else { return }
        let template = CPListTemplate(title: title, sections: channelSections(channels, showGroup: false))
        interfaceController.pushTemplate(template, animated: true, completion: nil)
    }

    private func makeInfoTemplate() -> CPListTemplate {
        let items = [
            CPListItem(text: "Your channels, on the big screen",
                       detailText: "Import IPTV playlists on your iPhone"),
            CPListItem(text: "Audio while driving",
                       detailText: "Video is only shown when parked, via AirPlay")
        ]
        for item in items {
            item.handler = { _, completion in completion() }
        }
        let template = CPListTemplate(title: "DashCast", sections: [CPListSection(items: items)])
        template.tabTitle = "Info"
        template.tabImage = UIImage(systemName: "info.circle.fill")
        return template
    }

    // MARK: - Playback

    private func play(_ channel: ChannelModel) {
        VideoPlayerService.shared.load(channel: channel)
        updateNowPlayingInfo(for: channel, isPlaying: true)
        rebuildTemplates()
        showNowPlaying()
    }

    private func showNowPlaying() {
        guard let interfaceController else { return }
        let nowPlaying = CPNowPlayingTemplate.shared
        if interfaceController.topTemplate === nowPlaying { return }
        if interfaceController.templates.contains(where: { $0 === nowPlaying }) {
            interfaceController.pop(to: nowPlaying, animated: true, completion: nil)
        } else {
            interfaceController.pushTemplate(nowPlaying, animated: true, completion: nil)
        }
    }

    private func updateNowPlayingInfo(for channel: ChannelModel?, isPlaying: Bool) {
        guard let channel else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: channel.name,
            MPMediaItemPropertyArtist: channel.groupTitle,
            MPMediaItemPropertyAlbumTitle: "DashCast",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }

    private func configureRemoteCommands() {
        removeRemoteCommands()
        let center = MPRemoteCommandCenter.shared()

        func register(_ command: MPRemoteCommand, _ action: @escaping @MainActor @Sendable () -> Void) {
            command.isEnabled = true
            let token = command.addTarget { _ in
                Task { @MainActor in action() }
                return .success
            }
            remoteCommandTargets.append((command, token))
        }

        register(center.playCommand) { [weak self] in
            VideoPlayerService.shared.play()
            self?.syncNowPlayingRate()
        }
        register(center.pauseCommand) { [weak self] in
            VideoPlayerService.shared.pause()
            self?.syncNowPlayingRate()
        }
        register(center.togglePlayPauseCommand) { [weak self] in
            VideoPlayerService.shared.togglePlayPause()
            self?.syncNowPlayingRate()
        }
    }

    private func syncNowPlayingRate() {
        let service = VideoPlayerService.shared
        updateNowPlayingInfo(for: service.currentChannel, isPlaying: service.isPlaying)
    }

    private func removeRemoteCommands() {
        for (command, token) in remoteCommandTargets {
            command.removeTarget(token)
        }
        remoteCommandTargets.removeAll()
    }
}
