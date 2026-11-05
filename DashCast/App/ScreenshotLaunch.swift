import Foundation

/// Launch arguments used only by the App Store media pipeline (Scripts/generate-appstore-media.sh).
/// They open a screen directly; they never change layout and are ignored in normal launches.
enum ScreenshotLaunch {
    private static var args: [String] { ProcessInfo.processInfo.arguments }

    /// Present the first-run walkthrough even though `-seedDemoData` skips it.
    static var showOnboarding: Bool { args.contains("-showOnboarding") }
    /// Open the Cast tab's media sources sheet (bundled demo channels).
    static var showMediaSources: Bool { args.contains("-showMediaSources") }
    /// Start the first bundled demo video in the Cast player.
    static var playDemoVideo: Bool { args.contains("-playDemoVideo") }
    /// Open the Drive tab's trip summary for the newest (seeded) trip.
    static var showLatestTrip: Bool { args.contains("-showLatestTrip") }
}
