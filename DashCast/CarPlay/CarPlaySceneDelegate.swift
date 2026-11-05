import CarPlay
import Combine
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
/// CarPlay calls the delegate on the main thread but the SDK protocol isn't `@MainActor`;
/// `@preconcurrency` states that and silences "conformance crosses into main actor-isolated code".
@MainActor
public final class CarPlaySceneDelegate: UIResponder, @preconcurrency CPTemplateApplicationSceneDelegate {
    public var interfaceController: CPInterfaceController?

    private var libraryTemplate: CPListTemplate?
    private var favoritesTemplate: CPListTemplate?
    private var playlistObserver: NSObjectProtocol?
    private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []
    private var playerCancellable: AnyCancellable?

    /// CarPlay audio apps may stack at most five templates (root included); pushing more
    /// raises an exception in CarPlay. Now Playing counts towards the depth.
    private static let maximumTemplateDepth = 5

    // MARK: - Scene lifecycle

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let library = Self.libraryTemplate()
        libraryTemplate = library

        let favorites = Self.favoritesTemplate()
        favoritesTemplate = favorites

        // Only templates allowed for the CarPlay Audio category (tab bar, list, Now Playing).
        // CPInformationTemplate is NOT allowed for audio apps and would throw.
        let tabs: [CPTemplate] = [library, favorites, makeInfoTemplate(), Self.mirrorInstructionsTemplate { [weak self] in
            self?.startMirror()
        }]
        let tabBar = CPTabBarTemplate(templates: Array(tabs.prefix(Int(CPTabBarTemplate.maximumTabCount))))

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
        observePlayer()
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
        playerCancellable = nil
        libraryTemplate = nil
        favoritesTemplate = nil
        self.interfaceController = nil
    }

    // MARK: - CarPlay window (mirror iPhone to the car screen)
    // iOS only calls these when the app holds a CarPlay entitlement that grants a
    // drawable window (see ADR-002 §7). Without it they are never called and the
    // template UI above is the graceful fallback.

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.templateApplicationScene(templateApplicationScene, didConnect: interfaceController)
        CarPlayMirrorController.shared.attach(to: window)
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        CarPlayMirrorController.shared.detach()
        self.templateApplicationScene(templateApplicationScene, didDisconnectInterfaceController: interfaceController)
    }

    // MARK: - Templates

    /// Rebuilds Library and Favorites from the current playlist store.
    private func rebuildTemplates() {
        let store = PlaylistStore.shared
        libraryTemplate?.updateSections(makeLibrarySections(store: store))
        favoritesTemplate?.updateSections(makeFavoritesSections(store: store))

        // Group lists pushed from Library carry their group name in `userInfo`;
        // refresh them so they never show channels that were removed.
        guard let interfaceController else { return }
        let groups = store.groupedChannels(store.allChannels)
        for case let template as CPListTemplate in interfaceController.templates {
            guard let group = template.userInfo as? String else { continue }
            let channels = groups.first(where: { $0.group == group })?.channels ?? []
            template.updateSections(channelSections(channels, showGroup: false))
        }
    }

    /// Updates the playing indicator on every visible channel row without rebuilding lists.
    private func refreshPlayingIndicators() {
        let playingURL = VideoPlayerService.shared.currentChannel?.streamURL
        var templates: [CPListTemplate] = [libraryTemplate, favoritesTemplate].compactMap { $0 }
        templates += interfaceController?.templates.compactMap { $0 as? CPListTemplate } ?? []
        for template in templates {
            for section in template.sections {
                for case let item as CPListItem in section.items {
                    guard let url = item.userInfo as? URL else { continue }
                    item.isPlaying = url == playingURL
                }
            }
        }
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
                self?.pushGroup(group, title: group.isEmpty ? "Other" : group, channels: channels)
                completion()
            }
            return item
        }
        return [CPListSection(items: items)]
    }

    private func makeFavoritesSections(store: PlaylistStore) -> [CPListSection] {
        let favorites = store.favoriteChannels
        // An empty template shows `emptyViewTitleVariants` / `emptyViewSubtitleVariants`.
        guard !favorites.isEmpty else { return [] }
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
        guard !channels.isEmpty else { return [] }
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
        item.userInfo = channel.streamURL
        item.isPlaying = VideoPlayerService.shared.currentChannel?.streamURL == channel.streamURL
        item.handler = { [weak self] _, completion in
            self?.play(channel)
            completion()
        }
        return item
    }

    private func pushGroup(_ group: String, title: String, channels: [ChannelModel]) {
        guard let interfaceController, canPush(onto: interfaceController) else { return }
        let template = CPListTemplate(title: title, sections: channelSections(channels, showGroup: false))
        template.userInfo = group
        template.emptyViewTitleVariants = ["No channels"]
        interfaceController.pushTemplate(template, animated: true, completion: nil)
    }

    private func canPush(onto interfaceController: CPInterfaceController) -> Bool {
        interfaceController.templates.count < Self.maximumTemplateDepth
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

    // MARK: - Tab templates (static so unit tests can build them without a car)

    static func libraryTemplate() -> CPListTemplate {
        let library = CPListTemplate(title: "Library", sections: [])
        library.tabTitle = "Library"
        library.tabImage = UIImage(systemName: "tv.fill")
        library.emptyViewTitleVariants = ["No channels"]
        library.emptyViewSubtitleVariants = ["Import an M3U playlist on your iPhone"]
        return library
    }

    static func favoritesTemplate() -> CPListTemplate {
        let favorites = CPListTemplate(title: "Favorites", sections: [])
        favorites.tabTitle = "Favorites"
        favorites.tabImage = UIImage(systemName: "heart.fill")
        favorites.emptyViewTitleVariants = ["No Favorites Yet"]
        favorites.emptyViewSubtitleVariants = ["Tap the heart on a channel on your iPhone"]
        return favorites
    }

    /// Car-screen instructions for mirroring the iPhone (the "Cast" tab). A list, because
    /// CPInformationTemplate is not allowed for CarPlay Audio apps.
    /// With `onMirror`, a second section adds the "Show iPhone screen" action, which plays the
    /// broadcast extension's HLS stream through the system player (ADR-002 §7.5).
    static func mirrorInstructionsTemplate(onMirror: (() -> Void)? = nil) -> CPListTemplate {
        let steps = mirrorInstructionSteps.enumerated().map { index, step -> CPListItem in
            let item = CPListItem(
                text: step.title,
                detailText: step.detail,
                image: UIImage(systemName: "\(index + 1).circle.fill")
            )
            item.isEnabled = false
            return item
        }
        var sections = [CPListSection(items: steps, header: "Show your iPhone on this screen", sectionIndexTitle: nil)]
        if let onMirror {
            let action = CPListItem(
                text: mirrorActionTitle,
                detailText: "Parked only · starts after Start Broadcast on iPhone",
                image: UIImage(systemName: "iphone")
            )
            action.handler = { _, completion in
                onMirror()
                completion()
            }
            sections.append(CPListSection(items: [action], header: "Mirror", sectionIndexTitle: nil))
        }
        let template = CPListTemplate(title: "Mirror iPhone", sections: sections)
        template.tabTitle = "Cast"
        template.tabImage = UIImage(systemName: "rectangle.on.rectangle")
        return template
    }

    static let mirrorActionTitle = "Show iPhone screen"

    /// Original copy; also used by the unit tests.
    static let mirrorInstructionSteps: [(title: String, detail: String)] = [
        ("Open DashCast on your iPhone", "Go to Cast → Car Display."),
        ("Turn on “Mirror to CarPlay screen”", "Then tap the broadcast button and choose Start Broadcast."),
        ("Parked only", "Mirroring stops automatically as soon as the vehicle moves.")
    ]

    // MARK: - Playback

    /// "Show iPhone screen": parked-only checks live in `CarPlayMirrorPlayback.decide`.
    private func startMirror() {
        switch CarPlayMirrorPlayback.start() {
        case .play:
            updateNowPlayingInfo(for: CarPlayMirrorPlayback.mirrorChannel, isPlaying: true)
            showNowPlaying()
        case .vehicleMoving, .mirrorDisabled, .notBroadcasting:
            // The instruction rows on this screen already say what to do on the iPhone.
            break
        }
    }

    private func play(_ channel: ChannelModel) {
        VideoPlayerService.shared.load(channel: channel)
        updateNowPlayingInfo(for: channel, isPlaying: VideoPlayerService.shared.isPlaying)
        refreshPlayingIndicators()
        showNowPlaying()
    }

    private func showNowPlaying() {
        guard let interfaceController else { return }
        let nowPlaying = CPNowPlayingTemplate.shared
        if interfaceController.topTemplate === nowPlaying { return }
        if interfaceController.templates.contains(where: { $0 === nowPlaying }) {
            interfaceController.pop(to: nowPlaying, animated: true, completion: nil)
        } else if canPush(onto: interfaceController) {
            interfaceController.pushTemplate(nowPlaying, animated: true, completion: nil)
        } else {
            // Stack is full: go back to the root and show Now Playing from there.
            interfaceController.popToRootTemplate(animated: false) { _, _ in
                interfaceController.pushTemplate(nowPlaying, animated: true, completion: nil)
            }
        }
    }

    /// Keeps Now Playing info and row indicators in sync when playback is changed
    /// from the iPhone UI (or anywhere else), not just from CarPlay.
    private func observePlayer() {
        let service = VideoPlayerService.shared
        playerCancellable = service.$currentChannel
            .combineLatest(service.$isPlaying)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] channel, isPlaying in
                MainActor.assumeIsolated {
                    self?.updateNowPlayingInfo(for: channel, isPlaying: isPlaying)
                    self?.refreshPlayingIndicators()
                }
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

        // `VideoPlayerService.shared` already owns the play/pause/toggle targets for the whole
        // process. Adding a second set here made every toggle (steering wheel, AirPods) run twice
        // while CarPlay was connected, so it flipped back and nothing happened (Review 2026-11-05).
        // Only make sure the commands are enabled; Now Playing follows `observePlayer()`.
        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand] {
            command.isEnabled = true
        }
    }

    private func removeRemoteCommands() {
        for (command, token) in remoteCommandTargets {
            command.removeTarget(token)
        }
        remoteCommandTargets.removeAll()
    }
}
