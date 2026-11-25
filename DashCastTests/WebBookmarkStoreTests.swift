import XCTest
@testable import DashCast

@MainActor
final class WebBookmarkStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "com.xanderco.dashcast.tests.bookmarks.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDownWithError() throws {
        if let suiteName {
            defaults?.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
    }

    func testAddValidateAndDeduplicateBookmarks() {
        let store = WebBookmarkStore(defaults: defaults)

        XCTAssertNil(store.addBookmark(title: "Empty", urlString: ""))
        XCTAssertNil(store.addBookmark(title: "Script", urlString: "javascript:alert(1)"))
        XCTAssertNil(store.addBookmark(title: "Relative", urlString: "/videos/1.mp4"))

        let first = store.addBookmark(title: "Public Archive", urlString: "https://archive.org/details/movies")
        XCTAssertNotNil(first)
        XCTAssertEqual(store.bookmarks.count, 1)
        XCTAssertTrue(store.isBookmarked(urlString: "https://archive.org/details/movies"))

        // Duplicate URL updates title instead of creating a second row
        let updated = store.addBookmark(title: "Open Movies", urlString: "https://archive.org/details/movies")
        XCTAssertEqual(store.bookmarks.count, 1)
        XCTAssertEqual(updated?.title, "Open Movies")
    }

    func testPersistenceAcrossReinitialization() {
        let store1 = WebBookmarkStore(defaults: defaults)
        store1.addBookmark(title: "My Server", urlString: "http://192.168.1.50:8096")
        store1.userAgentMode = .desktop

        let store2 = WebBookmarkStore(defaults: defaults)
        XCTAssertEqual(store2.bookmarks.count, 1)
        XCTAssertEqual(store2.bookmarks.first?.title, "My Server")
        XCTAssertEqual(store2.bookmarks.first?.urlString, "http://192.168.1.50:8096")
        XCTAssertEqual(store2.userAgentMode, .desktop)
        XCTAssertNotNil(store2.userAgentMode.customUserAgent)
    }

    func testToggleAndClearBookmarks() {
        let store = WebBookmarkStore(defaults: defaults)
        let added = store.toggleBookmark(title: "Demo", urlString: "https://example.com/watch")
        XCTAssertTrue(added)
        XCTAssertTrue(store.isBookmarked(urlString: "https://example.com/watch"))

        let removed = store.toggleBookmark(title: "Demo", urlString: "https://example.com/watch")
        XCTAssertFalse(removed)
        XCTAssertFalse(store.isBookmarked(urlString: "https://example.com/watch"))

        store.addBookmark(title: "A", urlString: "https://a.example.com")
        store.addBookmark(title: "B", urlString: "https://b.example.com")
        XCTAssertEqual(store.bookmarks.count, 2)

        store.clearAllBookmarks()
        XCTAssertTrue(store.bookmarks.isEmpty)
    }

    func testUserAgentToggleSwitchesBetweenMobileAndDesktop() {
        let store = WebBookmarkStore(defaults: defaults)
        XCTAssertEqual(store.userAgentMode, .mobile)
        XCTAssertNil(store.userAgentMode.customUserAgent)

        store.toggleUserAgentMode()
        XCTAssertEqual(store.userAgentMode, .desktop)
        XCTAssertNotNil(store.userAgentMode.customUserAgent)

        store.toggleUserAgentMode()
        XCTAssertEqual(store.userAgentMode, .mobile)
        XCTAssertNil(store.userAgentMode.customUserAgent)
    }

    func testResolveNavigationURLHandlesSchemesDomainsAndSearchQueries() {
        XCTAssertNil(WebBookmarkStore.resolveNavigationURL(from: "   "))
        XCTAssertEqual(
            WebBookmarkStore.resolveNavigationURL(from: "http://192.168.1.20:8096")?.absoluteString,
            "http://192.168.1.20:8096"
        )
        XCTAssertEqual(
            WebBookmarkStore.resolveNavigationURL(from: "archive.org")?.absoluteString,
            "https://archive.org"
        )
        XCTAssertEqual(
            WebBookmarkStore.resolveNavigationURL(from: "dashcam road trip")?.absoluteString,
            "https://duckduckgo.com/?q=dashcam%20road%20trip"
        )
    }
}
