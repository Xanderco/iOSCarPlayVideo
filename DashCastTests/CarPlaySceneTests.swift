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
            CarPlaySceneDelegate.infoTemplate().tabTitle,
            CarPlaySceneDelegate.mirrorInstructionsTemplate().tabTitle
        ]
        XCTAssertEqual(titles, ["Library", "Favorites", "Info", "Cast"])
    }

    func testMirrorInstructionsScreenListsTheSteps() {
        let template = CarPlaySceneDelegate.mirrorInstructionsTemplate()
        XCTAssertEqual(template.title, "Screen Mirror")
        let items = template.sections.first?.items.compactMap { $0 as? CPListItem } ?? []
        XCTAssertEqual(items.count, CarPlaySceneDelegate.mirrorInstructionSteps.count)
        XCTAssertEqual(items.first?.text, "Parked setup required")
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

    func testCarPlayTemplatesContainNoIPhoneInstructions() {
        let delegate = CarPlaySceneDelegate()
        let suite = "CarPlaySceneTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: suite)
        }
        let store = PlaylistStore(persistence: PersistenceController(userDefaults: defaults), defaults: defaults)
        if let first = store.sampleChannels.first {
            store.recordRecentChannel(first)
        }

        let library = CarPlaySceneDelegate.libraryTemplate()
        library.updateSections(delegate.makeLibrarySections(store: store))

        let templates: [CPListTemplate] = [
            library,
            CarPlaySceneDelegate.favoritesTemplate(),
            CarPlaySceneDelegate.infoTemplate(),
            CarPlaySceneDelegate.mirrorInstructionsTemplate(onMirror: {})
        ]

        var collectedCopy: [String] = []
        for template in templates {
            if let title = template.title { collectedCopy.append(title) }
            if let tabTitle = template.tabTitle { collectedCopy.append(tabTitle) }
            collectedCopy.append(contentsOf: template.emptyViewTitleVariants)
            collectedCopy.append(contentsOf: template.emptyViewSubtitleVariants)
            for section in template.sections {
                if let header = section.header { collectedCopy.append(header) }
                for case let item as CPListItem in section.items {
                    if let text = item.text { collectedCopy.append(text) }
                    if let detail = item.detailText { collectedCopy.append(detail) }
                }
            }
        }

        let forbiddenPhrases = ["iphone", "on your phone", "open dashcast", "tap the heart"]
        for copy in collectedCopy {
            let lowered = copy.lowercased()
            for phrase in forbiddenPhrases {
                XCTAssertFalse(
                    lowered.contains(phrase),
                    "CarPlay Guideline 2 violation — found '\(phrase)' in: '\(copy)'"
                )
            }
        }
    }

    func testLibrarySectionsSurfaceRecentChannelsAtTopInMostRecentOrder() throws {
        let suite = "CarPlaySceneTests.Recent.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: suite)
        }
        let store = PlaylistStore(persistence: PersistenceController(userDefaults: defaults), defaults: defaults)
        let m3u = """
        #EXTM3U
        #EXTINF:-1 group-title="News",News One
        https://stream.example.com/news1.m3u8
        #EXTINF:-1 group-title="Sports",Sports One
        https://stream.example.com/sports1.m3u8
        """
        try store.addPlaylist(data: Data(m3u.utf8), sourceURL: nil, title: "Test")

        let delegate = CarPlaySceneDelegate()
        let sectionsWithoutRecents = delegate.makeLibrarySections(store: store)
        XCTAssertEqual(sectionsWithoutRecents.count, 1)
        XCTAssertNil(sectionsWithoutRecents[0].header)

        let news = store.importedChannels[0]
        let sports = store.importedChannels[1]
        store.recordRecentChannel(news)
        store.recordRecentChannel(sports)
        store.recordRecentChannel(news)

        let sectionsWithRecents = delegate.makeLibrarySections(store: store)
        XCTAssertEqual(sectionsWithRecents.count, 2)
        XCTAssertEqual(sectionsWithRecents[0].header, "Recent")
        XCTAssertEqual(sectionsWithRecents[1].header, "Categories")

        let recentItems = sectionsWithRecents[0].items.compactMap { $0 as? CPListItem }
        XCTAssertEqual(recentItems.compactMap(\.text), ["News One", "Sports One"])
        XCTAssertEqual(recentItems.first?.detailText, "News")
    }
}
