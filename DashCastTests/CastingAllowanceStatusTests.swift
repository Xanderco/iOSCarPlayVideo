import XCTest
import Combine
@testable import DashCast

@MainActor
final class CastingAllowanceStatusTests: XCTestCase {
    private let pro = CurrentValueSubject<Bool, Never>(false)
    private var now: Date = ISO8601DateFormatter().date(from: "2026-11-26T10:00:00Z")!

    private lazy var defaults: UserDefaults = {
        let suite = "CastingAllowanceStatusTests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        return UserDefaults(suiteName: suite)!
    }()

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func makeGate(limits: EntitlementGate.FreeTierLimits = .standard) -> EntitlementGate {
        EntitlementGate(
            isProPublisher: pro.eraseToAnyPublisher(),
            limits: limits,
            defaults: defaults,
            calendar: calendar,
            now: { [unowned self] in self.now }
        )
    }

    func testDurationFormatting() {
        XCTAssertEqual(CastingAllowanceStatus.formatDuration(900), "15:00")
        XCTAssertEqual(CastingAllowanceStatus.formatDuration(899.9), "14:59")
        XCTAssertEqual(CastingAllowanceStatus.formatDuration(300), "5:00")
        XCTAssertEqual(CastingAllowanceStatus.formatDuration(299.9), "4:59")
        XCTAssertEqual(CastingAllowanceStatus.formatDuration(65), "1:05")
        XCTAssertEqual(CastingAllowanceStatus.formatDuration(0.4), "0:01")
        XCTAssertEqual(CastingAllowanceStatus.formatDuration(0), "0:00")
        XCTAssertEqual(CastingAllowanceStatus.formatDuration(-12), "0:00")
        XCTAssertEqual(CastingAllowanceStatus.formatDuration(.nan), "0:00")
        XCTAssertEqual(CastingAllowanceStatus.formatDuration(.infinity), "∞")
    }

    func testStatesAcrossRemainingAllowanceThresholds() {
        let full = CastingAllowanceStatus(remainingSeconds: 900, totalSeconds: 900)
        XCTAssertEqual(full.state, .full)
        XCTAssertEqual(full.progress, 1.0, accuracy: 0.001)
        XCTAssertEqual(full.formattedRemaining, "15:00")
        XCTAssertEqual(full.remainingMinutes, 15)
        XCTAssertEqual(full.titleFormatKey, "Free casting · %@ daily")
        XCTAssertEqual(full.badgeFormatKey, "PRO")

        let normalBoundary = CastingAllowanceStatus(remainingSeconds: 300, totalSeconds: 900)
        XCTAssertEqual(normalBoundary.state, .normal)
        XCTAssertEqual(normalBoundary.progress, 1.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(normalBoundary.formattedRemaining, "5:00")
        XCTAssertEqual(normalBoundary.titleFormatKey, "Free casting · %@ left")

        let lowBoundary = CastingAllowanceStatus(remainingSeconds: 299.5, totalSeconds: 900)
        XCTAssertEqual(lowBoundary.state, .low)
        XCTAssertEqual(lowBoundary.formattedRemaining, "4:59")
        XCTAssertEqual(lowBoundary.titleFormatKey, "Low casting time · %@ left")
        XCTAssertEqual(lowBoundary.subtitleFormatKey, "Less than 5 min left today · Tap for Pro")

        let exhausted = CastingAllowanceStatus(remainingSeconds: 0, totalSeconds: 900)
        XCTAssertEqual(exhausted.state, .exhausted)
        XCTAssertEqual(exhausted.progress, 0.0, accuracy: 0.001)
        XCTAssertEqual(exhausted.formattedRemaining, "0:00")
        XCTAssertEqual(exhausted.remainingMinutes, 0)
        XCTAssertEqual(exhausted.titleFormatKey, "Daily free casting limit reached")
        XCTAssertEqual(exhausted.badgeFormatKey, "Unlock Pro")
    }

    func testGateIntegrationTracksUsageAndMidnightReset() {
        let gate = makeGate()

        var status = CastingAllowanceStatus(gate: gate)
        XCTAssertEqual(status.state, .full)
        XCTAssertEqual(status.formattedRemaining, "15:00")

        // Use 6 minutes -> 9:00 left (.normal)
        XCTAssertTrue(gate.recordCasting(seconds: 6 * 60))
        status = CastingAllowanceStatus(gate: gate)
        XCTAssertEqual(status.state, .normal)
        XCTAssertEqual(status.formattedRemaining, "9:00")
        XCTAssertEqual(status.progress, 0.6, accuracy: 0.001)

        // Use 5 more minutes -> 4:00 left (.low < 5 min)
        XCTAssertTrue(gate.recordCasting(seconds: 5 * 60))
        status = CastingAllowanceStatus(gate: gate)
        XCTAssertEqual(status.state, .low)
        XCTAssertEqual(status.formattedRemaining, "4:00")

        // Exhaust final 4 minutes -> 0:00 left (.exhausted)
        XCTAssertFalse(gate.recordCasting(seconds: 4 * 60))
        status = CastingAllowanceStatus(gate: gate)
        XCTAssertEqual(status.state, .exhausted)
        XCTAssertEqual(status.formattedRemaining, "0:00")
        XCTAssertEqual(status.progress, 0.0, accuracy: 0.001)

        // Next day resets back to full 15:00
        now = now.addingTimeInterval(24 * 60 * 60)
        gate.refreshUsage()
        status = CastingAllowanceStatus(gate: gate)
        XCTAssertEqual(status.state, .full)
        XCTAssertEqual(status.formattedRemaining, "15:00")
    }

    func testAllowanceBannerLocalizationKeysExistInCatalog() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectDir
            .appendingPathComponent("DashCast")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = try XCTUnwrap(json?["strings"] as? [String: [String: Any]])

        let statuses = [
            CastingAllowanceStatus(remainingSeconds: 900, totalSeconds: 900),
            CastingAllowanceStatus(remainingSeconds: 600, totalSeconds: 900),
            CastingAllowanceStatus(remainingSeconds: 180, totalSeconds: 900),
            CastingAllowanceStatus(remainingSeconds: 0, totalSeconds: 900)
        ]

        var expectedKeys = Set(["Opens DashCast Pro upgrade options"])
        for status in statuses {
            expectedKeys.insert(status.titleFormatKey)
            expectedKeys.insert(status.subtitleFormatKey)
            expectedKeys.insert(status.badgeFormatKey)
        }

        for key in expectedKeys {
            let entry = try XCTUnwrap(strings[key], "Missing Localizable.xcstrings key: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]])
            let enValue = (localizations["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
            let esValue = (localizations["es"]?["stringUnit"] as? [String: Any])?["value"] as? String
            XCTAssertFalse(enValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Empty EN value for \(key)")
            XCTAssertFalse(esValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Empty ES value for \(key)")
        }
    }
}
