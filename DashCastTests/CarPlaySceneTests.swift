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
}
