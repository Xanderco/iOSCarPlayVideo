import Foundation
import AppIntents
import SwiftUI

// MARK: - 1. Start Trip Recording Intent

public struct StartTripRecordingIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Drive Recording"
    public static var description = IntentDescription("Starts recording your trip telemetry and drive path in DashCast.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let locationService = DriveLocationService.shared
        if !locationService.isTracking {
            locationService.startTrip()
        }
        AppState.shared.selectedTab = .drive
        return .result(dialog: "Drive recording started in DashCast.")
    }
}

// MARK: - 2. Resume Video Cast Intent

public struct ResumeLastCastIntent: AppIntent {
    public static var title: LocalizedStringResource = "Resume Video Cast"
    public static var description = IntentDescription("Resumes playback of your in-car video or parked stream in DashCast.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let player = VideoPlayerService.shared
        player.play()
        AppState.shared.selectedTab = .cast
        return .result(dialog: "Resuming video playback in DashCast.")
    }
}

// MARK: - 3. Toggle Night Vision HUD Intent

public struct ToggleNightHUDIntent: AppIntent {
    public static var title: LocalizedStringResource = "Toggle Night Vision HUD"
    public static var description = IntentDescription("Toggles high-contrast pure black OLED night vision HUD display in DashCast.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults.standard
        let current = defaults.bool(forKey: "dashcast_oled_night_hud_active")
        let updated = !current
        defaults.set(updated, forKey: "dashcast_oled_night_hud_active")
        NotificationCenter.default.post(
            name: Notification.Name("DashCastNightHUDToggledNotification"),
            object: nil,
            userInfo: ["isActive": updated]
        )
        let stateMessage = updated ? "Night Vision HUD activated." : "Night Vision HUD deactivated."
        return .result(dialog: "\(stateMessage)")
    }
}

// MARK: - 4. Play Welcome Chime Intent

public struct PlayCarChimeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Play Welcome Chime"
    public static var description = IntentDescription("Plays your selected car personality welcome sound or CarPlay connection chime.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let catalog = SoundCatalogService.shared
        let sound = catalog.trendingSounds.first ?? catalog.allSounds.first
        if let sound = sound {
            SoundPlayerEngine.shared.play(sound: sound)
            return .result(dialog: "Playing \(sound.title) chime in DashCast.")
        } else {
            return .result(dialog: "Welcome chime played.")
        }
    }
}

// MARK: - 5. App Shortcuts Provider

public struct DashCastShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTripRecordingIntent(),
            phrases: [
                "Start drive in \(.applicationName)",
                "Start trip recording in \(.applicationName)",
                "Record drive in \(.applicationName)"
            ],
            shortTitle: "Start Drive",
            systemImageName: "steeringwheel"
        )

        AppShortcut(
            intent: ResumeLastCastIntent(),
            phrases: [
                "Resume video in \(.applicationName)",
                "Stream video in \(.applicationName)",
                "Resume cast in \(.applicationName)"
            ],
            shortTitle: "Resume Cast",
            systemImageName: "play.tv.fill"
        )

        AppShortcut(
            intent: ToggleNightHUDIntent(),
            phrases: [
                "Toggle night HUD in \(.applicationName)",
                "Turn on night mode in \(.applicationName)",
                "Night vision in \(.applicationName)"
            ],
            shortTitle: "Toggle Night HUD",
            systemImageName: "moon.fill"
        )

        AppShortcut(
            intent: PlayCarChimeIntent(),
            phrases: [
                "Play car chime in \(.applicationName)",
                "Play welcome sound in \(.applicationName)"
            ],
            shortTitle: "Play Chime",
            systemImageName: "bell.fill"
        )
    }
}
