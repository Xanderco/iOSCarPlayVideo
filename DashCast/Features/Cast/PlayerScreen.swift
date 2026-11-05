import SwiftUI

/// Full-screen player. Portrait: video on top, details and the rest of the group below.
/// Landscape: edge-to-edge video. Pull down (or tap the chevron) to collapse into the
/// mini player; playback keeps going.
public struct PlayerScreen: View {
    @ObservedObject private var player = VideoPlayerService.shared
    @ObservedObject private var presentation = PlayerPresentation.shared
    @ObservedObject private var playlistStore = PlaylistStore.shared
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var isFullscreen = false
    @State private var dragOffset: CGFloat = 0

    public init() {}

    private var isLandscape: Bool { verticalSizeClass == .compact }
    private var siblings: [ChannelModel] { PlaybackQueue.siblings(of: player.currentChannel) }
    private var canStep: Bool { siblings.count > 1 }

    public var body: some View {
        ZStack {
            Color.dcVideoChrome.ignoresSafeArea()

            if isLandscape || isFullscreen {
                videoSurface
                    .ignoresSafeArea()
                    .overlay(alignment: .topLeading) { collapseButton.padding(DSSpacing.sm) }
            } else {
                portraitLayout
            }
        }
        .offset(y: dragOffset)
        .environment(\.colorScheme, .dark)
        .statusBarHidden(isLandscape || isFullscreen)
        .onChange(of: player.currentChannel) { _, channel in
            if channel == nil { presentation.isExpanded = false }
        }
        .accessibilityIdentifier("Player_Screen")
    }

    private var videoSurface: some View {
        AutomotiveVideoPlayerView(
            isFullscreen: $isFullscreen,
            showsFullscreenToggle: !isLandscape,
            onPrevious: canStep ? { presentation.step(-1) } : nil,
            onNext: canStep ? { presentation.step(1) } : nil
        )
    }

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            header
            videoSurface
                .aspectRatio(16 / 9, contentMode: .fit)
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xl) {
                    details
                    actions
                    upNext
                }
                .padding(.vertical, DSSpacing.lg)
            }
        }
        .background(Color.dcBackground.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            collapseButton
            Spacer()
            Capsule()
                .fill(Color.dcTextTertiary)
                .frame(width: 36, height: 5)
                .accessibilityHidden(true)
            Spacer()
            AirPlayRoutePickerRepresentable(tintColor: .white)
                .frame(width: DSLayout.minTapTarget, height: DSLayout.minTapTarget)
                .accessibilityLabel(Text("Play on another screen"))
        }
        .padding(.horizontal, DSSpacing.sm)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in dragOffset = max(0, value.translation.height) }
                .onEnded { value in
                    if value.translation.height > 120 {
                        presentation.isExpanded = false
                    }
                    dragOffset = 0
                }
        )
    }

    private var collapseButton: some View {
        Button {
            if isFullscreen && !isLandscape {
                isFullscreen = false
            } else {
                presentation.isExpanded = false
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: DSLayout.minTapTarget, height: DSLayout.minTapTarget)
                .background(Color.dcScrim, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Minimize player"))
        .accessibilityIdentifier("Player_Collapse")
    }

    @ViewBuilder
    private var details: some View {
        if let channel = player.currentChannel {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(spacing: DSSpacing.sm) {
                    Text(channel.name)
                        .font(DSTypography.title2)
                        .foregroundStyle(Color.dcTextPrimary)
                        .lineLimit(2)
                    if player.duration <= 0 { LiveBadge() }
                }
                Text(channel.groupTitle)
                    .font(DSTypography.subheadline)
                    .foregroundStyle(Color.dcTextSecondary)
            }
            .padding(.horizontal, DSSpacing.screenGutter)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if let channel = player.currentChannel {
            let isFavorite = playlistStore.isFavorite(channel)
            HStack(spacing: DSSpacing.sm) {
                PrimaryButton(isFavorite ? "Saved" : "Save", systemImage: isFavorite ? "star.fill" : "star",
                              kind: .secondary, size: .compact) {
                    playlistStore.toggleFavorite(channel)
                }
                .accessibilityLabel(Text(isFavorite ? "Remove from Favorites" : "Add to Favorites"))
                PrimaryButton("Car Mode", systemImage: "car.fill", kind: .secondary, size: .compact) {
                    presentation.openCarMode()
                }
                .accessibilityIdentifier("Player_CarMode")
                PrimaryButton("Stop", systemImage: "stop.fill", kind: .tertiary, size: .compact) {
                    player.stop()
                }
            }
            .padding(.horizontal, DSSpacing.screenGutter)
        }
    }

    @ViewBuilder
    private var upNext: some View {
        if canStep, let current = player.currentChannel {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                SectionHeader("Up Next", subtitle: current.groupTitle)
                LazyVStack(spacing: 0) {
                    ForEach(siblings.prefix(50)) { channel in
                        Button {
                            WatchHistoryStore.shared.play(channel)
                        } label: {
                            ChannelRow(
                                channel: channel,
                                isLive: WatchHistoryStore.shared.looksLive(channel),
                                isPlaying: channel.streamURL == current.streamURL,
                                isFavorite: playlistStore.isFavorite(channel),
                                onToggleFavorite: { playlistStore.toggleFavorite(channel) }
                            )
                            .padding(.horizontal, DSSpacing.screenGutter)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.dcSeparator).padding(.leading, DSSpacing.screenGutter + DSLayout.channelLogo + DSSpacing.md)
                    }
                }
            }
        }
    }
}
