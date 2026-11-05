import SwiftUI
import UIKit

/// UI state for the playback surfaces: mini player, full player and Car Mode.
/// Playback itself lives in `VideoPlayerService`; this only decides what is on screen.
@MainActor
public final class PlayerPresentation: ObservableObject {
    public static let shared = PlayerPresentation()

    /// Full-screen player is showing (mini player hidden).
    @Published public var isExpanded = false
    /// Landscape Car Mode is showing (mini player hidden).
    @Published public var isCarModeActive = false

    public init() {}

    /// Starts `channel` (resuming on-demand videos) and optionally opens the full player.
    public func play(_ channel: ChannelModel, expand: Bool = true) {
        WatchHistoryStore.shared.play(channel)
        if expand && !isCarModeActive { isExpanded = true }
    }

    public func openCarMode() {
        guard isExpanded else {
            isCarModeActive = true
            return
        }
        // Let the full player finish dismissing before presenting Car Mode.
        isExpanded = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            self.isCarModeActive = true
        }
    }

    /// Plays the previous/next channel in the current group.
    public func step(_ offset: Int, player: VideoPlayerService = .shared) {
        let list = PlaybackQueue.siblings(of: player.currentChannel)
        if let target = PlaybackQueue.neighbor(of: player.currentChannel, offset: offset, in: list) {
            WatchHistoryStore.shared.play(target)
        }
    }

    public func canStep(player: VideoPlayerService = .shared) -> Bool {
        PlaybackQueue.siblings(of: player.currentChannel).count > 1
    }
}

/// Asks the foreground app scene for an interface orientation (used by Car Mode).
@MainActor
enum OrientationRequest {
    static func request(_ mask: UIInterfaceOrientationMask) {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowApplication }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }
        scene.windows.first(where: \.isKeyWindow)?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in
            // The system may refuse (e.g. orientation lock on iPad); layouts adapt either way.
        }
    }
}

/// Formats seconds as m:ss or h:mm:ss.
enum TimecodeFormatter {
    static func string(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
