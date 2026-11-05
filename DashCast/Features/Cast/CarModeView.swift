import SwiftUI
import UIKit

/// Landscape, glanceable playback screen for use in the car (passengers / parked).
///
/// Left: the video. Right: a dark panel with the clock, what's on, oversized
/// previous / play-pause / next buttons and the channels of the current group as
/// 72 pt rows. No text entry and no navigation deeper than this one screen.
public struct CarModeView: View {
    @ObservedObject private var player = VideoPlayerService.shared
    @ObservedObject private var presentation = PlayerPresentation.shared
    @ObservedObject private var playlistStore = PlaylistStore.shared
    @ObservedObject private var history = WatchHistoryStore.shared

    public init() {}

    /// What the right-hand list offers: the current group, else favorites, else recents, else samples.
    private var channelList: [ChannelModel] {
        if player.currentChannel != nil {
            return PlaybackQueue.siblings(of: player.currentChannel)
        }
        if !playlistStore.favoriteChannels.isEmpty { return playlistStore.favoriteChannels }
        let recents = history.recents.map(\.channel)
        if !recents.isEmpty { return recents }
        return playlistStore.allChannels
    }

    private var listTitle: String {
        if let channel = player.currentChannel { return channel.groupTitle }
        if !playlistStore.favoriteChannels.isEmpty { return "Favorites" }
        if !history.recents.isEmpty { return "Recently Watched" }
        return "Channels"
    }

    public var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            ZStack {
                Color.dcVideoChrome.ignoresSafeArea()
                if landscape {
                    HStack(spacing: 0) {
                        video
                            .frame(width: proxy.size.width * 0.6)
                        panel
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        video
                            .aspectRatio(16 / 9, contentMode: .fit)
                        panel
                    }
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .dsCarModeTypography()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .accessibilityIdentifier("CarMode_Screen")
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            OrientationRequest.request(.landscape)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            OrientationRequest.request(.portrait)
        }
    }

    // MARK: - Video

    private var video: some View {
        AutomotiveVideoPlayerView()
            .ignoresSafeArea(edges: [.top, .bottom, .leading])
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            HStack(alignment: .center) {
                TimelineView(.everyMinute) { context in
                    Text(context.date, style: .time)
                        .font(DSTypography.carTitle)
                        .monospacedDigit()
                        .foregroundStyle(Color.dcTextPrimary)
                }
                Spacer()
                Button {
                    presentation.isCarModeActive = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(.title2, weight: .bold))
                        .foregroundStyle(Color.dcTextPrimary)
                        .frame(width: DSLayout.carTapTarget, height: DSLayout.carTapTarget)
                        .background(Color.dcSurfaceRaised, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Exit Car Mode"))
                .accessibilityIdentifier("CarMode_Exit")
            }

            nowPlaying

            transport

            channelColumn

            Label("For passengers, or while parked", systemImage: "exclamationmark.shield")
                .font(DSTypography.footnote)
                .foregroundStyle(Color.dcTextTertiary)
        }
        .padding(DSSpacing.carGutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.dcBackgroundElevated.ignoresSafeArea())
    }

    @ViewBuilder
    private var nowPlaying: some View {
        if let channel = player.currentChannel {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(spacing: DSSpacing.sm) {
                    Text(channel.name)
                        .font(DSTypography.carHeadline)
                        .foregroundStyle(Color.dcTextPrimary)
                        .lineLimit(1)
                    if player.duration <= 0 { LiveBadge() }
                }
                Text(channel.groupTitle)
                    .font(DSTypography.carBody)
                    .foregroundStyle(Color.dcTextSecondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        } else {
            Text("Choose a channel")
                .font(DSTypography.carHeadline)
                .foregroundStyle(Color.dcTextSecondary)
        }
    }

    private var transport: some View {
        let canStep = channelList.count > 1 && player.currentChannel != nil
        return HStack(spacing: DSSpacing.md) {
            carButton("backward.end.fill", label: "Previous channel", kind: .secondary) {
                presentation.step(-1)
            }
            .disabled(!canStep)

            carButton(player.isPlaying ? "pause.fill" : "play.fill",
                      label: player.isPlaying ? "Pause" : "Play", kind: .primary) {
                if player.currentChannel == nil, let first = channelList.first {
                    WatchHistoryStore.shared.play(first)
                } else {
                    player.togglePlayPause()
                }
            }
            .accessibilityIdentifier("CarMode_PlayPause")

            carButton("forward.end.fill", label: "Next channel", kind: .secondary) {
                presentation.step(1)
            }
            .disabled(!canStep)
        }
    }

    private func carButton(_ systemImage: String, label: String, kind: PrimaryButton.Kind,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(.title, weight: .bold))
        }
        .buttonStyle(DSButtonStyle(kind: kind, size: .car))
        .accessibilityLabel(Text(label))
    }

    private var channelColumn: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(listTitle)
                .font(DSTypography.carBody)
                .foregroundStyle(Color.dcTextSecondary)
                .accessibilityAddTraits(.isHeader)
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: DSSpacing.xs) {
                        ForEach(channelList.prefix(100)) { channel in
                            carRow(channel).id(channel.streamURL)
                        }
                    }
                }
                .onAppear {
                    if let current = player.currentChannel { reader.scrollTo(current.streamURL, anchor: .center) }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func carRow(_ channel: ChannelModel) -> some View {
        let isCurrent = channel.streamURL == player.currentChannel?.streamURL
        return Button {
            WatchHistoryStore.shared.play(channel)
        } label: {
            HStack(spacing: DSSpacing.md) {
                ChannelLogo(url: channel.logoURL, name: channel.name, size: 52)
                Text(channel.name)
                    .font(DSTypography.carBody)
                    .foregroundStyle(isCurrent ? Color.dcAccent : Color.dcTextPrimary)
                    .lineLimit(1)
                Spacer(minLength: DSSpacing.sm)
                if isCurrent {
                    Image(systemName: "waveform")
                        .font(.system(.title3, weight: .bold))
                        .foregroundStyle(Color.dcAccent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .frame(minHeight: DSLayout.carTapTarget)
            .background(isCurrent ? Color.dcAccentSoft : Color.dcSurface,
                        in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(channel.name))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
