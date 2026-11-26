import XCTest

/// Smoke tests that drive the real app UI in the simulator.
/// Every test attaches screenshots (kept even on success) so CI artifacts
/// show what each screen looked like.
final class DashCastSmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    /// Tabs in display order; raw values match `AppState.TabItem`.
    private let tabs = ["Cast", "Drive", "Widgets", "Sounds", "Me"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITests", "-initialTab", "cast"]

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

    /// Native system tab bar on iOS 18+ (Liquid Glass on iOS 26); custom capsule bar on iOS 17.
    private func tabButton(_ name: String) -> XCUIElement {
        let native = app.tabBars.buttons[name]
        return native.exists || app.tabBars.firstMatch.waitForExistence(timeout: 5) ? native : app.buttons["Tab_\(name)"]
    }

    // MARK: - Tests

    func testAppLaunchesToCastTab() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "App did not reach foreground")
        let castTab = tabButton("Cast")
        XCTAssertTrue(castTab.waitForExistence(timeout: 15), "Tab bar did not appear")
        XCTAssertTrue(app.otherElements["Screen_Cast"].waitForExistence(timeout: 10), "Cast screen missing")
        snapshot("01-launch")
    }

    func testEveryTabOpens() throws {
        for (index, tab) in tabs.enumerated() {
            let button = tabButton(tab)
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
            app.navigationBars["Media Sources"].waitForExistence(timeout: 10),
            "Media Sources sheet did not open"
        )
        let firstChannel = app.buttons.matching(identifier: "MediaSources_Channel").firstMatch
        XCTAssertTrue(firstChannel.waitForExistence(timeout: 10), "No channels listed")
        XCTAssertGreaterThan(
            app.buttons.matching(identifier: "MediaSources_Channel").count, 0,
            "Channel list is empty"
        )
        snapshot("03-media-sources")

        app.navigationBars["Media Sources"].buttons["Done"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Did not return to Cast tab")
    }

    func testMediaSourcesJellyfinAndQREntry() throws {
        let row = app.buttons["Cast_MediaSourceRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Media Source row missing")
        tapCenter(of: row)

        XCTAssertTrue(
            app.navigationBars["Media Sources"].waitForExistence(timeout: 10),
            "Media Sources sheet did not open"
        )

        // Verify Jellyfin/Emby connect button or section exists
        let connectServer = app.buttons["MediaSources_ConnectServer"]
        let addServerButton = app.buttons["MediaSources_AddServerButton"]
        XCTAssertTrue(connectServer.exists || addServerButton.exists, "Media server entry missing")

        // Verify QR Scan buttons exist
        let scanQRHeader = app.buttons["MediaSources_ScanQRHeaderButton"]
        let scanQRCard = app.buttons["MediaSources_ScanQRCard"]
        XCTAssertTrue(scanQRHeader.exists || scanQRCard.exists, "QR Scan entry missing")

        // Open Add Server sheet and verify form
        if addServerButton.exists {
            addServerButton.tap()
            XCTAssertTrue(app.navigationBars["Add Server"].waitForExistence(timeout: 5), "Add Server sheet failed to open")
            snapshot("03b-add-media-server")
            app.navigationBars["Add Server"].buttons["Cancel"].tap()
        }

        // Open QR scanner sheet and verify scanner view
        if scanQRHeader.exists {
            scanQRHeader.tap()
            XCTAssertTrue(app.navigationBars["Scan Playlist QR"].waitForExistence(timeout: 5), "Scan Playlist QR sheet failed to open")
            snapshot("03c-scan-playlist-qr")
            app.navigationBars["Scan Playlist QR"].buttons["Close"].tap()
        }

        app.navigationBars["Media Sources"].buttons["Done"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Did not return to Cast tab")
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
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Did not return to Cast tab")
    }

    func testMeSettingsDataPrivacyAndCarDisplayGuide() throws {
        let meTab = tabButton("Me")
        XCTAssertTrue(meTab.waitForExistence(timeout: 15), "Me tab button missing")
        meTab.tap()
        XCTAssertTrue(app.otherElements["Screen_Me"].waitForExistence(timeout: 10), "Me screen did not appear")

        let guideRow = app.buttons["Me_CarDisplayGuideRow"]
        XCTAssertTrue(guideRow.waitForExistence(timeout: 10), "Car Display Guide row missing on Me tab")
        scrollUntilVisible(guideRow, maxY: 520)
        tapCenter(of: guideRow)

        let guideNav = app.navigationBars["Car Display Setup"]
        XCTAssertTrue(guideNav.waitForExistence(timeout: 10), "Car Display Setup sheet did not open from Me tab")
        snapshot("06-car-display-guide")
        guideNav.buttons["Done"].tap()
        waitForDisappearance(of: guideNav, timeout: 5)

        let settingsRow = app.buttons["Me_SettingsRow"]
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 10), "Settings row missing on Me tab")
        scrollUntilVisible(settingsRow, maxY: 520)
        tapCenter(of: settingsRow)

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 10), "Settings sheet did not open")

        let clearTrips = app.buttons["Me_Settings_ClearTripsButton"]
        let clearPlaylists = app.buttons["Me_Settings_ClearPlaylistsButton"]
        XCTAssertTrue(clearTrips.waitForExistence(timeout: 10), "Clear Trip History button missing")
        XCTAssertTrue(clearPlaylists.waitForExistence(timeout: 10), "Clear Playlists button missing")
        scrollUntilVisible(clearPlaylists, maxY: 610)
        snapshot("06b-settings-data-privacy")

        scrollUntilVisible(clearTrips, maxY: 610)
        tapCenter(of: clearTrips)
        let cancelAction = app.buttons["Cancel"]
        XCTAssertTrue(cancelAction.waitForExistence(timeout: 5), "Clear Trip History confirmation dialog did not open")
        cancelAction.tap()

        let settingsGuideRow = app.buttons["Me_Settings_CarDisplayGuideRow"]
        XCTAssertTrue(settingsGuideRow.waitForExistence(timeout: 10), "Car Display Guide row missing in Settings")
        scrollUntilVisible(settingsGuideRow, maxY: 610)
        tapCenter(of: settingsGuideRow)
        XCTAssertTrue(guideNav.waitForExistence(timeout: 10), "Car Display Setup sheet did not open from Settings")
        guideNav.buttons["Done"].tap()
        waitForDisappearance(of: guideNav, timeout: 5)

        XCTAssertTrue(settingsNav.waitForExistence(timeout: 10), "Settings did not reappear")
        settingsNav.buttons["Done"].tap()
    }

    // MARK: - Helpers

    /// Scrolls the frontmost scroll view up until `element` sits comfortably above the floating tab bar / bottom edge.
    private func scrollUntilVisible(_ element: XCUIElement, maxY: CGFloat, maxSwipes: Int = 5) {
        for _ in 0..<maxSwipes {
            if element.exists && element.frame.height > 0 && element.frame.minY >= 60 && element.frame.maxY <= maxY {
                return
            }
            let scrollView = app.scrollViews.allElementsBoundByIndex.last(where: { $0.exists && $0.frame.height > 100 })
                ?? app.scrollViews.firstMatch
            guard scrollView.exists else { return }
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval) {
        guard element.exists else { return }
        let predicate = NSPredicate(format: "exists == false")
        let exp = expectation(for: predicate, evaluatedWith: element)
        _ = XCTWaiter.wait(for: [exp], timeout: timeout)
    }

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
