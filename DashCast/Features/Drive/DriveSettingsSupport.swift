import Foundation
import CoreLocation
import CoreMotion
import UserNotifications

public enum DrivePermissionTone: Equatable, Sendable {
    case green
    case orange
    case red
    case muted
}

public struct DrivePermissionDisplay: Equatable, Sendable {
    public let statusKey: String
    public let tone: DrivePermissionTone

    public init(statusKey: String, tone: DrivePermissionTone) {
        self.statusKey = statusKey
        self.tone = tone
    }
}

public enum DrivePermissionStatusMapper {
    public static func locationDisplay(for status: CLAuthorizationStatus) -> DrivePermissionDisplay {
        switch status {
        case .authorizedAlways:
            return DrivePermissionDisplay(statusKey: "Always", tone: .green)
        case .authorizedWhenInUse:
            return DrivePermissionDisplay(statusKey: "While using", tone: .orange)
        case .denied:
            return DrivePermissionDisplay(statusKey: "Denied", tone: .red)
        case .restricted:
            return DrivePermissionDisplay(statusKey: "Restricted", tone: .red)
        case .notDetermined:
            return DrivePermissionDisplay(statusKey: "Not set", tone: .muted)
        @unknown default:
            return DrivePermissionDisplay(statusKey: "Not set", tone: .muted)
        }
    }

    public static func motionDisplay(for status: CMAuthorizationStatus) -> DrivePermissionDisplay {
        switch status {
        case .authorized:
            return DrivePermissionDisplay(statusKey: "On", tone: .green)
        case .denied:
            return DrivePermissionDisplay(statusKey: "Denied", tone: .red)
        case .restricted:
            return DrivePermissionDisplay(statusKey: "Restricted", tone: .red)
        case .notDetermined:
            return DrivePermissionDisplay(statusKey: "Not set", tone: .muted)
        @unknown default:
            return DrivePermissionDisplay(statusKey: "Not set", tone: .muted)
        }
    }

    public static func notificationDisplay(
        isEnabledInApp: Bool,
        systemStatus: UNAuthorizationStatus
    ) -> DrivePermissionDisplay {
        guard isEnabledInApp else {
            return DrivePermissionDisplay(statusKey: "Off", tone: .muted)
        }
        switch systemStatus {
        case .authorized, .provisional, .ephemeral:
            return DrivePermissionDisplay(statusKey: "On", tone: .green)
        case .denied:
            return DrivePermissionDisplay(statusKey: "Denied", tone: .red)
        case .notDetermined:
            return DrivePermissionDisplay(statusKey: "Not set", tone: .muted)
        @unknown default:
            return DrivePermissionDisplay(statusKey: "Not set", tone: .muted)
        }
    }
}

public enum DriveCountryCatalog {
    public static let allCountries: [String] = {
        let enLocale = Locale(identifier: "en_US")
        var seen = Set<String>()
        var names: [String] = []

        for region in Locale.Region.isoRegions {
            let code = region.identifier
            guard code.count == 2,
                  let name = enLocale.localizedString(forRegionCode: code)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                continue
            }
            if seen.insert(name).inserted {
                names.append(name)
            }
        }

        if names.isEmpty {
            names = ["Colombia", "United States", "Canada", "Mexico", "Spain", "United Kingdom"]
        }

        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }()

    public static func filteredCountries(matching query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allCountries }
        return allCountries.filter { $0.localizedStandardContains(trimmed) }
    }
}
