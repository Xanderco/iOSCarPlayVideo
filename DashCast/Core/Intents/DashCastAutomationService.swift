import Foundation
import SwiftUI
import Combine

/// Manages Siri Shortcuts and hands-free CarPlay automation triggers,
/// providing simulation helpers for in-app testing and deep-link routing.
@MainActor
public final class DashCastAutomationService: ObservableObject {
    public static let shared = DashCastAutomationService()

    @Published public private(set) var lastExecutedIntentName: String?
    @Published public private(set) var lastExecutionTimestamp: Date?
    @Published public private(set) var executionLog: [AutomationExecutionEvent] = []

    public struct AutomationExecutionEvent: Identifiable, Equatable {
        public let id = UUID()
        public let intentName: String
        public let timestamp: Date
        public let summary: String

        public init(intentName: String, summary: String, timestamp: Date = Date()) {
            self.intentName = intentName
            self.summary = summary
            self.timestamp = timestamp
        }
    }

    public init() {}

    public func recordExecution(intentName: String, summary: String) {
        lastExecutedIntentName = intentName
        lastExecutionTimestamp = Date()
        let event = AutomationExecutionEvent(intentName: intentName, summary: summary)
        executionLog.insert(event, at: 0)
        if executionLog.count > 20 {
            executionLog.removeLast()
        }
    }

    /// Triggers start trip recording automation
    public func triggerStartTrip() {
        let locationService = DriveLocationService.shared
        if !locationService.isTracking {
            locationService.startTrip()
        }
        AppState.shared.selectedTab = .drive
        recordExecution(intentName: "StartTripRecordingIntent", summary: "Drive recording started via automation")
    }

    /// Triggers video cast playback resume automation
    public func triggerResumeCast() {
        VideoPlayerService.shared.play()
        AppState.shared.selectedTab = .cast
        recordExecution(intentName: "ResumeLastCastIntent", summary: "Video playback resumed via automation")
    }

    /// Triggers night HUD toggle automation
    public func triggerToggleNightHUD() {
        let defaults = UserDefaults.standard
        let current = defaults.bool(forKey: "dashcast_oled_night_hud_active")
        let updated = !current
        defaults.set(updated, forKey: "dashcast_oled_night_hud_active")
        NotificationCenter.default.post(
            name: Notification.Name("DashCastNightHUDToggledNotification"),
            object: nil,
            userInfo: ["isActive": updated]
        )
        let summary = updated ? "Night HUD activated" : "Night HUD deactivated"
        recordExecution(intentName: "ToggleNightHUDIntent", summary: summary)
    }

    /// Triggers welcome chime playback automation
    public func triggerPlayChime() {
        let catalog = SoundCatalogService.shared
        let sound = catalog.trendingSounds.first ?? catalog.allSounds.first
        if let sound = sound {
            SoundPlayerEngine.shared.play(sound: sound)
            recordExecution(intentName: "PlayCarChimeIntent", summary: "Chime '\(sound.title)' played")
        }
    }

    /// Launches Apple's Shortcuts application
    public func launchShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }
}
