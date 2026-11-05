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
}
