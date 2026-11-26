import SwiftUI
import AVKit

public struct AutomotiveVideoPlayerView: View {
    @ObservedObject var playerService = VideoPlayerService.shared
    @ObservedObject var externalDisplay = ExternalDisplayManager.shared
    @State private var showControls: Bool = true
    @State private var showUnlockHint: Bool = false
    @State private var isSeeking: Bool = false
    @State private var seekSliderValue: Double = 0
    @State private var autoHideTask: Task<Void, Never>?
    @State private var unlockHintTask: Task<Void, Never>?
    @Binding var isFullscreen: Bool

    public init(isFullscreen: Binding<Bool> = .constant(false)) {
        self._isFullscreen = isFullscreen
    }

    public var body: some View {
        ZStack {
            Color.black

            if playerService.currentChannel != nil {
                CustomVideoPlayerRepresentable(
                    player: playerService.isVideoLayerAttached ? playerService.player : nil,
                    videoGravity: playerService.videoAspectMode.avLayerGravity
                )
                .ignoresSafeArea()
                .onTapGesture {
                    handleSurfaceTap()
                }

                if (playerService.isBuffering || playerService.streamHealth.isReconnecting) && playerService.playbackError == nil {
                    bufferingOrReconnectingBadge
                }

                if let error = playerService.playbackError {
                    errorOverlay(error)
                } else if playerService.isControlsLocked {
                    if showUnlockHint {
                        lockedControlsOverlay
                            .transition(.opacity)
                    }
                } else if showControls {
                    controlsOverlay
                        .transition(.opacity)
                }
            } else {
                placeholderView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isFullscreen ? 0 : 16, style: .continuous))
        .onChange(of: playerService.isPlaying) { _, playing in
            if playing {
                scheduleControlsAutoHide()
            } else {
                autoHideTask?.cancel()
            }
        }
        .onChange(of: playerService.isControlsLocked) { _, locked in
            if locked {
                autoHideTask?.cancel()
                showControls = false
                presentUnlockHintTemporarily()
            } else {
                unlockHintTask?.cancel()
                showUnlockHint = false
                showControls = true
                scheduleControlsAutoHide()
            }
        }
        .onDisappear {
            autoHideTask?.cancel()
            unlockHintTask?.cancel()
        }
    }

    private func handleSurfaceTap() {
        if playerService.isControlsLocked {
            withAnimation(.easeInOut(duration: 0.2)) {
                showUnlockHint.toggle()
            }
            if showUnlockHint {
                presentUnlockHintTemporarily()
            } else {
                unlockHintTask?.cancel()
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            showControls.toggle()
        }
        if showControls {
            scheduleControlsAutoHide()
        } else {
            autoHideTask?.cancel()
        }
    }

    private func scheduleControlsAutoHide() {
        autoHideTask?.cancel()
        guard playerService.isPlaying, !isSeeking, !playerService.isControlsLocked else { return }
        autoHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            if playerService.isPlaying && !isSeeking && !playerService.isControlsLocked {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showControls = false
                }
            }
        }
    }

    private func presentUnlockHintTemporarily() {
        unlockHintTask?.cancel()
        showUnlockHint = true
        unlockHintTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                showUnlockHint = false
            }
        }
    }

    private var bufferingOrReconnectingBadge: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(playerService.streamHealth.isReconnecting ? Color.dashYellow : .white)
                .scaleEffect(1.25)

            if case .reconnecting(let attempt, let maxAttempts) = playerService.streamHealth {
                VStack(spacing: 6) {
                    Text("Reconnecting (\(attempt)/\(maxAttempts))…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    HStack(spacing: 10) {
                        Button("Reconnect Now") {
                            playerService.reconnectNow()
                        }
                        .font(.system(size: 12, weight: .bold))
                        .buttonStyle(.borderedProminent)
                        .tint(.dashYellow)
                        .foregroundStyle(.black)

                        Button("Cancel") {
                            playerService.pause()
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .allowsHitTesting(playerService.streamHealth.isReconnecting)
    }

    private var lockedControlsOverlay: some View {
        VStack {
            Spacer()
            Button {
                playerService.setControlsLocked(false)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.dashYellow)
                    Text("Controls Locked · Tap to Unlock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.78))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.dashYellow.opacity(0.6), lineWidth: 1))
            }
            .accessibilityIdentifier("Player_UnlockControlsButton")
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Button("Reconnect Now") {
                    playerService.reconnectNow()
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

    private var statusBadgeColor: Color {
        if !playerService.isNetworkAvailable && !(playerService.currentChannel?.streamURL.isFileURL ?? true) {
            return Color.dashOrange
        }
        if playerService.streamHealth.isReconnecting {
            return Color.dashYellow
        }
        return Color.dashGreen
    }

    private var statusBadgeText: LocalizedStringKey {
        if !playerService.isNetworkAvailable && !(playerService.currentChannel?.streamURL.isFileURL ?? true) {
            return "No Connection"
        }
        if case .reconnecting(let attempt, let maxAttempts) = playerService.streamHealth {
            return "Reconnecting (\(attempt)/\(maxAttempts))…"
        }
        return externalDisplay.isExternalDisplayConnected
            ? "Showing on external display"
            : "Parked Video · AirPlay / CarPlay audio"
    }

    private var controlsOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack {
                // Top bar: title, stream health, aspect, lock & fullscreen
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playerService.currentChannel?.name ?? "Video Player")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusBadgeColor)
                                .frame(width: 6, height: 6)
                            Text(statusBadgeText)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.dashTextSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button {
                        playerService.toggleVideoAspectMode()
                        scheduleControlsAutoHide()
                    } label: {
                        Image(systemName: playerService.videoAspectMode.systemImageName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(playerService.videoAspectMode == .fit ? "Fill Screen" : "Fit Screen")
                    .accessibilityIdentifier("Player_AspectModeButton")

                    Button {
                        playerService.toggleControlsLock()
                    } label: {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Lock Controls")
                    .accessibilityIdentifier("Player_LockControlsButton")

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
                        scheduleControlsAutoHide()
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
                        scheduleControlsAutoHide()
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }

                    Button {
                        playerService.togglePlayPause()
                        scheduleControlsAutoHide()
                    } label: {
                        Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(Color.dashYellow)
                            .shadow(color: Color.dashYellow.opacity(0.5), radius: 10)
                    }

                    Button {
                        playerService.skip(seconds: 10)
                        scheduleControlsAutoHide()
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
                            if editing {
                                autoHideTask?.cancel()
                            } else {
                                playerService.seek(to: seekSliderValue)
                                isSeeking = false
                                scheduleControlsAutoHide()
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
    public let videoGravity: AVLayerVideoGravity

    public init(player: AVPlayer?, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        self.player = player
        self.videoGravity = videoGravity
    }

    public func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = videoGravity
        view.playerLayer.player = player
        return view
    }

    public func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
        if uiView.playerLayer.videoGravity != videoGravity {
            uiView.playerLayer.videoGravity = videoGravity
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
