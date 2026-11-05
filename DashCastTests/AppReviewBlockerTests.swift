import XCTest
@testable import DashCast

/// Session 21: App Review blockers on the classic UI (legal links, paywall wording, bundle hygiene, welcome tour replay).
final class AppReviewBlockerTests: XCTestCase {

    // MARK: Legal links

    func testLegalLinksAreHTTPS() {
        for url in [LegalLinks.termsOfUse, LegalLinks.privacyPolicy, LegalLinks.support] {
            XCTAssertEqual(url.scheme, "https", "\(url) must be https")
            XCTAssertNotNil(url.host)
        }
    }

    func testPaywallUsesTheSameLegalLinksAsMe() {
        XCTAssertEqual(PaywallLegal.termsOfUse, LegalLinks.termsOfUse)
        XCTAssertEqual(PaywallLegal.privacyPolicy, LegalLinks.privacyPolicy)
    }

    // MARK: One-time purchase only

    func testProProductIsTheLifetimeNonConsumable() throws {
        XCTAssertEqual(ProProduct.lifetime.rawValue, "pro.lifetime")
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "DashCastStore", withExtension: "storekit"))
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("\"NonConsumable\""))
        XCTAssertTrue(text.contains("\"19.99\""))
        XCTAssertFalse(text.contains("RecurringSubscription"), "No subscriptions (D1)")
    }

    // MARK: Bundle hygiene

    func testReferenceMediaIsNotBundled() throws {
        let root = try XCTUnwrap(Bundle.main.resourceURL)
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var offenders: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            let name = url.lastPathComponent.lowercased()
            if ["mediatoanalyze", "screenshots", "referencemedia"].contains(name)
                || name.contains("cardash") || name.contains("cartv") {
                offenders.append(url.path.replacingOccurrences(of: root.path, with: ""))
            }
        }
        XCTAssertEqual(offenders, [], "Reference/competitor media must not ship in the app bundle")
    }

    // MARK: Replay welcome tour

    func testReplayWelcomeTourClearsAcceptance() throws {
        let suite = "AppReviewBlockerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertTrue(PassengerSafetyNotice.needsWelcomeTour(defaults: defaults))
        defaults.set(true, forKey: PassengerSafetyNotice.acceptedKey)
        XCTAssertFalse(PassengerSafetyNotice.needsWelcomeTour(defaults: defaults))

        PassengerSafetyNotice.replayWelcomeTour(defaults: defaults)
        XCTAssertTrue(PassengerSafetyNotice.needsWelcomeTour(defaults: defaults))
        XCTAssertFalse(defaults.bool(forKey: PassengerSafetyNotice.acceptedKey))
    }
}
