import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var selectedTab: TabItem = .cast
    @Published public var isProLifetimeUnlocked: Bool = false
    @Published public var showPaywall: Bool = false
    @Published public var showWidgetEditor: Bool = false
    @Published public var showCarPlaySimulator: Bool = false
    @Published public var initialCarPlayMode: String = "App in CarPlay"
    @Published public var isDriveActive: Bool = false
    @Published public var useMilesPerHour: Bool = false

    // Matches CarDash exact 5 native tabs
    public enum TabItem: String, CaseIterable, Identifiable {
        case cast = "Cast"
        case drive = "Drive"
        case widgets = "Widgets"
        case sounds = "Sounds"
        case me = "Me"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .cast: return "tv"
            case .drive: return "car.fill"
            case .widgets: return "square.grid.2x2.fill"
            case .sounds: return "speaker.wave.3.fill"
            case .me: return "person.crop.circle.fill"
            }
        }
    }

    public init(isProLifetimeUnlocked: Bool = false) {
        self.isProLifetimeUnlocked = isProLifetimeUnlocked
        self.useMilesPerHour = UserDefaults.standard.bool(forKey: "useMilesPerHour")

        if let tabIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "-initialTab"),
           ProcessInfo.processInfo.arguments.indices.contains(tabIndex + 1) {
            let tabArg = ProcessInfo.processInfo.arguments[tabIndex + 1].lowercased()
            if let matched = TabItem.allCases.first(where: { $0.rawValue.lowercased() == tabArg }) {
                self.selectedTab = matched
            }
        }

        // App Store media pipeline: populate trips/metrics with demo content.
        DemoDataSeeder.seedIfRequested()

        if ProcessInfo.processInfo.arguments.contains("-showPaywall") {
            self.showPaywall = true
        }

        if ProcessInfo.processInfo.arguments.contains("-showWidgetEditor") {
            self.showWidgetEditor = true
            self.selectedTab = .widgets
        }

        if ProcessInfo.processInfo.arguments.contains("-carplaySimulator") {
            self.showCarPlaySimulator = true
            self.selectedTab = .cast
        }

        if ProcessInfo.processInfo.arguments.contains("-carplayDashboard") {
            self.showCarPlaySimulator = true
            self.initialCarPlayMode = "CarPlay Dashboard"
            self.selectedTab = .cast
        }

        if ProcessInfo.processInfo.arguments.contains("-carplayHomeMenu") {
            self.showCarPlaySimulator = true
            self.initialCarPlayMode = "CarPlay Home Menu"
            self.selectedTab = .cast
        }
    }

    /// Handles `dashcast://cast|drive|widgets|sounds|me` links from Home/Lock Screen widgets.
    @discardableResult
    public func handleDeepLink(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == DashCastLinks.scheme else { return false }
        let target = (url.host ?? url.pathComponents.dropFirst().first ?? "").lowercased()
        guard let tab = TabItem.allCases.first(where: { $0.rawValue.lowercased() == target }) else { return false }
        selectedTab = tab
        return true
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
