import SwiftUI
import AVKit

public struct AutomotiveVideoPlayerView: View {
    @ObservedObject var playerService = VideoPlayerService.shared
    @ObservedObject var externalDisplay = ExternalDisplayManager.shared
    @State private var showControls: Bool = true
    @State private var isSeeking: Bool = false
    @State private var seekSliderValue: Double = 0
    @Binding var isFullscreen: Bool

    public init(isFullscreen: Binding<Bool> = .constant(false)) {
        self._isFullscreen = isFullscreen
    }

    public var body: some View {
        ZStack {
            Color.black

            if playerService.currentChannel != nil {
                CustomVideoPlayerRepresentable(player: playerService.isVideoLayerAttached ? playerService.player : nil)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showControls.toggle()
                        }
                    }

                if playerService.isBuffering && playerService.playbackError == nil {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.4)
                        .allowsHitTesting(false)
                }

                if let error = playerService.playbackError {
                    errorOverlay(error)
                } else if showControls {
                    controlsOverlay
                        .transition(.opacity)
                }
            } else {
                placeholderView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isFullscreen ? 0 : 16, style: .continuous))
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.tv")
                .font(.system(size: 44))
                .foregroundStyle(Color.dashTextMuted)
            Text("Select a video or stream below to play")
                .font(ThemeFonts.hudCaption(size: 14))
                .foregroundStyle(Color.dashTextMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dashSurface)
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.dashOrange)
            Text("Can't play \(playerService.currentChannel?.name ?? "this video")")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.dashTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            HStack(spacing: 12) {
                Button("Retry") {
                    if let channel = playerService.currentChannel {
                        playerService.load(channel: channel)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.dashYellow)
                .foregroundStyle(.black)

                Button("Close") { playerService.stop() }
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.75))
    }

    private var controlsOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack {
                // Top bar: title & fullscreen toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playerService.currentChannel?.name ?? "Video Player")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.dashGreen)
                                .frame(width: 6, height: 6)
                            Text(externalDisplay.isExternalDisplayConnected ? "Showing on external display" : "Parked Video · AirPlay / CarPlay audio")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.dashTextSecondary)
                        }
                    }

                    Spacer()

                    AirPlayRoutePickerRepresentable(tintColor: .white)
                        .frame(width: 34, height: 34)

                    Button {
                        playerService.stop()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(9)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Close player")

                    Button {
                        withAnimation {
                            isFullscreen.toggle()
                        }
                    } label: {
                        Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "viewfinder")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding()

                Spacer()

                // Center transport controls
                HStack(spacing: 36) {
                    Button {
                        playerService.skip(seconds: -10)
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }

                    Button {
                        playerService.togglePlayPause()
                    } label: {
                        Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(Color.dashYellow)
                            .shadow(color: Color.dashYellow.opacity(0.5), radius: 10)
                    }

                    Button {
                        playerService.skip(seconds: 10)
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }

                Spacer()

                // Bottom scrub bar & timestamps
                VStack(spacing: 6) {
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
                            }
                        }
                    )
                    .tint(.dashYellow)

                    HStack {
                        Text(formatTime(playerService.currentTime))
                            .font(ThemeFonts.monospaceDigits(size: 12))
                            .foregroundStyle(Color.dashTextSecondary)

                        Spacer()

                        Text(playerService.duration > 0 ? formatTime(playerService.duration) : "LIVE")
                            .font(ThemeFonts.monospaceDigits(size: 12))
                            .foregroundStyle(playerService.duration > 0 ? Color.dashTextSecondary : Color.dashRed)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let secs = Int(seconds)
        let hours = secs / 3600
        let minutes = (secs % 3600) / 60
        let remainingSeconds = secs % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%02d:%02d", minutes, remainingSeconds)
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
