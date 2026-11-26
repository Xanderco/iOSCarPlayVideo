import SwiftUI

/// Localized copy and VoiceOver formatting helpers for `ChannelRow` and `LiveBadge`.
public enum ChannelRowCopy {
    nonisolated public static let liveString = "Live"
    nonisolated public static let nowPlayingString = "Now playing"
    nonisolated public static let favoriteString = "Favorite"
    nonisolated public static let percentWatchedFormatString = "%d percent watched"
    nonisolated public static let unavailableString = "Unavailable"
    nonisolated public static let removeFromFavoritesString = "Remove from Favorites"
    nonisolated public static let addToFavoritesString = "Add to Favorites"
    nonisolated public static let liveBadgeString = "LIVE"

    nonisolated public static let allLocalizationKeys: [String] = [
        liveString,
        nowPlayingString,
        favoriteString,
        percentWatchedFormatString,
        unavailableString,
        removeFromFavoritesString,
        addToFavoritesString,
        liveBadgeString
    ]

    @MainActor public static var liveBadgeKey: LocalizedStringKey {
        LocalizedStringKey(liveBadgeString)
    }

    @MainActor public static func favoriteActionKey(isFavorite: Bool) -> LocalizedStringKey {
        LocalizedStringKey(isFavorite ? removeFromFavoritesString : addToFavoritesString)
    }

    nonisolated public static func accessibilityLabel(
        title: String,
        subtitle: String?,
        isLive: Bool,
        bundle: Bundle = .main
    ) -> String {
        let liveText = isLive ? bundle.localizedString(forKey: liveString, value: liveString, table: nil) : nil
        let trimmedSubtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let validSubtitle = (trimmedSubtitle?.isEmpty == false) ? trimmedSubtitle : nil
        return [title, liveText, validSubtitle].compactMap { $0 }.joined(separator: ", ")
    }

    nonisolated public static func accessibilityValue(
        isPlaying: Bool,
        isFavorite: Bool,
        progress: Double?,
        isUnavailable: Bool,
        bundle: Bundle = .main
    ) -> String {
        var parts: [String] = []
        if isPlaying {
            parts.append(bundle.localizedString(forKey: nowPlayingString, value: nowPlayingString, table: nil))
        }
        if isFavorite {
            parts.append(bundle.localizedString(forKey: favoriteString, value: favoriteString, table: nil))
        }
        if let progress {
            let clamped = min(max(progress.isFinite ? progress : 0, 0), 1)
            let percent = Int((clamped * 100).rounded())
            let format = bundle.localizedString(forKey: percentWatchedFormatString, value: percentWatchedFormatString, table: nil)
            parts.append(String(format: format, percent))
        }
        if isUnavailable {
            parts.append(bundle.localizedString(forKey: unavailableString, value: unavailableString, table: nil))
        }
        return parts.joined(separator: ", ")
    }
}

/// Rounded channel / item logo with async loading and a monogram fallback.
public struct ChannelLogo: View {
    private let url: URL?
    private let name: String
    private let size: CGFloat

    public init(url: URL?, name: String, size: CGFloat = DSLayout.channelLogo) {
        self.url = url
        self.name = name
        self.size = size
    }

    private var monogram: String {
        let words = name.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map { String($0) }.joined()
        return letters.isEmpty ? "#" : letters.uppercased()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
        ZStack {
            shape.fill(Color.dcSurfaceRaised)
            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: DSMotion.quick)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit().padding(size * 0.12)
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.dcStroke, lineWidth: DSStroke.hairline))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Text(monogram)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(Color.dcTextSecondary)
            .minimumScaleFactor(0.5)
    }
}

/// A list row for a channel, episode, local video or web bookmark.
///
/// Presentational only: wrap it in a `Button`/`NavigationLink` to make the
/// whole row tappable. The favorite star is a separate borderless button so it
/// works inside `List` rows, and is also exposed as a VoiceOver action.
public struct ChannelRow: View {
    private let title: String
    private let subtitle: String?
    private let logoURL: URL?
    private let isLive: Bool
    private let isPlaying: Bool
    private let isFavorite: Bool
    private let progress: Double?
    private let isUnavailable: Bool
    private let onToggleFavorite: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var logoSize = DSLayout.channelLogo

    public init(
        title: String,
        subtitle: String? = nil,
        logoURL: URL? = nil,
        isLive: Bool = false,
        isPlaying: Bool = false,
        isFavorite: Bool = false,
        progress: Double? = nil,
        isUnavailable: Bool = false,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.logoURL = logoURL
        self.isLive = isLive
        self.isPlaying = isPlaying
        self.isFavorite = isFavorite
        self.progress = progress
        self.isUnavailable = isUnavailable
        self.onToggleFavorite = onToggleFavorite
    }

    /// Convenience for IPTV channels.
    public init(
        channel: ChannelModel,
        isLive: Bool = true,
        isPlaying: Bool = false,
        isFavorite: Bool? = nil,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.init(
            title: channel.name,
            subtitle: channel.groupTitle,
            logoURL: channel.logoURL,
            isLive: isLive,
            isPlaying: isPlaying,
            isFavorite: isFavorite ?? channel.isFavorite,
            onToggleFavorite: onToggleFavorite
        )
    }

    public var body: some View {
        HStack(spacing: DSSpacing.md) {
            ChannelLogo(url: logoURL, name: title, size: logoSize)
                .overlay(alignment: .bottomTrailing) {
                    if isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.dcOnAccent)
                            .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                            .padding(3)
                            .background(Color.dcAccent, in: Circle())
                            .offset(x: 4, y: 4)
                    }
                }

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                HStack(spacing: DSSpacing.xs) {
                    Text(title)
                        .font(DSTypography.headline)
                        .foregroundStyle(isPlaying ? Color.dcAccent : Color.dcTextPrimary)
                        .lineLimit(2)
                    if isLive { LiveBadge() }
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DSTypography.subheadline)
                        .foregroundStyle(Color.dcTextSecondary)
                        .lineLimit(1)
                }
                if let progress {
                    ProgressView(value: min(max(progress, 0), 1))
                        .tint(Color.dcAccent)
                        .padding(.top, DSSpacing.xxs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isFavorite ? Color.dcAccent : Color.dcTextTertiary)
                        .frame(width: DSLayout.minTapTarget, height: DSLayout.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityHidden(true)
            }
        }
        .padding(.vertical, DSSpacing.sm)
        .frame(minHeight: DSLayout.minTapTarget)
        .opacity(isUnavailable ? 0.45 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityLabelText))
        .accessibilityValue(Text(verbatim: accessibilityValueText))
        .accessibilityAddTraits(isPlaying ? .isSelected : [])
        .accessibilityActions {
            if let onToggleFavorite {
                Button(ChannelRowCopy.favoriteActionKey(isFavorite: isFavorite), action: onToggleFavorite)
            }
        }
    }

    private var accessibilityLabelText: String {
        ChannelRowCopy.accessibilityLabel(title: title, subtitle: subtitle, isLive: isLive)
    }

    private var accessibilityValueText: String {
        ChannelRowCopy.accessibilityValue(
            isPlaying: isPlaying,
            isFavorite: isFavorite,
            progress: progress,
            isUnavailable: isUnavailable
        )
    }
}

/// Small red "LIVE" capsule.
public struct LiveBadge: View {
    public init() {}

    public var body: some View {
        Text(ChannelRowCopy.liveBadgeKey)
            .font(DSTypography.badge)
            .tracking(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.dcLive, in: RoundedRectangle(cornerRadius: DSRadius.xs, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview("ChannelRow") {
    List {
        ChannelRow(title: "Metro News 24", subtitle: "News", isLive: true, isPlaying: true, isFavorite: true, onToggleFavorite: {})
        ChannelRow(title: "Coastal Weather", subtitle: "Weather", isLive: true, onToggleFavorite: {})
        ChannelRow(title: "Road Trip Vlog — Episode 3", subtitle: "S1 · E3 · 42 min", progress: 0.62)
        ChannelRow(title: "Offline Channel", subtitle: "Sports", isLive: true, isUnavailable: true)
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color.dcBackground)
    .preferredColorScheme(.dark)
}

#Preview("ChannelRow · Light · XXXL") {
    List {
        ChannelRow(title: "Metro News 24", subtitle: "News", isLive: true, isFavorite: true, onToggleFavorite: {})
        ChannelRow(title: "Road Trip Vlog", subtitle: "Local video", progress: 0.3)
    }
    .preferredColorScheme(.light)
    .dynamicTypeSize(.accessibility2)
}
