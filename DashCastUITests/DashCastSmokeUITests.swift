import XCTest

/// Smoke tests that drive the real app UI in the simulator.
/// Every test attaches screenshots (kept even on success) so CI artifacts
/// show what each screen looked like.
final class DashCastSmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    /// Tabs in display order; raw values match `AppState.TabItem`.
    private let tabs = ["Home", "Library", "Cast", "Settings"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITests", "-initialTab", "home"]

        // Dismiss any system permission alert (location, notifications…).
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for label in ["Allow While Using App", "Allow", "OK", "Don’t Allow", "Don't Allow"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }

        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    func testAppLaunchesToHomeTab() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "App did not reach foreground")
        let homeTab = app.buttons["Tab_Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 15), "Tab bar did not appear")
        XCTAssertTrue(app.otherElements["Screen_Home"].waitForExistence(timeout: 10), "Home screen missing")
        snapshot("01-launch")
    }

    func testEveryTabOpens() throws {
        for (index, tab) in tabs.enumerated() {
            let button = app.buttons["Tab_\(tab)"]
            XCTAssertTrue(button.waitForExistence(timeout: 15), "Tab button \(tab) missing")
            button.tap()

            XCTAssertTrue(
                app.otherElements["Screen_\(tab)"].waitForExistence(timeout: 10),
                "Screen for tab \(tab) did not appear"
            )
            XCTAssertTrue(button.isSelected, "Tab \(tab) is not marked selected")
            snapshot(String(format: "02-tab-%02d-%@", index + 1, tab))
        }
    }

    func testMediaSourcesSheetListsChannels() throws {
        let row = app.buttons["Cast_MediaSourceRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Media Source row missing")
        tapCenter(of: row)

        XCTAssertTrue(
            app.navigationBars["Library"].waitForExistence(timeout: 10),
            "Library sheet did not open"
        )
        let firstChannel = app.buttons.matching(identifier: "MediaSources_Channel").firstMatch
        XCTAssertTrue(firstChannel.waitForExistence(timeout: 10), "No channels listed")
        XCTAssertGreaterThan(
            app.buttons.matching(identifier: "MediaSources_Channel").count, 0,
            "Channel list is empty"
        )
        snapshot("03-media-sources")

        app.navigationBars["Library"].buttons["Done"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Did not return to Home tab")
    }

    func testBrowserSheetOpens() throws {
        let row = app.buttons["Cast_BrowserRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Browser row missing")
        tapCenter(of: row)

        let exit = app.buttons["Exit"]
        XCTAssertTrue(exit.waitForExistence(timeout: 10), "Browser sheet did not open")
        XCTAssertTrue(app.textFields.firstMatch.exists, "Browser address bar missing")
        snapshot("04-browser")

        exit.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Did not return to Home tab")
    }

    // MARK: - Helpers

    /// Screens are wrapped in `accessibilityElement(children: .contain)` containers
    /// (for `Screen_*` identifiers), which makes XCUITest report their children as
    /// "not hittable" even when fully visible. Tap the element's center instead.
    private func tapCenter(of element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
