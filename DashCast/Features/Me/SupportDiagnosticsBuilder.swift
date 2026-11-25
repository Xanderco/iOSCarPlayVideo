import Foundation
import SwiftUI
import UIKit

/// Categories for user-submitted support feedback.
public enum FeedbackCategory: String, CaseIterable, Identifiable, Sendable {
    case bug = "Bug Report"
    case playback = "Playback Issue"
    case feature = "Feature Request"
    case other = "Other"

    public var id: String { rawValue }

    public var localizedTitle: LocalizedStringKey {
        switch self {
        case .bug: return "Bug Report"
        case .playback: return "Playback Issue"
        case .feature: return "Feature Request"
        case .other: return "Other"
        }
    }
}

/// Non-sensitive capability and runtime flags included in support diagnostics.
public struct SupportDiagnosticCapabilities: Equatable, Sendable {
    public var speedUnit: String
    public var autoTripDetectionEnabled: Bool
    public var backgroundLocationEnabled: Bool
    public var backgroundAudioEnabled: Bool
    public var liveActivitiesEnabled: Bool
    public var externalDisplayConnected: Bool
    public var carPlaySceneConfigured: Bool
    public var localNetworkConfigured: Bool

    public init(
        speedUnit: String,
        autoTripDetectionEnabled: Bool,
        backgroundLocationEnabled: Bool,
        backgroundAudioEnabled: Bool,
        liveActivitiesEnabled: Bool,
        externalDisplayConnected: Bool,
        carPlaySceneConfigured: Bool,
        localNetworkConfigured: Bool
    ) {
        self.speedUnit = speedUnit
        self.autoTripDetectionEnabled = autoTripDetectionEnabled
        self.backgroundLocationEnabled = backgroundLocationEnabled
        self.backgroundAudioEnabled = backgroundAudioEnabled
        self.liveActivitiesEnabled = liveActivitiesEnabled
        self.externalDisplayConnected = externalDisplayConnected
        self.carPlaySceneConfigured = carPlaySceneConfigured
        self.localNetworkConfigured = localNetworkConfigured
    }
}

/// Redacted, zero-PII diagnostic snapshot assembled strictly on-device.
public struct SupportDiagnosticSnapshot: Equatable, Sendable {
    public var appName: String
    public var appVersion: String
    public var buildNumber: String
    public var osVersion: String
    public var deviceModel: String
    public var localeIdentifier: String
    public var appLanguage: String
    public var entitlementTier: String
    public var remainingFreeCastingMinutes: Int?
    public var playlistCount: Int
    public var importedChannelCount: Int
    public var favoriteChannelCount: Int
    public var mediaServerCount: Int
    public var capabilities: SupportDiagnosticCapabilities
    public var generatedAt: Date

    public init(
        appName: String,
        appVersion: String,
        buildNumber: String,
        osVersion: String,
        deviceModel: String,
        localeIdentifier: String,
        appLanguage: String,
        entitlementTier: String,
        remainingFreeCastingMinutes: Int?,
        playlistCount: Int,
        importedChannelCount: Int,
        favoriteChannelCount: Int,
        mediaServerCount: Int,
        capabilities: SupportDiagnosticCapabilities,
        generatedAt: Date = Date()
    ) {
        self.appName = appName
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.localeIdentifier = localeIdentifier
        self.appLanguage = appLanguage
        self.entitlementTier = entitlementTier
        self.remainingFreeCastingMinutes = remainingFreeCastingMinutes
        self.playlistCount = playlistCount
        self.importedChannelCount = importedChannelCount
        self.favoriteChannelCount = favoriteChannelCount
        self.mediaServerCount = mediaServerCount
        self.capabilities = capabilities
        self.generatedAt = generatedAt
    }
}

/// Builds redacted on-device diagnostic reports, `.txt` export files, and `mailto:` support URLs.
public enum SupportDiagnosticsBuilder {
    private static let maxMailtoBodyLength = 6000

    private static let redactionPatterns: [(pattern: String, replacement: String)] = [
        (#"(?i)\b(?:https?|rtsp|rtmp|udp|ftp)://[^\s<>\"']+"#, "[REDACTED_URL]"),
        (#"(?i)\bbearer\s+[A-Za-z0-9._\-+/=]+"#, "[REDACTED_SECRET]"),
        (#"(?i)\b(?:token|password|passwd|secret|api[_-]?key|x-api-key|x-plex-token|access_token)\s*[:=]\s*[^\s,;\"']+"#, "[REDACTED_SECRET]"),
        (#"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#, "[REDACTED_EMAIL]"),
        (#"\b(?:\d{1,3}\.){3}\d{1,3}(?::\d{1,5})?\b"#, "[REDACTED_IP]")
    ]

    /// Captures the current non-sensitive app and device state without touching user PII, URLs, or secrets.
    @MainActor
    public static func captureCurrent(
        bundle: Bundle = .main,
        persistence: PersistenceController = .shared,
        appState: AppState = .shared,
        entitlementGate: EntitlementGate = .shared,
        playlistStore: PlaylistStore = .shared,
        mediaServerStore: MediaServerStore = .shared,
        externalDisplayManager: ExternalDisplayManager = .shared,
        now: Date = Date()
    ) -> SupportDiagnosticSnapshot {
        let info = bundle.infoDictionary ?? [:]
        let appName = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? "DashCast"
        let appVersion = (info["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        let buildNumber = (info["CFBundleVersion"] as? String) ?? "1"

        let device = UIDevice.current
        let osVersion = "\(device.systemName) \(device.systemVersion)"
        let hardwareModel = deviceHardwareIdentifier()

        let backgroundModes = info["UIBackgroundModes"] as? [String] ?? []
        let sceneManifest = info["UIApplicationSceneManifest"] as? [String: Any]
        let sceneConfigs = sceneManifest?["UISceneConfigurations"] as? [String: Any]
        let carPlayConfigured = sceneConfigs?["CPTemplateApplicationSceneSessionRoleApplication"] != nil

        let prefs = persistence.loadUserPreferences()
        let isPro = entitlementGate.isPro || appState.isProLifetimeUnlocked
        let tier = isPro ? "pro.lifetime" : "free"
        let remainingMinutes = isPro ? nil : entitlementGate.remainingCastingMinutes

        let capabilities = SupportDiagnosticCapabilities(
            speedUnit: appState.useMilesPerHour ? "MPH" : "KM/H",
            autoTripDetectionEnabled: prefs.autoTripDetectionEnabled ?? prefs.autoDetectDrives,
            backgroundLocationEnabled: backgroundModes.contains("location"),
            backgroundAudioEnabled: backgroundModes.contains("audio"),
            liveActivitiesEnabled: (info["NSSupportsLiveActivities"] as? Bool) ?? false,
            externalDisplayConnected: externalDisplayManager.isExternalDisplayConnected,
            carPlaySceneConfigured: carPlayConfigured,
            localNetworkConfigured: info["NSLocalNetworkUsageDescription"] != nil
        )

        return SupportDiagnosticSnapshot(
            appName: appName,
            appVersion: appVersion,
            buildNumber: buildNumber,
            osVersion: osVersion,
            deviceModel: hardwareModel,
            localeIdentifier: Locale.current.identifier,
            appLanguage: appState.appLanguage,
            entitlementTier: tier,
            remainingFreeCastingMinutes: remainingMinutes,
            playlistCount: playlistStore.playlists.count,
            importedChannelCount: playlistStore.importedChannels.count,
            favoriteChannelCount: playlistStore.favoriteChannels.count,
            mediaServerCount: mediaServerStore.accounts.count,
            capabilities: capabilities,
            generatedAt: now
        )
    }

    /// Returns the hardware machine identifier (e.g. `iPhone17,1`, `arm64`) rather than the user-assigned device name.
    public static func deviceHardwareIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { partial, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            partial.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }

    /// Strips URLs, credentials/tokens, emails, and IP addresses from diagnostic strings.
    public static func redact(_ input: String) -> String {
        var result = input
        for rule in redactionPatterns {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rule.replacement)
        }
        return result
    }

    /// Formats a redacted, zero-PII plain-text diagnostic report suitable for `.txt` export or email body inclusion.
    public static func buildReport(from snapshot: SupportDiagnosticSnapshot) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        let timestamp = iso.string(from: snapshot.generatedAt)

        let tierLine: String
        if let minutes = snapshot.remainingFreeCastingMinutes {
            tierLine = "\(redact(snapshot.entitlementTier)) (remaining_daily_minutes=\(max(0, minutes)))"
        } else {
            tierLine = redact(snapshot.entitlementTier)
        }

        let caps = snapshot.capabilities
        let lines: [String] = [
            "=== DashCast Diagnostic Report (Redacted) ===",
            "Generated: \(timestamp)",
            "App: \(redact(snapshot.appName)) \(redact(snapshot.appVersion)) (\(redact(snapshot.buildNumber)))",
            "OS: \(redact(snapshot.osVersion))",
            "Device: \(redact(snapshot.deviceModel))",
            "Locale: \(redact(snapshot.localeIdentifier)) | AppLanguage: \(redact(snapshot.appLanguage))",
            "Plan: \(tierLine)",
            "Playlists: \(max(0, snapshot.playlistCount))",
            "ImportedChannels: \(max(0, snapshot.importedChannelCount))",
            "Favorites: \(max(0, snapshot.favoriteChannelCount))",
            "MediaServersConfigured: \(max(0, snapshot.mediaServerCount))",
            "Capabilities:",
            "  - SpeedUnit: \(redact(caps.speedUnit))",
            "  - AutoTripDetection: \(caps.autoTripDetectionEnabled)",
            "  - BackgroundLocation: \(caps.backgroundLocationEnabled)",
            "  - BackgroundAudio: \(caps.backgroundAudioEnabled)",
            "  - LiveActivities: \(caps.liveActivitiesEnabled)",
            "  - ExternalDisplayConnected: \(caps.externalDisplayConnected)",
            "  - CarPlaySceneConfigured: \(caps.carPlaySceneConfigured)",
            "  - LocalNetworkConfigured: \(caps.localNetworkConfigured)",
            "Privacy: Zero PII, zero stream URLs, zero server addresses or tokens included."
        ]
        return lines.joined(separator: "\n")
    }

    /// Writes the diagnostic report to a temporary `.txt` file for sharing via `ShareLink` or `UIActivityViewController`.
    public static func exportReportFile(
        report: String,
        directory: URL? = nil,
        now: Date = Date()
    ) throws -> URL {
        let targetDir = directory ?? FileManager.default.temporaryDirectory
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        let fileName = "DashCast-Diagnostics-\(formatter.string(from: now)).txt"
        let fileURL = targetDir.appendingPathComponent(fileName)
        try report.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    /// Builds a properly percent-encoded `mailto:` URL targeting `LegalLinks.supportEmail`.
    public static func buildMailtoURL(
        recipient: String = LegalLinks.supportEmail,
        category: FeedbackCategory = .bug,
        appVersion: String? = nil,
        message: String,
        contactInfo: String = "",
        diagnosticReport: String? = nil,
        screenshotCount: Int = 0
    ) -> URL? {
        let trimmedRecipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRecipient.isEmpty else { return nil }

        let versionSuffix = appVersion.map { " (v\($0))" } ?? ""
        let subject = "[DashCast Support] \(category.rawValue)\(versionSuffix)"

        let body = buildComposeBody(
            category: category,
            message: message,
            contactInfo: contactInfo,
            diagnosticReport: diagnosticReport,
            screenshotCount: screenshotCount,
            maxLength: maxMailtoBodyLength
        )

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = trimmedRecipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }

    /// Formats the plain-text support message body shared across Mail and the system Share Sheet.
    public static func buildComposeBody(
        category: FeedbackCategory,
        message: String,
        contactInfo: String,
        diagnosticReport: String?,
        screenshotCount: Int = 0,
        maxLength: Int? = nil
    ) -> String {
        var sections: [String] = [
            "Category: \(category.rawValue)",
            "",
            message.trimmingCharacters(in: .whitespacesAndNewlines)
        ]

        let trimmedContact = contactInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContact.isEmpty {
            sections.append("")
            sections.append("Reply-To: \(trimmedContact)")
        }

        if screenshotCount > 0 {
            sections.append("")
            sections.append("Selected Screenshots: \(screenshotCount) (attach via Share Sheet if Mail doesn't pre-attach images)")
        }

        if let diagnosticReport, !diagnosticReport.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("")
            sections.append(diagnosticReport)
        }

        let joined = sections.joined(separator: "\n")
        if let maxLength, joined.count > maxLength {
            let prefixCount = max(0, maxLength - 3)
            return String(joined.prefix(prefixCount)) + "..."
        }
        return joined
    }
}
