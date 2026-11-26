import CarPlay
import UIKit

public enum CarPlayDashboardShortcutAction: Equatable {
    case togglePlayPause
    case playChannel(ChannelModel)
    case none
}

public struct CarPlayDashboardShortcutSpec: Equatable {
    public let titleVariants: [String]
    public let subtitleVariants: [String]
    public let systemImageName: String
    public let action: CarPlayDashboardShortcutAction

    public init(
        titleVariants: [String],
        subtitleVariants: [String],
        systemImageName: String,
        action: CarPlayDashboardShortcutAction
    ) {
        self.titleVariants = titleVariants
        self.subtitleVariants = subtitleVariants
        self.systemImageName = systemImageName
        self.action = action
    }
}

public enum CarPlayDashboardShortcutProvider {
    public static let maxShortcutCount = 2

    public static func buildShortcuts(
        currentChannel: ChannelModel?,
        isPlaying: Bool,
        favoriteChannels: [ChannelModel],
        allChannels: [ChannelModel]
    ) -> [CarPlayDashboardShortcutSpec] {
        let favoriteURLs = Set(favoriteChannels.map(\.streamURL))
        let candidates = deduplicatedCandidates(
            favorites: favoriteChannels,
            allChannels: allChannels,
            excluding: currentChannel?.streamURL
        )

        if let active = currentChannel {
            let toggleSpec = CarPlayDashboardShortcutSpec(
                titleVariants: isPlaying
                    ? [String(localized: "Pause"), String(localized: "Pause")]
                    : [String(localized: "Resume"), String(localized: "Play")],
                subtitleVariants: [
                    active.name,
                    isPlaying ? String(localized: "Playing") : String(localized: "Paused")
                ],
                systemImageName: isPlaying ? "pause.circle.fill" : "play.circle.fill",
                action: .togglePlayPause
            )

            var specs = [toggleSpec]
            if let nextChannel = candidates.first {
                specs.append(
                    quickPlaySpec(
                        for: nextChannel,
                        isFavorite: favoriteURLs.contains(nextChannel.streamURL),
                        isPrimaryIdleSlot: false
                    )
                )
            }
            return Array(specs.prefix(maxShortcutCount))
        }

        if !candidates.isEmpty {
            let specs = candidates.prefix(maxShortcutCount).enumerated().map { index, channel in
                quickPlaySpec(
                    for: channel,
                    isFavorite: favoriteURLs.contains(channel.streamURL),
                    isPrimaryIdleSlot: index == 0
                )
            }
            return Array(specs)
        }

        return [
            CarPlayDashboardShortcutSpec(
                titleVariants: ["DashCast", "Cast"],
                subtitleVariants: [String(localized: "No channels yet"), String(localized: "DashCast")],
                systemImageName: "car.fill",
                action: .none
            )
        ]
    }

    @MainActor
    public static func makeButtons(
        from specs: [CarPlayDashboardShortcutSpec],
        onAction: @escaping @MainActor (CarPlayDashboardShortcutAction) -> Void
    ) -> [CPDashboardButton] {
        specs.prefix(maxShortcutCount).map { spec in
            CPDashboardButton(
                titleVariants: spec.titleVariants,
                subtitleVariants: spec.subtitleVariants,
                image: UIImage(systemName: spec.systemImageName) ?? UIImage()
            ) { _ in
                MainActor.assumeIsolated {
                    onAction(spec.action)
                }
            }
        }
    }

    @MainActor
    public static func perform(_ action: CarPlayDashboardShortcutAction, on player: VideoPlayerService) {
        switch action {
        case .togglePlayPause:
            player.togglePlayPause()
        case .playChannel(let channel):
            player.load(channel: channel)
        case .none:
            break
        }
    }

    private static func quickPlaySpec(
        for channel: ChannelModel,
        isFavorite: Bool,
        isPrimaryIdleSlot: Bool
    ) -> CarPlayDashboardShortcutSpec {
        let primarySubtitle: String
        if isPrimaryIdleSlot {
            primarySubtitle = isFavorite
                ? String(localized: "Quick Resume · Favorite")
                : String(localized: "Quick Resume")
        } else if !channel.groupTitle.isEmpty {
            primarySubtitle = channel.groupTitle
        } else {
            primarySubtitle = isFavorite ? String(localized: "Favorite") : String(localized: "Quick Play")
        }

        return CarPlayDashboardShortcutSpec(
            titleVariants: [channel.name, String(localized: "Play")],
            subtitleVariants: [primarySubtitle, String(localized: "Play")],
            systemImageName: isFavorite ? "heart.circle.fill" : "play.tv.fill",
            action: .playChannel(channel)
        )
    }

    private static func deduplicatedCandidates(
        favorites: [ChannelModel],
        allChannels: [ChannelModel],
        excluding excludedURL: URL?
    ) -> [ChannelModel] {
        var seen = Set<URL>()
        if let excludedURL {
            seen.insert(excludedURL)
        }

        var result: [ChannelModel] = []
        for channel in favorites + allChannels {
            if seen.insert(channel.streamURL).inserted {
                result.append(channel)
            }
        }
        return result
    }
}
