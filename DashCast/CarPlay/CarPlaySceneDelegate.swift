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
    /// Caps the Quick-Resume section so category folders stay visible on smaller CarPlay lists.
    private static let maxRecentLibraryItems = 5

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
        let tabs: [CPTemplate] = [library, favorites, Self.infoTemplate(), Self.mirrorInstructionsTemplate { [weak self] in
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

    /// Library root: optional Recent Quick-Resume section at the top, followed by group folders.
    func makeLibrarySections(store: PlaylistStore) -> [CPListSection] {
        let maxSections = Int(CPListTemplate.maximumSectionCount)
        var remaining = Int(CPListTemplate.maximumItemCount)
        let groups = store.groupedChannels(store.allChannels)
        var sections: [CPListSection] = []

        // Reserve at least one slot for category folders when groups exist so Recent never crowds them out.
        let recentCap = groups.isEmpty ? Self.maxRecentLibraryItems : min(Self.maxRecentLibraryItems, max(0, remaining - 1))
        let recent = Array(store.recentChannels.prefix(recentCap))
        if !recent.isEmpty && remaining > 0 && sections.count < maxSections {
            let recentItems = recent.map { makeChannelItem($0, showGroup: true) }
            remaining -= recentItems.count
            sections.append(CPListSection(
                items: recentItems,
                header: String(localized: "Recent"),
                sectionIndexTitle: nil
            ))
        }

        if !groups.isEmpty && remaining > 0 && sections.count < maxSections {
            let groupItems: [CPListItem] = groups.prefix(remaining).map { entry in
                let group = entry.group
                let channels = entry.channels
                let item = CPListItem(
                    text: group.isEmpty ? String(localized: "Other") : group,
                    detailText: channels.count == 1 ? String(localized: "1 channel") : String(localized: "\(channels.count) channels"),
                    image: UIImage(systemName: "folder.fill")
                )
                item.accessoryType = .disclosureIndicator
                item.handler = { [weak self] _, completion in
                    self?.pushGroup(group, title: group.isEmpty ? String(localized: "Other") : group, channels: channels)
                    completion()
                }
                return item
            }
            sections.append(CPListSection(
                items: groupItems,
                header: recent.isEmpty ? nil : String(localized: "Categories"),
                sectionIndexTitle: nil
            ))
        }

        return sections
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
                                          header: entry.group.isEmpty ? String(localized: "Other") : entry.group,
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
        template.emptyViewTitleVariants = [String(localized: "No channels")]
        interfaceController.pushTemplate(template, animated: true, completion: nil)
    }

    private func canPush(onto interfaceController: CPInterfaceController) -> Bool {
        interfaceController.templates.count < Self.maximumTemplateDepth
    }

    // MARK: - Tab templates (static so unit tests can build them without a car)

    static func infoTemplate() -> CPListTemplate {
        let items = [
            CPListItem(text: String(localized: "Your channels, on the big screen"),
                       detailText: String(localized: "Set up playlists and media sources while parked")),
            CPListItem(text: String(localized: "Audio while driving"),
                       detailText: String(localized: "Video is only shown when parked, via AirPlay"))
        ]
        for item in items {
            item.handler = { _, completion in completion() }
        }
        let template = CPListTemplate(title: "DashCast", sections: [CPListSection(items: items)])
        template.tabTitle = String(localized: "Info")
        template.tabImage = UIImage(systemName: "info.circle.fill")
        return template
    }

    static func libraryTemplate() -> CPListTemplate {
        let library = CPListTemplate(title: String(localized: "Library"), sections: [])
        library.tabTitle = String(localized: "Library")
        library.tabImage = UIImage(systemName: "tv.fill")
        library.emptyViewTitleVariants = [String(localized: "No channels")]
        library.emptyViewSubtitleVariants = [String(localized: "Add a playlist while parked to see channels here")]
        return library
    }

    static func favoritesTemplate() -> CPListTemplate {
        let favorites = CPListTemplate(title: String(localized: "Favorites"), sections: [])
        favorites.tabTitle = String(localized: "Favorites")
        favorites.tabImage = UIImage(systemName: "heart.fill")
        favorites.emptyViewTitleVariants = [String(localized: "No Favorites Yet")]
        favorites.emptyViewSubtitleVariants = [String(localized: "Star favorite channels while parked for quick access here")]
        return favorites
    }

    /// Car-screen instructions for mirroring while parked (the "Cast" tab). A list, because
    /// CPInformationTemplate is not allowed for CarPlay Audio apps.
    /// With `onMirror`, a second section adds the mirror action, which plays the
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
        var sections = [CPListSection(
            items: steps,
            header: String(localized: "Parked screen mirroring"),
            sectionIndexTitle: nil
        )]
        if let onMirror {
            let action = CPListItem(
                text: mirrorActionTitle,
                detailText: String(localized: "Parked only · plays once broadcast is active"),
                image: UIImage(systemName: "play.rectangle.on.rectangle")
            )
            action.handler = { _, completion in
                onMirror()
                completion()
            }
            sections.append(CPListSection(items: [action], header: String(localized: "Mirror"), sectionIndexTitle: nil))
        }
        let template = CPListTemplate(title: String(localized: "Screen Mirror"), sections: sections)
        template.tabTitle = String(localized: "Cast")
        template.tabImage = UIImage(systemName: "rectangle.on.rectangle")
        return template
    }

    static let mirrorActionTitle = String(localized: "Show mirrored screen")

    /// Car-safe parked/setup copy complying with CarPlay Guideline 2; also checked by unit tests.
    static let mirrorInstructionSteps: [(title: String, detail: String)] = [
        (
            String(localized: "Parked setup required"),
            String(localized: "Enable Car Display mirroring in DashCast settings while parked.")
        ),
        (
            String(localized: "Start screen broadcast"),
            String(localized: "Begin the broadcast while parked before selecting Show Mirrored Screen below.")
        ),
        (
            String(localized: "Parked only"),
            String(localized: "Mirroring stops automatically as soon as the vehicle moves.")
        )
    ]

    // MARK: - Playback

    /// Plays the active mirror broadcast when parked; checks live in `CarPlayMirrorPlayback.decide`.
    private func startMirror() {
        switch CarPlayMirrorPlayback.start() {
        case .play:
            updateNowPlayingInfo(for: CarPlayMirrorPlayback.mirrorChannel, isPlaying: true)
            showNowPlaying()
        case .vehicleMoving, .mirrorDisabled, .notBroadcasting:
            // The instruction rows on this screen already describe parked-only mirror setup.
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
