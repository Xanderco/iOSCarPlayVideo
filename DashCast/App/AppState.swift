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
    @Published public var appLanguage: String = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"

    public func setLanguage(_ lang: String) {
        appLanguage = lang
        UserDefaults.standard.set(lang, forKey: "appLanguage")
    }

    public var effectiveLocale: Locale? {
        switch appLanguage {
        case "es": return Locale(identifier: "es")
        case "en": return Locale(identifier: "en")
        default: return nil
        }
    }

    // Matches CarDash exact 5 native tabs
    public enum TabItem: String, CaseIterable, Identifiable {
        case cast = "Cast"
        case drive = "Drive"
        case widgets = "Widgets"
        case sounds = "Sounds"
        case me = "Me"

        public var id: String { rawValue }

        public var localizedTitle: LocalizedStringKey {
            switch self {
            case .cast: return "Cast"
            case .drive: return "Drive"
            case .widgets: return "Widgets"
            case .sounds: return "Sounds"
            case .me: return "Me"
            }
        }

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

    }

    /// Handles `dashcast://cast` and `dashcast://drive` links from Home/Lock Screen widgets.
    @discardableResult
    public func handleDeepLink(_ url: URL) -> Bool {
        guard let destination = DashCastLinks.destination(for: url) else { return false }
        switch destination {
        case .cast: selectedTab = .cast
        case .drive: selectedTab = .drive
        }
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
