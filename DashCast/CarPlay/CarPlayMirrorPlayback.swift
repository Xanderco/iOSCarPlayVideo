import Foundation
import AVFoundation

/// Plays the iPhone screen (low-latency HLS from the DashCastBroadcast extension, ADR-002 §7.5)
/// through the normal DashCast player, i.e. AVPlayer with external playback. That is the
/// system-player route a CarPlay *video* app uses: CarPlay "video in the car" (iOS 26/27) and
/// AirPlay video show it full screen on the car display — parked only.
///
/// Flow: phone Cast → Car Display → "Mirror to CarPlay screen" on → Start Broadcast (system
/// sheet lists only DashCastBroadcast) → this starts automatically once the first segments
/// exist, or from CarPlay → Cast → "Show iPhone screen".
@MainActor
enum CarPlayMirrorPlayback {
    static let channelID = "dashcast.mirror.iphone"

    enum Decision: Equatable {
        case play(URL)
        case mirrorDisabled
        case notBroadcasting
        case vehicleMoving
    }

    /// Pure decision (unit tested). Parked-only wins over everything.
    nonisolated static func decide(mirrorEnabled: Bool, broadcast: BroadcastStatus, vehicleMoving: Bool) -> Decision {
        if vehicleMoving { return .vehicleMoving }
        guard mirrorEnabled else { return .mirrorDisabled }
        guard broadcast.isLive else { return .notBroadcasting }
        return .play(MirrorHLS.playlistURL())
    }

    static var mirrorChannel: ChannelModel {
        ChannelModel(id: channelID, name: "iPhone Screen", streamURL: MirrorHLS.playlistURL(), groupTitle: "Cast")
    }

    static var isPlayingMirror: Bool {
        VideoPlayerService.shared.currentChannel?.id == channelID
    }

    private static var pendingStart: Task<Void, Never>?

    /// Starts playback when allowed. Waits (≤ 10 s) for the extension's first segment so
    /// AVPlayer never sees a 404 playlist.
    @discardableResult
    static func start() -> Decision {
        let moving = CarCastShared.isVehicleMoving() || CarVideoOutputController.shared.parkedGuard.state == .moving
        let decision = decide(mirrorEnabled: CarMirrorFeature.isEnabled(), broadcast: .load(), vehicleMoving: moving)
        guard case .play(let url) = decision else { return decision }
        if isPlayingMirror { return decision }

        pendingStart?.cancel()
        pendingStart = Task { @MainActor in
            for _ in 0..<20 {
                if Task.isCancelled { return }
                if await isStreamReady(url) { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            guard !Task.isCancelled,
                  !CarCastShared.isVehicleMoving(),
                  BroadcastStatus.load().isLive else { return }
            VideoPlayerService.shared.load(channel: mirrorChannel)
        }
        return decision
    }

    /// Broadcast ended or the vehicle moved: stop showing the (now frozen) mirror.
    static func stopIfMirroring() {
        pendingStart?.cancel()
        pendingStart = nil
        if isPlayingMirror {
            VideoPlayerService.shared.stop()
        }
    }

    private static func isStreamReady(_ url: URL) async -> Bool {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 1)
        request.httpMethod = "GET"
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
}
