import Foundation

/// Scope selection for filtering channels in Media Sources.
public enum PlaylistChannelFilterScope: Hashable, Sendable {
    case all
    case favorites
    case group(String)
}

/// Pure, testable filter specification for M3U/IPTV channel lists.
public struct PlaylistChannelFilter: Equatable, Sendable {
    public var query: String
    public var scope: PlaylistChannelFilterScope

    public init(query: String = "", scope: PlaylistChannelFilterScope = .all) {
        self.query = query
        self.scope = scope
    }

    /// Trimmed search string used for matching channel names and group titles.
    public var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether either a search query or non-default scope filter is active.
    public var isActive: Bool {
        !trimmedQuery.isEmpty || scope != .all
    }

    /// Filters `channels` by scope (All, Favorites, or specific group) and case-insensitive substring match
    /// across `name` and `groupTitle`.
    public func apply(
        to channels: [ChannelModel],
        isFavorite: (ChannelModel) -> Bool
    ) -> [ChannelModel] {
        let needle = trimmedQuery
        return channels.filter { channel in
            switch scope {
            case .all:
                break
            case .favorites:
                guard isFavorite(channel) else { return false }
            case .group(let groupTitle):
                guard channel.groupTitle == groupTitle else { return false }
            }

            guard !needle.isEmpty else { return true }
            return channel.name.localizedCaseInsensitiveContains(needle)
                || channel.groupTitle.localizedCaseInsensitiveContains(needle)
        }
    }

    /// Distinct non-empty group titles in first-seen order.
    public static func availableGroups(from channels: [ChannelModel]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for channel in channels {
            let group = channel.groupTitle
            guard !group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if seen.insert(group).inserted {
                ordered.append(group)
            }
        }
        return ordered
    }
}
