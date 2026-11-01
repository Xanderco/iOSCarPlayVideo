import SwiftUI
import AVKit

public struct AutomotiveVideoPlayerView: View {
    @ObservedObject var playerService = VideoPlayerService.shared
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
                CustomVideoPlayerRepresentable(player: playerService.player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showControls.toggle()
                        }
                    }

                if showControls {
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
                            Text("Parked Video · Audio over CarPlay")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.dashTextSecondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        AirPlayRoutePickerRepresentable()
                            .frame(width: 32, height: 32)

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
                            .foregroundStyle(Color.dashCyan)
                            .shadow(color: Color.dashCyan.opacity(0.5), radius: 10)
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
                    .tint(.dashCyan)

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

public struct CustomVideoPlayerRepresentable: UIViewControllerRepresentable {
    public let player: AVPlayer

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }

    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
