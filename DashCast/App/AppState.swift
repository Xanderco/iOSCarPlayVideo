import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var selectedTab: TabItem = .cast
    @Published public var isProLifetimeUnlocked: Bool = false
    @Published public var showPaywall: Bool = false
    @Published public var isDriveActive: Bool = false
    @Published public var useMilesPerHour: Bool = false

    public enum TabItem: String, CaseIterable, Identifiable {
        case cast = "Cast"
        case drive = "Drive"
        case territory = "Territory"
        case widgets = "Widgets"
        case sounds = "Sounds"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .cast: return "tv.fill"
            case .drive: return "gauge.with.dots.needle.bottom.50percent"
            case .territory: return "hexagon.fill"
            case .widgets: return "square.grid.2x2.fill"
            case .sounds: return "speaker.wave.3.fill"
            }
        }
    }

    public init(isProLifetimeUnlocked: Bool = false) {
        self.isProLifetimeUnlocked = isProLifetimeUnlocked
        self.useMilesPerHour = UserDefaults.standard.bool(forKey: "useMilesPerHour")
        applyCommandLineArguments()
    }

    private func applyCommandLineArguments() {
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment

        if args.contains("-unlockPro") || env["SIMCTL_CHILD_UNLOCK_PRO"] == "1" {
            self.isProLifetimeUnlocked = true
        }

        if let tabIdx = args.firstIndex(of: "-selectedTab"), tabIdx + 1 < args.count {
            selectTabByName(args[tabIdx + 1])
        } else if let envTab = env["SIMCTL_CHILD_SELECTED_TAB"] {
            selectTabByName(envTab)
        }
    }

    public func selectTabByName(_ name: String) {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "cast": self.selectedTab = .cast
        case "drive": self.selectedTab = .drive
        case "territory": self.selectedTab = .territory
        case "widgets": self.selectedTab = .widgets
        case "sounds": self.selectedTab = .sounds
        default: break
        }
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
