import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var selectedTab: TabItem = .home
    @Published public var isProLifetimeUnlocked: Bool = false
    @Published public var showPaywall: Bool = false
    /// Settings sub-screen to push next time Settings appears (deep links into Car Extras).
    @Published public var settingsDeepLink: SettingsRoute?
    @Published public var showCarPlaySimulator: Bool = false
    @Published public var initialCarPlayMode: String = "App in CarPlay"
    @Published public var useMilesPerHour: Bool = false

    /// Root tabs. Drive is a first-class feature (owner decision on O2); Widgets / Sounds live under
    /// Settings › Car Extras.
    public enum TabItem: String, CaseIterable, Identifiable {
        case home = "Home"
        case library = "Library"
        case cast = "Cast"
        case drive = "Drive"
        case settings = "Settings"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .home: return "house.fill"
            case .library: return "square.stack.fill"
            case .cast: return "airplayvideo"
            case .drive: return "car.fill"
            case .settings: return "gearshape.fill"
            }
        }

        /// Former tab names, kept so older call sites and deep links still compile and land somewhere sensible.
        @available(*, deprecated, message: "Widgets is Settings › Car Extras › Car Screen; use AppState.open(_:)")
        public static let widgets: TabItem = .settings
        @available(*, deprecated, message: "Sounds is Settings › Car Extras › Car Chime; use AppState.open(_:)")
        public static let sounds: TabItem = .settings
        @available(*, deprecated, renamed: "settings")
        public static let me: TabItem = .settings

        /// Maps a `-initialTab` value (current or legacy) to a tab plus an optional Settings screen.
        public static func resolve(launchValue: String) -> (tab: TabItem, route: SettingsRoute?)? {
            switch launchValue.lowercased() {
            case "home": return (.home, nil)
            case "library": return (.library, nil)
            case "cast": return (.cast, nil)
            case "settings", "me": return (.settings, nil)
            case "drive", "trips": return (.drive, nil)
            case "widgets", "carscreen": return (.settings, .carScreen)
            case "sounds", "chime": return (.settings, .chime)
            default: return nil
            }
        }
    }

    public init(isProLifetimeUnlocked: Bool = false) {
        self.isProLifetimeUnlocked = isProLifetimeUnlocked
        self.useMilesPerHour = UserDefaults.standard.bool(forKey: "useMilesPerHour")

        if let tabIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "-initialTab"),
           ProcessInfo.processInfo.arguments.indices.contains(tabIndex + 1) {
            let tabArg = ProcessInfo.processInfo.arguments[tabIndex + 1]
            if let resolved = TabItem.resolve(launchValue: tabArg) {
                self.selectedTab = resolved.tab
                self.settingsDeepLink = resolved.route
            }
        }

        // App Store media pipeline: populate trips/metrics with demo content.
        DemoDataSeeder.seedIfRequested()
        CarScreenDefaults.seedIfNeeded()
        OnboardingView.applyLaunchOverrides()

        if ProcessInfo.processInfo.arguments.contains("-showPaywall") {
            self.showPaywall = true
        }

        if ProcessInfo.processInfo.arguments.contains("-showWidgetEditor") {
            open(.carScreen)
        }

        if ProcessInfo.processInfo.arguments.contains("-carplaySimulator") {
            self.showCarPlaySimulator = true
            self.selectedTab = .home
        }

        if ProcessInfo.processInfo.arguments.contains("-carplayDashboard") {
            self.showCarPlaySimulator = true
            self.initialCarPlayMode = "CarPlay Dashboard"
            self.selectedTab = .home
        }

        if ProcessInfo.processInfo.arguments.contains("-carplayHomeMenu") {
            self.showCarPlaySimulator = true
            self.initialCarPlayMode = "CarPlay Home Menu"
            self.selectedTab = .home
        }
    }

    /// Switches to Settings and pushes a Car Extras (or other Settings) screen.
    public func open(_ route: SettingsRoute) {
        selectedTab = .settings
        settingsDeepLink = route
    }

    public func unlockProLifetime() {
        isProLifetimeUnlocked = true
        showPaywall = false
    }

    public func setSpeedUnit(milesPerHour: Bool) {
        self.useMilesPerHour = milesPerHour
        UserDefaults.standard.set(milesPerHour, forKey: "useMilesPerHour")
    }
}
