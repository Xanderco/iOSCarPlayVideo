import XCTest
import Combine
@testable import DashCast

@MainActor
final class EntitlementGateTests: XCTestCase {
    private let pro = CurrentValueSubject<Bool, Never>(false)
    private var now: Date = ISO8601DateFormatter().date(from: "2026-11-05T10:00:00Z")!
    private var blocked: [EntitlementGate.Decision] = []
    private lazy var defaults: UserDefaults = {
        let suite = "EntitlementGateTests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        return UserDefaults(suiteName: suite)!
    }()

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func makeGate(limits: EntitlementGate.FreeTierLimits = .standard) -> EntitlementGate {
        EntitlementGate(isProPublisher: pro.eraseToAnyPublisher(),
                        limits: limits,
                        defaults: defaults,
                        calendar: calendar,
                        now: { [unowned self] in self.now },
                        onBlocked: { [unowned self] in self.blocked.append($0) })
    }

    func testStandardFreeTierLimits() {
        XCTAssertEqual(EntitlementGate.FreeTierLimits.standard.maxPlaylistSources, 1)
        XCTAssertEqual(EntitlementGate.FreeTierLimits.standard.dailyCastingMinutes, 15)
    }

    func testFreeUserGetsOnePlaylistSource() {
        let gate = makeGate()
        XCTAssertEqual(gate.check(.addPlaylistSource(existingCount: 0)), .allowed)
        XCTAssertEqual(gate.check(.addPlaylistSource(existingCount: 1)), .playlistLimitReached(limit: 1))
        XCTAssertTrue(blocked.isEmpty, "check() must not present the paywall")
    }

    func testRequestPresentsPaywallWhenBlocked() {
        let gate = makeGate()
        XCTAssertFalse(gate.request(.addPlaylistSource(existingCount: 1)))
        XCTAssertEqual(blocked, [.playlistLimitReached(limit: 1)])
        XCTAssertEqual(gate.lastBlock, .playlistLimitReached(limit: 1))
        XCTAssertNotNil(gate.lastBlock?.message)
    }

    func testProUserIsNeverBlocked() {
        let gate = makeGate()
        pro.send(true)
        XCTAssertTrue(gate.isPro)
        XCTAssertTrue(gate.request(.addPlaylistSource(existingCount: 50)))
        XCTAssertTrue(gate.recordCasting(seconds: 10_000))
        XCTAssertTrue(gate.request(.startCasting))
        XCTAssertEqual(gate.remainingCastingSeconds, .infinity)
        XCTAssertTrue(blocked.isEmpty)
    }

    func testCastingMinutesAccumulateAndBlock() {
        let gate = makeGate()
        XCTAssertEqual(gate.remainingCastingSeconds, 15 * 60)

        XCTAssertTrue(gate.recordCasting(seconds: 10 * 60))
        XCTAssertEqual(gate.remainingCastingSeconds, 5 * 60)
        XCTAssertEqual(gate.check(.startCasting), .allowed)

        XCTAssertFalse(gate.recordCasting(seconds: 6 * 60))
        XCTAssertEqual(gate.remainingCastingSeconds, 0)
        XCTAssertEqual(gate.castingSecondsUsedToday, 15 * 60)
        XCTAssertEqual(gate.check(.startCasting), .dailyCastingLimitReached(minutes: 15))
        XCTAssertEqual(blocked, [.dailyCastingLimitReached(minutes: 15)])
    }

    func testCastingUsagePersistsAcrossLaunchesAndResetsNextDay() {
        let gate = makeGate()
        gate.recordCasting(seconds: 15 * 60)

        let relaunched = makeGate()
        XCTAssertEqual(relaunched.remainingCastingSeconds, 0)

        now = now.addingTimeInterval(24 * 60 * 60)
        XCTAssertEqual(relaunched.remainingCastingSeconds, 15 * 60)
        XCTAssertEqual(relaunched.check(.startCasting), .allowed)
        relaunched.refreshUsage()
        XCTAssertEqual(relaunched.castingSecondsUsedToday, 0)
    }

    func testIgnoresInvalidDurations() {
        let gate = makeGate()
        gate.recordCasting(seconds: -30)
        gate.recordCasting(seconds: .nan)
        XCTAssertEqual(gate.remainingCastingSeconds, 15 * 60)
    }

    func testBecomingProClearsLastBlockAndLosingProRestoresLimits() {
        let gate = makeGate()
        gate.request(.addPlaylistSource(existingCount: 1))
        XCTAssertNotNil(gate.lastBlock)

        pro.send(true)
        XCTAssertNil(gate.lastBlock)

        pro.send(false) // e.g. refund
        XCTAssertFalse(gate.isPro)
        XCTAssertEqual(gate.check(.addPlaylistSource(existingCount: 1)), .playlistLimitReached(limit: 1))
    }
}
