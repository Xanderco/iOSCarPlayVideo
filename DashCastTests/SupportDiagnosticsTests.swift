import XCTest
@testable import DashCast

final class SupportDiagnosticsTests: XCTestCase {

    func testBuildReportIncludesMetadataTierCountsAndCapabilities() {
        let fixedDate = Date(timeIntervalSince1970: 1_764_000_000)
        let snapshot = SupportDiagnosticSnapshot(
            appName: "DashCast",
            appVersion: "1.0.0",
            buildNumber: "42",
            osVersion: "iOS 18.2",
            deviceModel: "iPhone17,1",
            localeIdentifier: "en_US",
            appLanguage: "en",
            entitlementTier: "free",
            remainingFreeCastingMinutes: 9,
            playlistCount: 1,
            importedChannelCount: 14,
            favoriteChannelCount: 3,
            mediaServerCount: 2,
            capabilities: SupportDiagnosticCapabilities(
                speedUnit: "MPH",
                autoTripDetectionEnabled: true,
                backgroundLocationEnabled: true,
                backgroundAudioEnabled: true,
                liveActivitiesEnabled: true,
                externalDisplayConnected: false,
                carPlaySceneConfigured: true,
                localNetworkConfigured: true
            ),
            generatedAt: fixedDate
        )

        let report = SupportDiagnosticsBuilder.buildReport(from: snapshot)

        XCTAssertTrue(report.contains("=== DashCast Diagnostic Report (Redacted) ==="))
        XCTAssertTrue(report.contains("App: DashCast 1.0.0 (42)"))
        XCTAssertTrue(report.contains("OS: iOS 18.2"))
        XCTAssertTrue(report.contains("Device: iPhone17,1"))
        XCTAssertTrue(report.contains("Plan: free (remaining_daily_minutes=9)"))
        XCTAssertTrue(report.contains("Playlists: 1"))
        XCTAssertTrue(report.contains("ImportedChannels: 14"))
        XCTAssertTrue(report.contains("Favorites: 3"))
        XCTAssertTrue(report.contains("MediaServersConfigured: 2"))
        XCTAssertTrue(report.contains("SpeedUnit: MPH"))
        XCTAssertTrue(report.contains("AutoTripDetection: true"))
        XCTAssertTrue(report.contains("CarPlaySceneConfigured: true"))
    }

    func testBuildReportProTierOmitsRemainingMinutes() {
        let snapshot = SupportDiagnosticSnapshot(
            appName: "DashCast",
            appVersion: "1.0.0",
            buildNumber: "43",
            osVersion: "iOS 18.2",
            deviceModel: "iPhone17,2",
            localeIdentifier: "es_CO",
            appLanguage: "es",
            entitlementTier: "pro.lifetime",
            remainingFreeCastingMinutes: nil,
            playlistCount: 5,
            importedChannelCount: 120,
            favoriteChannelCount: 12,
            mediaServerCount: 3,
            capabilities: SupportDiagnosticCapabilities(
                speedUnit: "KM/H",
                autoTripDetectionEnabled: false,
                backgroundLocationEnabled: true,
                backgroundAudioEnabled: true,
                liveActivitiesEnabled: true,
                externalDisplayConnected: true,
                carPlaySceneConfigured: false,
                localNetworkConfigured: true
            ),
            generatedAt: Date(timeIntervalSince1970: 1_764_000_000)
        )

        let report = SupportDiagnosticsBuilder.buildReport(from: snapshot)

        XCTAssertTrue(report.contains("Plan: pro.lifetime\n"))
        XCTAssertFalse(report.contains("remaining_daily_minutes"))
    }

    func testRedactStripsURLsTokensEmailsAndIPAddresses() {
        let dirty = """
        url=https://user:superpass@iptv.example.com:8080/live/playlist.m3u8?token=abc123
        rtsp=rtsp://192.168.1.55:554/stream1
        auth=Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig
        plex=X-Plex-Token=deadbeef987654
        mail=driver.name@example.org
        host=10.0.0.24:8096
        """

        let redacted = SupportDiagnosticsBuilder.redact(dirty)

        XCTAssertFalse(redacted.contains("superpass"))
        XCTAssertFalse(redacted.contains("iptv.example.com"))
        XCTAssertFalse(redacted.contains("192.168.1.55"))
        XCTAssertFalse(redacted.contains("eyJhbGciOi"))
        XCTAssertFalse(redacted.contains("deadbeef987654"))
        XCTAssertFalse(redacted.contains("driver.name@example.org"))
        XCTAssertFalse(redacted.contains("10.0.0.24"))
        XCTAssertTrue(redacted.contains("[REDACTED_URL]"))
        XCTAssertTrue(redacted.contains("[REDACTED_SECRET]"))
        XCTAssertTrue(redacted.contains("[REDACTED_EMAIL]"))
        XCTAssertTrue(redacted.contains("[REDACTED_IP]"))
    }

    func testBuildReportRedactsDirtyFieldsInsideSnapshot() {
        let dirtySnapshot = SupportDiagnosticSnapshot(
            appName: "DashCast https://secret.example.com/m3u",
            appVersion: "1.0.0 token=mysecret123",
            buildNumber: "192.168.1.99",
            osVersion: "iOS 18.2",
            deviceModel: "alex.benitez@example.com",
            localeIdentifier: "en_US",
            appLanguage: "en",
            entitlementTier: "free",
            remainingFreeCastingMinutes: 15,
            playlistCount: 1,
            importedChannelCount: 0,
            favoriteChannelCount: 0,
            mediaServerCount: 1,
            capabilities: SupportDiagnosticCapabilities(
                speedUnit: "KM/H",
                autoTripDetectionEnabled: true,
                backgroundLocationEnabled: true,
                backgroundAudioEnabled: true,
                liveActivitiesEnabled: true,
                externalDisplayConnected: false,
                carPlaySceneConfigured: true,
                localNetworkConfigured: true
            ),
            generatedAt: Date(timeIntervalSince1970: 1_764_000_000)
        )

        let report = SupportDiagnosticsBuilder.buildReport(from: dirtySnapshot)

        XCTAssertFalse(report.contains("secret.example.com"))
        XCTAssertFalse(report.contains("mysecret123"))
        XCTAssertFalse(report.contains("192.168.1.99"))
        XCTAssertFalse(report.contains("alex.benitez@example.com"))
    }

    func testExportReportFileWritesReadableTextFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SupportDiagnosticsTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let report = "=== DashCast Diagnostic Report (Redacted) ===\nApp: DashCast 1.0.0 (1)"
        let fixedDate = Date(timeIntervalSince1970: 1_764_000_000)

        let fileURL = try SupportDiagnosticsBuilder.exportReportFile(
            report: report,
            directory: tempDir,
            now: fixedDate
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(fileURL.pathExtension, "txt")
        XCTAssertTrue(fileURL.lastPathComponent.hasPrefix("DashCast-Diagnostics-"))

        let readBack = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(readBack, report)
    }

    func testBuildMailtoURLConstructsValidEncodedMailtoLink() {
        let report = "=== DashCast Diagnostic Report (Redacted) ===\nPlan: free"
        let url = SupportDiagnosticsBuilder.buildMailtoURL(
            recipient: LegalLinks.supportEmail,
            category: .playback,
            appVersion: "1.0.0",
            message: "Stream buffers after 30 seconds on Car Display.",
            contactInfo: "test@example.com",
            diagnosticReport: report,
            screenshotCount: 2
        )

        XCTAssertNotNil(url)
        guard let url else { return }

        XCTAssertEqual(url.scheme, "mailto")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.path, LegalLinks.supportEmail)

        let subject = components?.queryItems?.first(where: { $0.name == "subject" })?.value
        let body = components?.queryItems?.first(where: { $0.name == "body" })?.value

        XCTAssertEqual(subject, "[DashCast Support] Playback Issue (v1.0.0)")
        XCTAssertNotNil(body)
        XCTAssertTrue(body?.contains("Category: Playback Issue") == true)
        XCTAssertTrue(body?.contains("Stream buffers after 30 seconds on Car Display.") == true)
        XCTAssertTrue(body?.contains("Reply-To: test@example.com") == true)
        XCTAssertTrue(body?.contains("Selected Screenshots: 2") == true)
        XCTAssertTrue(body?.contains("Plan: free") == true)
    }

    func testBuildMailtoURLReturnsNilForBlankRecipientAndTruncatesLongBody() {
        let blank = SupportDiagnosticsBuilder.buildMailtoURL(
            recipient: "   ",
            message: "Valid feedback message"
        )
        XCTAssertNil(blank)

        let hugeMessage = String(repeating: "a", count: 8000)
        let url = SupportDiagnosticsBuilder.buildMailtoURL(
            recipient: LegalLinks.supportEmail,
            message: hugeMessage
        )
        let components = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let body = components?.queryItems?.first(where: { $0.name == "body" })?.value
        XCTAssertNotNil(body)
        XCTAssertLessThanOrEqual(body?.count ?? Int.max, 6000)
        XCTAssertTrue(body?.hasSuffix("...") == true)
    }

    @MainActor
    func testCaptureCurrentProducesSafeReport() {
        let snapshot = SupportDiagnosticsBuilder.captureCurrent()
        let report = SupportDiagnosticsBuilder.buildReport(from: snapshot)

        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("DashCast"))
        XCTAssertFalse(report.contains("http://"))
        XCTAssertFalse(report.contains("https://"))
    }
}
