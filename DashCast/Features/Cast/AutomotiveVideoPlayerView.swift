import SwiftUI
import AVKit

/// The video surface used by the full player, Car Mode and anywhere video is shown inline.
///
/// Always dark (video chrome ignores the app appearance). Controls fade in on tap and
/// hide themselves after a few seconds of playback. Live streams get no scrubber or
/// skip buttons; on-demand videos get ±10 s and a scrubber.
public struct AutomotiveVideoPlayerView: View {
    @ObservedObject var playerService = VideoPlayerService.shared
    @ObservedObject var externalDisplay = ExternalDisplayManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showControls: Bool = true
    @State private var isSeeking: Bool = false
    @State private var seekSliderValue: Double = 0
    @State private var hideTask: Task<Void, Never>?
    @Binding var isFullscreen: Bool

    private let showsFullscreenToggle: Bool
    private let onPrevious: (() -> Void)?
    private let onNext: (() -> Void)?

    public init(
        isFullscreen: Binding<Bool> = .constant(false),
        showsFullscreenToggle: Bool = false,
        onPrevious: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil
    ) {
        self._isFullscreen = isFullscreen
        self.showsFullscreenToggle = showsFullscreenToggle
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    private var isLive: Bool { playerService.duration <= 0 }

    public var body: some View {
        ZStack {
            Color.dcVideoChrome

            if playerService.currentChannel != nil {
                CustomVideoPlayerRepresentable(player: playerService.isVideoLayerAttached ? playerService.player : nil)
                    .accessibilityHidden(true)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { toggleControls() }
                    .accessibilityHidden(true)

                if playerService.isBuffering && playerService.playbackError == nil {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                        .allowsHitTesting(false)
                        .accessibilityLabel(Text("Loading video"))
                }

                if let error = playerService.playbackError {
                    errorOverlay(error)
                } else if showControls {
                    controlsOverlay
                        .transition(.opacity)
                }
            } else {
                idleView
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear { scheduleAutoHide() }
        .onChange(of: playerService.isPlaying) { _, _ in scheduleAutoHide() }
        .onDisappear { hideTask?.cancel() }
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(.largeTitle, weight: .semibold))
                .foregroundStyle(Color.dcTextTertiary)
                .accessibilityHidden(true)
            Text("Pick something to watch")
                .font(DSTypography.subheadline)
                .foregroundStyle(Color.dcTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: DSSpacing.sm) {
            EmptyStateView.error(
                title: "This stream won't play",
                message: message,
                retry: {
                    if let channel = playerService.currentChannel {
                        playerService.load(channel: channel)
                    }
                }
            )
            HStack(spacing: DSSpacing.sm) {
                if let onNext {
                    PrimaryButton("Next Channel", systemImage: "forward.end.fill", kind: .tertiary,
                                  size: .compact, fullWidth: false, action: onNext)
                }
                PrimaryButton("Close", kind: .tertiary, size: .compact, fullWidth: false) {
                    playerService.stop()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dcVideoChrome.opacity(0.85))
    }

    // MARK: - Controls

    private var controlsOverlay: some View {
        ZStack {
            Color.dcScrim
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: DSSpacing.sm)
                transport
                Spacer(minLength: DSSpacing.sm)
                bottomBar
            }
            .padding(DSSpacing.md)
        }
    }

    private var topBar: some View {
        HStack(spacing: DSSpacing.sm) {
            if isLive {
                LiveBadge()
            }
            if externalDisplay.isExternalDisplayConnected {
                Label("On car display", systemImage: "rectangle.on.rectangle")
                    .font(DSTypography.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            AirPlayRoutePickerRepresentable(tintColor: .white)
                .frame(width: DSLayout.minTapTarget, height: DSLayout.minTapTarget)
                .accessibilityLabel(Text("Play on another screen"))
            if showsFullscreenToggle {
                overlayIconButton(isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                                  label: isFullscreen ? "Exit full screen" : "Full screen") {
                    isFullscreen.toggle()
                }
            }
        }
    }

    private var transport: some View {
        HStack(spacing: DSSpacing.xl) {
            if let onPrevious {
                overlayIconButton("backward.end.fill", label: "Previous channel", action: onPrevious)
            }
            if !isLive {
                overlayIconButton("gobackward.10", label: "Back 10 seconds") { playerService.skip(seconds: -10) }
            }
            Button {
                playerService.togglePlayPause()
                scheduleAutoHide()
            } label: {
                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(.title, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(width: 64, height: 64)
                    .background(Color.white, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(playerService.isPlaying ? "Pause" : "Play"))
            if !isLive {
                overlayIconButton("goforward.10", label: "Forward 10 seconds") { playerService.skip(seconds: 10) }
            }
            if let onNext {
                overlayIconButton("forward.end.fill", label: "Next channel", action: onNext)
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if isLive {
            HStack {
                Text(playerService.currentChannel?.name ?? "")
                    .font(DSTypography.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
            }
        } else {
            VStack(spacing: DSSpacing.xxs) {
                Slider(
                    value: Binding(
                        get: { isSeeking ? seekSliderValue : playerService.currentTime },
                        set: { newValue in
                            seekSliderValue = newValue
                            isSeeking = true
                        }
                    ),
                    in: 0...max(playerService.duration, 1),
                    onEditingChanged: { editing in
                        if !editing {
                            playerService.seek(to: seekSliderValue)
                            isSeeking = false
                            scheduleAutoHide()
                        } else {
                            hideTask?.cancel()
                        }
                    }
                )
                .tint(Color.dcAccent)
                .accessibilityLabel(Text("Playback position"))
                .accessibilityValue(Text("\(TimecodeFormatter.string(playerService.currentTime)) of \(TimecodeFormatter.string(playerService.duration))"))

                HStack {
                    Text(TimecodeFormatter.string(isSeeking ? seekSliderValue : playerService.currentTime))
                    Spacer()
                    Text("-" + TimecodeFormatter.string(max(playerService.duration - playerService.currentTime, 0)))
                }
                .font(DSTypography.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)
            }
        }
    }

    private func overlayIconButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            scheduleAutoHide()
        } label: {
            Image(systemName: systemImage)
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: DSLayout.minTapTarget, height: DSLayout.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    // MARK: - Auto-hide

    private func toggleControls() {
        withAnimation(DSMotion.animation(DSMotion.quick, reduceMotion: reduceMotion)) {
            showControls.toggle()
        }
        scheduleAutoHide()
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        guard showControls, playerService.isPlaying, !UIAccessibility.isVoiceOverRunning else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled, playerService.isPlaying, !isSeeking else { return }
            withAnimation(DSMotion.animation(DSMotion.standard, reduceMotion: reduceMotion)) {
                showControls = false
            }
        }
    }
}

/// AVPlayerLayer-backed view. Unlike AVPlayerViewController, any number of these can share one
/// AVPlayer, so the phone and the external display can render the same video at the same time.
public struct CustomVideoPlayerRepresentable: UIViewRepresentable {
    public let player: AVPlayer?

    public init(player: AVPlayer?) {
        self.player = player
    }

    public func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    public func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    public static func dismantleUIView(_ uiView: PlayerLayerView, coordinator: ()) {
        uiView.playerLayer.player = nil
    }
}

public final class PlayerLayerView: UIView {
    public override static var layerClass: AnyClass { AVPlayerLayer.self }
    public var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
