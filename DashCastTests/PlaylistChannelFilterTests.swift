import XCTest
@testable import DashCast

final class PlaylistChannelFilterTests: XCTestCase {

    private func makeChannels() -> [ChannelModel] {
        [
            ChannelModel(id: "1", name: "World News HD", streamURL: URL(string: "https://example.com/1.m3u8")!, groupTitle: "News"),
            ChannelModel(id: "2", name: "Sports Central", streamURL: URL(string: "https://example.com/2.m3u8")!, groupTitle: "Sports"),
            ChannelModel(id: "3", name: "Action Cinema", streamURL: URL(string: "https://example.com/3.m3u8")!, groupTitle: "Movies"),
            ChannelModel(id: "4", name: "Local Weather", streamURL: URL(string: "https://example.com/4.m3u8")!, groupTitle: "News"),
        ]
    }

    func testAllScopeAndEmptyQueryReturnsAllChannels() {
        let channels = makeChannels()
        let filter = PlaylistChannelFilter()
        XCTAssertFalse(filter.isActive)

        let result = filter.apply(to: channels) { _ in false }
        XCTAssertEqual(result.map(\.id), ["1", "2", "3", "4"])
    }

    func testQueryMatchesNameAndGroupTitleCaseInsensitively() {
        let channels = makeChannels()

        let byName = PlaylistChannelFilter(query: "  central ")
        XCTAssertTrue(byName.isActive)
        XCTAssertEqual(byName.apply(to: channels) { _ in false }.map(\.id), ["2"])

        let byGroup = PlaylistChannelFilter(query: "NEWS")
        XCTAssertEqual(byGroup.apply(to: channels) { _ in false }.map(\.id), ["1", "4"])
    }

    func testGroupScopeFiltersExactGroupAndCombinesWithSearch() {
        let channels = makeChannels()

        let groupOnly = PlaylistChannelFilter(query: "", scope: .group("News"))
        XCTAssertTrue(groupOnly.isActive)
        XCTAssertEqual(groupOnly.apply(to: channels) { _ in false }.map(\.id), ["1", "4"])

        let groupAndQuery = PlaylistChannelFilter(query: "weather", scope: .group("News"))
        XCTAssertEqual(groupAndQuery.apply(to: channels) { _ in false }.map(\.id), ["4"])

        let noMatch = PlaylistChannelFilter(query: "sports", scope: .group("News"))
        XCTAssertTrue(noMatch.apply(to: channels) { _ in false }.isEmpty)
    }

    func testFavoritesScopeFiltersFavoritePredicateAndSearch() {
        let channels = makeChannels()
        let favorites: Set<String> = ["1", "3"]
        let isFav: (ChannelModel) -> Bool = { favorites.contains($0.id) }

        let favOnly = PlaylistChannelFilter(scope: .favorites)
        XCTAssertTrue(favOnly.isActive)
        XCTAssertEqual(favOnly.apply(to: channels, isFavorite: isFav).map(\.id), ["1", "3"])

        let favWithQuery = PlaylistChannelFilter(query: "cinema", scope: .favorites)
        XCTAssertEqual(favWithQuery.apply(to: channels, isFavorite: isFav).map(\.id), ["3"])
    }

    func testAvailableGroupsPreservesFirstSeenOrderAndSkipsBlank() {
        var channels = makeChannels()
        channels.append(ChannelModel(id: "5", name: "Blank", streamURL: URL(string: "https://example.com/5.m3u8")!, groupTitle: "  "))

        XCTAssertEqual(PlaylistChannelFilter.availableGroups(from: channels), ["News", "Sports", "Movies"])
    }
}
