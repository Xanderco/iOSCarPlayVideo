import SwiftUI

/// Localized copy keys for `MiniPlayerBar`.
public enum MiniPlayerCopy {
    nonisolated public static let nowPlayingFormatString = "Now playing: %@"
    nonisolated public static let opensFullPlayerHintString = "Opens the full player"
    nonisolated public static let pauseString = "Pause"
    nonisolated public static let playString = "Play"
    nonisolated public static let stopPlaybackString = "Stop playback"
    nonisolated public static let miniPlayerString = "Mini player"

    nonisolated public static let allLocalizationKeys: [String] = [
        nowPlayingFormatString,
        opensFullPlayerHintString,
        pauseString,
        playString,
        stopPlaybackString,
        miniPlayerString
    ]

    @MainActor
    public static func nowPlayingKey(title: String) -> LocalizedStringKey {
        LocalizedStringKey("Now playing: \(title)")
    }

    @MainActor
    public static var opensFullPlayerHintKey: LocalizedStringKey {
        LocalizedStringKey(opensFullPlayerHintString)
    }

    @MainActor
    public static func playPauseKey(isPlaying: Bool) -> LocalizedStringKey {
        LocalizedStringKey(isPlaying ? pauseString : playString)
    }

    @MainActor
    public static var stopPlaybackKey: LocalizedStringKey {
        LocalizedStringKey(stopPlaybackString)
    }

    @MainActor
    public static var miniPlayerKey: LocalizedStringKey {
        LocalizedStringKey(miniPlayerString)
    }
}

/// Floating "now playing" bar shown above the tab bar while playback continues
/// in the background of browsing. Tapping the bar expands to the full player.
///
/// Presentational only; the owner (phase 2: `VideoPlayerService`) supplies state
/// and callbacks.
public struct MiniPlayerBar: View {
    private let title: String
    private let subtitle: String?
    private let artworkURL: URL?
    private let isPlaying: Bool
    private let isLive: Bool
    private let isBuffering: Bool
    private let progress: Double?
    private let onExpand: () -> Void
    private let onPlayPause: () -> Void
    private let onClose: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .headline) private var artworkSize: CGFloat = 44

    public init(
        title: String,
        subtitle: String? = nil,
        artworkURL: URL? = nil,
        isPlaying: Bool,
        isLive: Bool = false,
        isBuffering: Bool = false,
        progress: Double? = nil,
        onExpand: @escaping () -> Void,
        onPlayPause: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.isPlaying = isPlaying
        self.isLive = isLive
        self.isBuffering = isBuffering
        self.progress = progress
        self.onExpand = onExpand
        self.onPlayPause = onPlayPause
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: DSSpacing.md) {
            Button(action: onExpand) {
                HStack(spacing: DSSpacing.md) {
                    ChannelLogo(url: artworkURL, name: title, size: artworkSize)
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        HStack(spacing: DSSpacing.xs) {
                            Text(title)
                                .font(DSTypography.headline)
                                .foregroundStyle(Color.dcTextPrimary)
                                .lineLimit(1)
                            if isLive { LiveBadge() }
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(DSTypography.footnote)
                                .foregroundStyle(Color.dcTextSecondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(MiniPlayerCopy.nowPlayingKey(title: title)))
            .accessibilityValue(Text(subtitle ?? ""))
            .accessibilityHint(Text(MiniPlayerCopy.opensFullPlayerHintKey))

            Button(action: onPlayPause) {
                ZStack {
                    if isBuffering {
                        ProgressView().tint(Color.dcTextPrimary)
                    } else {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.dcTextPrimary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: DSLayout.minTapTarget, height: DSLayout.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(MiniPlayerCopy.playPauseKey(isPlaying: isPlaying)))

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.dcTextSecondary)
                        .frame(width: DSLayout.minTapTarget, height: DSLayout.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(MiniPlayerCopy.stopPlaybackKey))
            }
        }
        .padding(.leading, DSSpacing.sm)
        .padding(.trailing, DSSpacing.xs)
        .padding(.vertical, DSSpacing.sm)
        .frame(minHeight: DSLayout.miniPlayerHeight)
        .overlay(alignment: .bottom) { progressTrack }
        .dsMaterialBackground(.chrome, radius: DSRadius.lg)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        .dsShadow(.floating)
        .padding(.horizontal, DSSpacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(MiniPlayerCopy.miniPlayerKey))
    }

    @ViewBuilder
    private var progressTrack: some View {
        if let progress, !isLive {
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.dcAccent)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1), height: 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 2)
            .padding(.horizontal, DSRadius.lg / 2)
            .accessibilityHidden(true)
        }
    }
}

#Preview("MiniPlayerBar") {
    ZStack(alignment: .bottom) {
        Color.dcBackground.ignoresSafeArea()
        ScrollView {
            VStack(spacing: DSSpacing.sm) {
                ForEach(0..<12) { i in
                    ChannelRow(title: "Channel \(i + 1)", subtitle: "Entertainment", isLive: true)
                        .padding(.horizontal, DSSpacing.screenGutter)
                }
            }
        }
        VStack(spacing: DSSpacing.sm) {
            MiniPlayerBar(title: "Metro News 24", subtitle: "Family TV · News", isPlaying: true, isLive: true,
                          onExpand: {}, onPlayPause: {}, onClose: {})
            MiniPlayerBar(title: "Road Trip Vlog — Episode 3", subtitle: "Home Server", isPlaying: false,
                          progress: 0.4, onExpand: {}, onPlayPause: {})
            MiniPlayerBar(title: "Loading stream…", isPlaying: true, isBuffering: true,
                          onExpand: {}, onPlayPause: {}, onClose: {})
        }
    }
    .preferredColorScheme(.dark)
}
