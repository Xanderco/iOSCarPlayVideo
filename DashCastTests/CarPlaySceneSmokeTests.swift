import CarPlay
import MediaPlayer
import XCTest
@testable import DashCast

/// In-memory stand-in for `CPInterfaceController`, which cannot be created without a car.
@MainActor
final class MockCarPlayInterfaceController: CarPlayInterfaceControlling {
    private(set) var templates: [CPTemplate] = []
    private(set) var setRootCount = 0
    var topTemplate: CPTemplate? { templates.last }
    var rootTemplate: CPTemplate? { templates.first }

    func carPlaySetRoot(_ template: CPTemplate, animated: Bool) {
        setRootCount += 1
        templates = [template]
    }

    func carPlayPush(_ template: CPTemplate, animated: Bool) {
        templates.append(template)
    }

    func carPlayPop(to template: CPTemplate, animated: Bool) {
        guard let index = templates.firstIndex(where: { $0 === template }) else { return }
        templates = Array(templates.prefix(index + 1))
    }

    func carPlayPopToRoot(animated: Bool, completion: (() -> Void)?) {
        templates = Array(templates.prefix(1))
        completion?()
    }
}

/// Smoke test of the CarPlay scene: instantiate the delegate, connect a mock interface
/// controller and drive the templates the way a driver would (tab → group → channel).
@MainActor
final class CarPlaySceneSmokeTests: XCTestCase {
    private var delegate: CarPlaySceneDelegate!
    private var controller: MockCarPlayInterfaceController!
    private var favoritesToRestore: [ChannelModel] = []

    override func setUp() async throws {
        delegate = CarPlaySceneDelegate()
        controller = MockCarPlayInterfaceController()
        delegate.connect(controller)
    }

    override func tearDown() async throws {
        for channel in favoritesToRestore where PlaylistStore.shared.isFavorite(channel) {
            PlaylistStore.shared.toggleFavorite(channel)
        }
        favoritesToRestore = []
        delegate.disconnect()
        VideoPlayerService.shared.pause()
        delegate = nil
        controller = nil
    }

    // MARK: Helpers

    private var tabBar: CPTabBarTemplate? { controller.rootTemplate as? CPTabBarTemplate }

    private func tab(_ title: String) throws -> CPListTemplate {
        let tabBar = try XCTUnwrap(tabBar, "Root template must be a CPTabBarTemplate")
        let match = tabBar.templates.first { $0.tabTitle == title }
        return try XCTUnwrap(match as? CPListTemplate, "Missing tab \(title)")
    }

    private func listItems(_ template: CPListTemplate) -> [CPListItem] {
        template.sections.flatMap { $0.items.compactMap { $0 as? CPListItem } }
    }

    private func select(_ item: CPListItem, file: StaticString = #filePath, line: UInt = #line) {
        guard let handler = item.handler else {
            return XCTFail("List item \(item.text ?? "?") has no handler", file: file, line: line)
        }
        var completed = false
        handler(item) { completed = true }
        XCTAssertTrue(completed, "Handler must call its completion block", file: file, line: line)
    }

    // MARK: Tests

    func testConnectInstallsTabBarWithLibraryFavoritesAndInfo() throws {
        XCTAssertEqual(controller.setRootCount, 1)
        let tabBar = try XCTUnwrap(tabBar)
        XCTAssertEqual(tabBar.templates.map { $0.tabTitle }, ["Library", "Favorites", "Info"])
        XCTAssertLessThanOrEqual(tabBar.templates.count, Int(CPTabBarTemplate.maximumTabCount))
        XCTAssertNotNil(delegate.interfaceController)
    }

    func testLibraryShowsOneRowPerGroupWithinCarPlayLimits() throws {
        let library = try tab("Library")
        let store = PlaylistStore.shared
        let groups = store.groupedChannels(store.allChannels)
        XCTAssertGreaterThan(CPListTemplate.maximumItemCount, 0)
        let expected = min(groups.count, Int(CPListTemplate.maximumItemCount))
        let items = listItems(library)
        XCTAssertEqual(items.count, expected)
        XCTAssertEqual(items.first?.text, groups.first?.group)
        XCTAssertTrue(items.allSatisfy { $0.accessoryType == .disclosureIndicator })
    }

    func testSelectingGroupPushesItsChannelsAndChannelStartsPlayback() throws {
        let library = try tab("Library")
        let groupItem = try XCTUnwrap(listItems(library).first)
        select(groupItem)

        XCTAssertEqual(controller.templates.count, 2, "Group list should be pushed")
        let groupList = try XCTUnwrap(controller.topTemplate as? CPListTemplate)
        XCTAssertEqual(groupList.userInfo as? String, groupItem.text)

        // Prefer a channel that plays a bundled file so nothing touches the network.
        let channels = listItems(groupList)
        let channelItem = try XCTUnwrap(channels.first { ($0.userInfo as? URL)?.isFileURL == true } ?? channels.first)
        select(channelItem)

        XCTAssertEqual(VideoPlayerService.shared.currentChannel?.name, channelItem.text)
        XCTAssertTrue(controller.topTemplate === CPNowPlayingTemplate.shared, "Now Playing should be shown")
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String,
                       channelItem.text)
        XCTAssertTrue(channelItem.isPlaying, "Playing indicator should be set on the selected row")
    }

    func testTemplateStackNeverExceedsCarPlayDepthLimit() throws {
        let library = try tab("Library")
        let groupItem = try XCTUnwrap(listItems(library).first)
        for _ in 0..<(CarPlaySceneDelegate.maximumTemplateDepth + 3) {
            select(groupItem)
        }
        XCTAssertEqual(controller.templates.count, CarPlaySceneDelegate.maximumTemplateDepth)

        // A channel selected from a full stack still reaches Now Playing within the limit.
        let groupList = try XCTUnwrap(controller.topTemplate as? CPListTemplate)
        let channelItem = try XCTUnwrap(listItems(groupList).first { ($0.userInfo as? URL)?.isFileURL == true }
                                        ?? listItems(groupList).first)
        select(channelItem)
        XCTAssertTrue(controller.topTemplate === CPNowPlayingTemplate.shared)
        XCTAssertLessThanOrEqual(controller.templates.count, CarPlaySceneDelegate.maximumTemplateDepth)
    }

    func testFavoritesTabFollowsPlaylistStore() throws {
        let favorites = try tab("Favorites")
        let store = PlaylistStore.shared
        let channel = try XCTUnwrap(store.sampleChannels.first)
        if !store.isFavorite(channel) {
            favoritesToRestore.append(channel)
            store.toggleFavorite(channel)
        }
        waitUntil("favorite appears in the CarPlay Favorites tab") {
            self.listItems(favorites).contains { $0.text == channel.name }
        }
        XCTAssertFalse(favorites.emptyViewTitleVariants.isEmpty, "Empty state text must be configured")
    }

    func testInfoTabRowsAreSelectable() throws {
        let info = try tab("Info")
        let items = listItems(info)
        XCTAssertFalse(items.isEmpty)
        items.forEach { select($0) }
        XCTAssertEqual(controller.templates.count, 1, "Info rows must not push templates")
    }

    func testDisconnectReleasesInterfaceController() {
        delegate.disconnect()
        XCTAssertNil(delegate.interfaceController)
    }

    func testDashboardSceneDelegateCanBeCreated() {
        XCTAssertNotNil(CarPlayDashboardSceneDelegate())
    }
}
