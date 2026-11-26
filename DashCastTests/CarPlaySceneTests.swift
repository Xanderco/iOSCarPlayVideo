import XCTest
import CarPlay
@testable import DashCast

/// Checks what the CarPlay simulator needs to show DashCast: the scene manifest
/// entry pointing at our delegate, and the templates it builds.
@MainActor
final class CarPlaySceneTests: XCTestCase {

    func testSceneManifestDeclaresCarPlaySceneWithOurDelegate() throws {
        let info = try XCTUnwrap(Bundle.main.infoDictionary)
        let manifest = try XCTUnwrap(info["UIApplicationSceneManifest"] as? [String: Any])
        let configurations = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: Any])
        let carPlay = try XCTUnwrap(configurations["CPTemplateApplicationSceneSessionRoleApplication"] as? [[String: Any]])
        let className = try XCTUnwrap(carPlay.first?["UISceneDelegateClassName"] as? String)
        let resolved = try XCTUnwrap(NSClassFromString(className), "Scene delegate class \(className) not found")
        XCTAssertTrue(resolved == CarPlaySceneDelegate.self)
    }

    func testTabsAreLibraryFavoritesNowPlayingCast() {
        let titles = [
            CarPlaySceneDelegate.libraryTemplate().tabTitle,
            CarPlaySceneDelegate.favoritesTemplate().tabTitle,
            CarPlaySceneDelegate.mirrorInstructionsTemplate().tabTitle
        ]
        XCTAssertEqual(titles, ["Library", "Favorites", "Cast"])
    }

    func testMirrorInstructionsScreenListsTheSteps() {
        let template = CarPlaySceneDelegate.mirrorInstructionsTemplate()
        XCTAssertEqual(template.title, "Mirror iPhone")
        let items = template.sections.first?.items.compactMap { $0 as? CPListItem } ?? []
        XCTAssertEqual(items.count, CarPlaySceneDelegate.mirrorInstructionSteps.count)
        XCTAssertEqual(items.first?.text, "Open DashCast on your iPhone")
        XCTAssertTrue(items.allSatisfy { !$0.isEnabled })
    }

    func testCastTabOffersShowIPhoneScreenAction() {
        var tapped = false
        let template = CarPlaySceneDelegate.mirrorInstructionsTemplate { tapped = true }
        XCTAssertEqual(template.sections.count, 2)
        let action = template.sections.last?.items.first as? CPListItem
        XCTAssertEqual(action?.text, CarPlaySceneDelegate.mirrorActionTitle)
        action?.handler?(action!) {}
        XCTAssertTrue(tapped)
    }

    func testCarPlaySceneCopyGroupTitleAndChannelCountPluralization() {
        XCTAssertEqual(CarPlaySceneCopy.groupTitle(""), CarPlaySceneCopy.otherGroupTitle)
        XCTAssertEqual(CarPlaySceneCopy.groupTitle("Sports"), "Sports")

        XCTAssertEqual(CarPlaySceneCopy.channelCountText(1), String(localized: "1 channel"))
        XCTAssertEqual(CarPlaySceneCopy.channelCountText(0), String(localized: "\(0) channels"))
        XCTAssertEqual(CarPlaySceneCopy.channelCountText(5), String(localized: "\(5) channels"))
        XCTAssertEqual(CarPlaySceneCopy.channelCountText(-3), String(localized: "\(0) channels"))
    }

    func testCarPlaySceneCopyInfoAndMirrorStrings() {
        XCTAssertEqual(CarPlaySceneCopy.infoRows.count, 2)
        XCTAssertFalse(CarPlaySceneCopy.infoRows[0].title.isEmpty)
        XCTAssertFalse(CarPlaySceneCopy.infoRows[0].detail.isEmpty)
        XCTAssertFalse(CarPlaySceneCopy.infoRows[1].title.isEmpty)
        XCTAssertFalse(CarPlaySceneCopy.infoRows[1].detail.isEmpty)

        XCTAssertEqual(CarPlaySceneCopy.mirrorInstructionSteps.count, 3)
        XCTAssertEqual(CarPlaySceneDelegate.mirrorActionTitle, CarPlaySceneCopy.mirrorActionTitle)
        XCTAssertEqual(CarPlaySceneDelegate.mirrorInstructionSteps.count, CarPlaySceneCopy.mirrorInstructionSteps.count)
    }

    func testCarPlayLocalizationKeysExistInCatalog() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = Bundle(for: CarPlaySceneTests.self).url(forResource: "Localizable", withExtension: "xcstrings")
            ?? projectDir
                .appendingPathComponent("DashCast")
                .appendingPathComponent("Resources")
                .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])

        for key in CarPlaySceneCopy.allLocalizationKeys {
            let entry = try XCTUnwrap(strings[key], "Missing key in Localizable.xcstrings: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]])
            let enValue = ((localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            let esValue = ((localizations["es"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            XCTAssertFalse(enValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Missing EN for \(key)")
            XCTAssertFalse(esValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Missing ES for \(key)")
        }
    }
}
