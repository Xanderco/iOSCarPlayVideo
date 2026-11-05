import SwiftUI

/// Docks the design-system `MiniPlayerBar` above the tab bar whenever something is
/// playing, and owns the full-screen player and Car Mode presentations so playback
/// survives switching tabs and closing sheets.
public struct MiniPlayerHost: View {
    @ObservedObject private var player = VideoPlayerService.shared
    @ObservedObject private var presentation = PlayerPresentation.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    private var isVisible: Bool {
        player.currentChannel != nil && !presentation.isExpanded && !presentation.isCarModeActive
    }

    public var body: some View {
        VStack(spacing: 0) {
            if isVisible, let channel = player.currentChannel {
                MiniPlayerBar(
                    title: channel.name,
                    subtitle: player.playbackError != nil ? "Couldn't play — tap for options" : channel.groupTitle,
                    artworkURL: channel.logoURL,
                    isPlaying: player.isPlaying,
                    isLive: player.duration <= 0 && player.playbackError == nil,
                    isBuffering: player.isBuffering && player.playbackError == nil,
                    progress: player.duration > 0 ? player.currentTime / player.duration : nil,
                    onExpand: { presentation.isExpanded = true },
                    onPlayPause: { player.togglePlayPause() },
                    onClose: { player.stop() }
                )
                .padding(.bottom, DSSpacing.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityIdentifier("MiniPlayer")
            }
        }
        .animation(DSMotion.animation(DSMotion.standard, reduceMotion: reduceMotion), value: isVisible)
        .onAppear { WatchHistoryStore.shared.startObserving(player) }
        .fullScreenCover(isPresented: $presentation.isExpanded) {
            PlayerScreen()
        }
        .background {
            // A second presenter so Car Mode can open on top of (or instead of) the player.
            Color.clear
                .fullScreenCover(isPresented: $presentation.isCarModeActive) {
                    CarModeView()
                }
        }
    }
}
