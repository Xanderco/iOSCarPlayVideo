import Foundation
import ActivityKit
import SwiftUI

// Shared between the DashCast app and the DashCastCastWidget extension.

enum CarCastLiveActivityCopy {
    nonisolated static let lockScreenTitleFormatString = "DashCast · %@"
    nonisolated static let mirroringModeString = "Mirroring"
    nonisolated static let airPlayModeString = "AirPlay"
    nonisolated static let externalDisplayModeString = "External display"
    nonisolated static let pausedForMotionString = "Paused while the vehicle is moving"
    nonisolated static let screenMirroringLiveString = "Screen mirroring is live"
    nonisolated static let playingConnectedDisplayString = "Playing on connected display"
    nonisolated static let brandNameString = "DashCast"

    nonisolated static let allLocalizationKeys: [String] = [
        lockScreenTitleFormatString,
        mirroringModeString,
        airPlayModeString,
        externalDisplayModeString,
        pausedForMotionString,
        screenMirroringLiveString,
        playingConnectedDisplayString,
        brandNameString
    ]

    nonisolated static func localizedMode(_ mode: String, bundle: Bundle = .main) -> String {
        String(localized: String.LocalizationValue(mode), bundle: bundle)
    }

    @MainActor
    static func modeKey(_ mode: String) -> LocalizedStringKey {
        LocalizedStringKey(mode)
    }

    @MainActor
    static func detailKey(_ detail: String) -> LocalizedStringKey {
        LocalizedStringKey(detail)
    }
}

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
