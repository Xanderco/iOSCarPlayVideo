import XCTest
@testable import DashCast

final class LocalizationTests: XCTestCase {

    func testLocalizableXCStringsFileValidAndComplete() throws {
        // Find Localizable.xcstrings in Bundle or project directory
        let bundle = Bundle(for: LocalizationTests.self)
        var fileURL: URL? = bundle.url(forResource: "Localizable", withExtension: "xcstrings")

        if fileURL == nil {
            // Check direct resource path in test environment
            let projectDir = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let candidate = projectDir
                .appendingPathComponent("DashCast")
                .appendingPathComponent("Resources")
                .appendingPathComponent("Localizable.xcstrings")
            if FileManager.default.fileExists(atPath: candidate.path) {
                fileURL = candidate
            }
        }

        guard let catalogURL = fileURL else {
            XCTFail("Localizable.xcstrings not found")
            return
        }

        let data = try Data(contentsOf: catalogURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json, "Localizable.xcstrings must be valid JSON")

        XCTAssertEqual(json?["sourceLanguage"] as? String, "en")
        XCTAssertEqual(json?["version"] as? String, "1.0")

        guard let strings = json?["strings"] as? [String: [String: Any]] else {
            XCTFail("Missing 'strings' dictionary in Localizable.xcstrings")
            return
        }

        XCTAssertGreaterThan(strings.count, 200, "Should have extracted a comprehensive string catalog")

        var missingSpanish: [String] = []
        var emptyTranslations: [String] = []

        for (key, entry) in strings {
            guard let localizations = entry["localizations"] as? [String: [String: Any]] else {
                missingSpanish.append(key)
                continue
            }

            guard let esDict = localizations["es"] as? [String: Any],
                  let esUnit = esDict["stringUnit"] as? [String: Any],
                  let esValue = esUnit["value"] as? String else {
                missingSpanish.append(key)
                continue
            }

            if esValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyTranslations.append(key)
            }
        }

        XCTAssertTrue(missingSpanish.isEmpty, "Missing Spanish translations for: \(missingSpanish)")
        XCTAssertTrue(emptyTranslations.isEmpty, "Empty Spanish translations for: \(emptyTranslations)")
    }

    func testInfoPlistXCStringsValid() throws {
        let bundle = Bundle(for: LocalizationTests.self)
        var fileURL: URL? = bundle.url(forResource: "InfoPlist", withExtension: "xcstrings")

        if fileURL == nil {
            let projectDir = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let candidate = projectDir
                .appendingPathComponent("DashCast")
                .appendingPathComponent("Resources")
                .appendingPathComponent("InfoPlist.xcstrings")
            if FileManager.default.fileExists(atPath: candidate.path) {
                fileURL = candidate
            }
        }

        guard let catalogURL = fileURL else {
            XCTFail("InfoPlist.xcstrings not found")
            return
        }

        let data = try Data(contentsOf: catalogURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)

        guard let strings = json?["strings"] as? [String: [String: Any]] else {
            XCTFail("Missing 'strings' in InfoPlist.xcstrings")
            return
        }

        let requiredKeys = [
            "NSLocationWhenInUseUsageDescription",
            "NSLocationAlwaysAndWhenInUseUsageDescription",
            "NSMotionUsageDescription",
            "NSPhotoLibraryUsageDescription",
            "NSCameraUsageDescription"
        ]

        for req in requiredKeys {
            XCTAssertNotNil(strings[req], "Missing privacy description for \(req)")
            let localizations = strings[req]?["localizations"] as? [String: Any]
            let es = (localizations?["es"] as? [String: Any])?["stringUnit"] as? [String: Any]
            let esVal = es?["value"] as? String
            XCTAssertFalse(esVal?.isEmpty ?? true, "Missing Spanish translation for \(req)")
        }
    }

    @MainActor
    func testAppStateLanguageSwitching() {
        let appState = AppState.shared
        let originalLanguage = appState.appLanguage

        appState.setLanguage("es")
        XCTAssertEqual(appState.appLanguage, "es")
        XCTAssertEqual(appState.effectiveLocale?.identifier, "es")

        appState.setLanguage("en")
        XCTAssertEqual(appState.appLanguage, "en")
        XCTAssertEqual(appState.effectiveLocale?.identifier, "en")

        appState.setLanguage("system")
        XCTAssertEqual(appState.appLanguage, "system")
        XCTAssertNil(appState.effectiveLocale)

        // Restore
        appState.setLanguage(originalLanguage)
    }

    func testTabItemLocalizations() {
        for tab in AppState.TabItem.allCases {
            XCTAssertNotNil(tab.localizedTitle)
        }
    }

    @MainActor
    func testWelcomeOnboardingCopyAndLocalizationKeys() throws {
        XCTAssertEqual(
            WelcomeOnboardingCopy.primaryTitleKeyName(page: 0, safetyPage: 3, pageCount: 5, acknowledgedSafety: false),
            "Continue"
        )
        XCTAssertEqual(
            WelcomeOnboardingCopy.primaryTitleKeyName(page: 2, safetyPage: 3, pageCount: 5, acknowledgedSafety: true),
            "Continue"
        )
        XCTAssertEqual(
            WelcomeOnboardingCopy.primaryTitleKeyName(page: 3, safetyPage: 3, pageCount: 5, acknowledgedSafety: false),
            "Please confirm above"
        )
        XCTAssertEqual(
            WelcomeOnboardingCopy.primaryTitleKeyName(page: 3, safetyPage: 3, pageCount: 5, acknowledgedSafety: true),
            "I understand"
        )
        XCTAssertEqual(
            WelcomeOnboardingCopy.primaryTitleKeyName(page: 4, safetyPage: 3, pageCount: 5, acknowledgedSafety: true),
            "See DashCast Pro"
        )
        _ = WelcomeOnboardingCopy.primaryTitle(page: 3, safetyPage: 3, pageCount: 5, acknowledgedSafety: true)

        try assertCatalogContainsENAndES(keys: WelcomeOnboardingCopy.allLocalizationKeys)
    }

    @MainActor
    func testLifetimePaywallCopyAndLocalizationKeys() throws {
        XCTAssertNil(PaywallCopy.limitBannerKeyName(for: .allowed))
        XCTAssertNil(PaywallCopy.limitBannerKey(for: .allowed))

        XCTAssertEqual(
            PaywallCopy.limitBannerKeyName(for: .playlistLimitReached(limit: 1)),
            "The free plan includes 1 playlist source."
        )
        XCTAssertEqual(
            PaywallCopy.limitBannerKeyName(for: .playlistLimitReached(limit: 3)),
            "The free plan includes %lld playlist sources."
        )
        XCTAssertEqual(
            PaywallCopy.limitBannerKeyName(for: .dailyCastingLimitReached(minutes: 15)),
            "You've used today's %lld free casting minutes. They reset at midnight."
        )
        XCTAssertNotNil(PaywallCopy.limitBannerKey(for: .dailyCastingLimitReached(minutes: 15)))

        XCTAssertEqual(PaywallCopy.purchaseButtonKeyName(isPurchasing: true), "Contacting the App Store…")
        XCTAssertEqual(PaywallCopy.purchaseButtonKeyName(isPurchasing: false), "Unlock Pro for %@")
        _ = PaywallCopy.purchaseButtonTitle(isPurchasing: false, price: "$19.99")

        XCTAssertEqual(PaywallCopy.restoreButtonKeyName(isRestoring: true), "Restoring…")
        XCTAssertEqual(PaywallCopy.restoreButtonKeyName(isRestoring: false), "Restore Purchases")
        _ = PaywallCopy.restoreButtonTitle(isRestoring: false)

        XCTAssertEqual(PaywallAlert.purchased.titleKeyName, "Welcome to DashCast Pro")
        XCTAssertEqual(
            PaywallAlert.purchased.messageKeyName,
            "Pro is unlocked on this device and on any device signed in to your Apple Account."
        )
        XCTAssertTrue(PaywallAlert.purchased.dismissesPaywall)

        XCTAssertEqual(PaywallAlert.restored.titleKeyName, "Purchase Restored")
        XCTAssertEqual(PaywallAlert.restored.messageKeyName, "DashCast Pro is unlocked again.")
        XCTAssertTrue(PaywallAlert.restored.dismissesPaywall)

        XCTAssertEqual(PaywallAlert.pending.titleKeyName, "Waiting for Approval")
        XCTAssertEqual(
            PaywallAlert.pending.messageKeyName,
            "Your purchase is waiting for approval. Pro unlocks automatically once it's approved."
        )
        XCTAssertFalse(PaywallAlert.pending.dismissesPaywall)

        XCTAssertEqual(PaywallAlert.nothingToRestore.titleKeyName, "Nothing to Restore")
        XCTAssertEqual(
            PaywallAlert.nothingToRestore.messageKeyName,
            "No DashCast Pro purchase was found for this Apple Account."
        )
        XCTAssertFalse(PaywallAlert.nothingToRestore.dismissesPaywall)

        XCTAssertEqual(PaywallAlert.error("Network down").titleKeyName, "Something Went Wrong")
        XCTAssertNil(PaywallAlert.error("Network down").messageKeyName)
        XCTAssertFalse(PaywallAlert.error("Network down").dismissesPaywall)

        try assertCatalogContainsENAndES(keys: PaywallCopy.allLocalizationKeys)
    }

    private func assertCatalogContainsENAndES(keys: [String]) throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = Bundle(for: LocalizationTests.self).url(forResource: "Localizable", withExtension: "xcstrings")
            ?? projectDir
                .appendingPathComponent("DashCast")
                .appendingPathComponent("Resources")
                .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])

        for key in keys {
            let entry = try XCTUnwrap(strings[key], "Missing key in Localizable.xcstrings: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]], "Missing localizations for \(key)")
            let enValue = ((localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            let esValue = ((localizations["es"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            XCTAssertFalse(enValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Missing EN for \(key)")
            XCTAssertFalse(esValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Missing ES for \(key)")
        }
    }
}
