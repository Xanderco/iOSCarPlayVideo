import Foundation

/// Owner road-test builds: a Debug build installed from Xcode onto a device is treated as Pro,
/// because Xcode's local StoreKit purchases only exist while the app is launched from Xcode
/// (opened from the Home Screen it would fall back to the free tier mid-drive).
///
/// Never active in Release / TestFlight / App Store builds, and never during unit tests,
/// UI tests or screenshot runs, so the free-tier and paywall behaviour stays fully tested.
enum DeveloperProUnlock {
    static var isActive: Bool {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil || env["XCTestSessionIdentifier"] != nil { return false }
        let args = ProcessInfo.processInfo.arguments
        let automated = ["-UITests", "-uiTesting", "-seedDemoData", "-stubNetwork"]
        if args.contains(where: automated.contains) { return false }
        #if targetEnvironment(simulator)
        return false // the simulator keeps the real free-tier behaviour for manual QA
        #else
        return true
        #endif
        #else
        return false
        #endif
    }
}
