import Foundation
import ActivityKit

// Shared between the DashCast app and the DashCastCastWidget extension.

struct CarCastActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Short label for the output path, e.g. "AirPlay" or "Mirroring".
        var mode: String
        var title: String
        var detail: String
        var isPausedForMotion: Bool
        var startedAt: Date
    }

    var sessionName: String
}
