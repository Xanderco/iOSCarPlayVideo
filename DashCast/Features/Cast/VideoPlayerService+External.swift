import Foundation
import AVFoundation

extension VideoPlayerService {
    /// Lets the shared player route video over AirPlay / external screens.
    public func enableExternalPlayback() {
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
    }

    /// Plays a video URL extracted from the web browser in the DashCast player.
    public func playWebVideo(url: URL, title: String) {
        enableExternalPlayback()
        let channel = ChannelModel(
            name: title.isEmpty ? "Web video" : title,
            streamURL: url,
            groupTitle: "Web"
        )
        load(channel: channel)
    }
}
