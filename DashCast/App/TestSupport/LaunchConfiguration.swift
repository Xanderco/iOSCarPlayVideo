import Foundation
import UIKit

/// Launch arguments understood by DashCast for automated testing.
///
/// | Argument          | Effect                                                                  |
/// |-------------------|-------------------------------------------------------------------------|
/// | `-uiTesting`      | UI-test mode: wipes persisted state, disables UIKit animations.          |
/// | `-UITests`        | Legacy alias of `-uiTesting`.                                           |
/// | `-seedDemoData`   | Seeds a demo playlist + one favorite (local bundled videos only).       |
/// | `-stubNetwork`    | Routes every http(s) request of `URLSession.shared` to `StubNetwork`;   |
/// |                   | unknown URLs fail instead of reaching the internet.                     |
/// | `-initialTab <t>` | Handled by `AppState` (cast/drive/widgets/sounds/me).                   |
///
/// Nothing here runs unless one of these arguments is passed, so production launches are unaffected.
public enum LaunchConfiguration {
    public static let uiTestingArgument = "-uiTesting"
    public static let legacyUITestingArgument = "-UITests"
    public static let seedDemoDataArgument = "-seedDemoData"
    public static let stubNetworkArgument = "-stubNetwork"

    static var arguments: [String] { ProcessInfo.processInfo.arguments }

    public static var isUITesting: Bool {
        arguments.contains(uiTestingArgument) || arguments.contains(legacyUITestingArgument)
    }

    public static var shouldSeedDemoData: Bool { arguments.contains(seedDemoDataArgument) }

    public static var shouldStubNetwork: Bool { arguments.contains(stubNetworkArgument) }

    private static var didApply = false

    /// Called once, as early as possible (from `DashCastApp.init`), before any shared store is created.
    @MainActor
    public static func applyIfNeeded() {
        guard !didApply else { return }
        didApply = true

        if isUITesting {
            resetPersistentState()
            UIView.setAnimationsEnabled(false)
        }
        if shouldStubNetwork {
            StubNetwork.install()
        }
        if shouldSeedDemoData {
            TestDataSeeder.seedPlaylists()
        }
    }

    /// Every UI test starts from a fresh install state so tests never depend on each other.
    static func resetPersistentState(defaults: UserDefaults = .standard) {
        if let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }
        // Keep the passenger/safety notice and other first-launch flows deterministic:
        // tests that want them pass explicit arguments.
        defaults.synchronize()
    }
}
