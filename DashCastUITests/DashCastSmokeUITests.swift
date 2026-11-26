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

    func testSoundsTriggerCardsAndSlotPickers() throws {
        let soundsTab = tabButton("Sounds")
        XCTAssertTrue(soundsTab.waitForExistence(timeout: 15), "Sounds tab missing")
        soundsTab.tap()
        XCTAssertTrue(app.otherElements["Screen_Sounds"].waitForExistence(timeout: 10), "Sounds screen did not appear")

        let connectionPicker = app.buttons["Sounds_PickerButton_connection"]
        let disconnectionPicker = app.buttons["Sounds_PickerButton_disconnection"]
        let arrivalPicker = app.buttons["Sounds_PickerButton_arrival"]

        XCTAssertTrue(connectionPicker.waitForExistence(timeout: 5), "Connection Sound card picker missing")
        XCTAssertTrue(disconnectionPicker.exists, "Disconnection Sound card picker missing")
        XCTAssertTrue(arrivalPicker.exists, "Home Arrival Sound card picker missing")

        // Open Connection picker, verify title, pick Hyperspace Jump
        tapCenter(of: connectionPicker)
        XCTAssertTrue(
            app.navigationBars["Select Connection Sound"].waitForExistence(timeout: 5),
            "Connection sound picker did not open with expected title"
        )
        let hyperspaceRow = app.buttons["Sounds_PickerRow_hyperspace"]
        XCTAssertTrue(hyperspaceRow.waitForExistence(timeout: 5), "Hyperspace row missing")
        tapCenter(of: hyperspaceRow)

        let connectionLabel = app.staticTexts["Sounds_SelectedLabel_connection"]
        XCTAssertTrue(connectionLabel.waitForExistence(timeout: 5), "Connection selected label missing")
        XCTAssertTrue(connectionLabel.label.contains("Hyperspace Jump"), "Expected Hyperspace Jump, got: \(connectionLabel.label)")
        snapshot("05a-sounds-connection-selected")

        // Open Arrival picker, verify distinct title, pick Luxury Sedan Chime
        tapCenter(of: arrivalPicker)
        XCTAssertTrue(
            app.navigationBars["Select Arrival Sound"].waitForExistence(timeout: 5),
            "Arrival sound picker did not open with expected title"
        )
        let luxuryRow = app.buttons["Sounds_PickerRow_luxury_chime"]
        XCTAssertTrue(luxuryRow.waitForExistence(timeout: 5), "Luxury chime row missing")
        tapCenter(of: luxuryRow)

        let arrivalLabel = app.staticTexts["Sounds_SelectedLabel_arrival"]
        XCTAssertTrue(arrivalLabel.waitForExistence(timeout: 5), "Arrival selected label missing")
        XCTAssertTrue(arrivalLabel.label.contains("Luxury Sedan Chime"), "Expected Luxury Sedan Chime, got: \(arrivalLabel.label)")
        XCTAssertTrue(connectionLabel.label.contains("Hyperspace Jump"), "Connection selection was overwritten by Arrival picker")

        // Open Disconnection picker, verify title, and close
        tapCenter(of: disconnectionPicker)
        XCTAssertTrue(
            app.navigationBars["Select Disconnection Sound"].waitForExistence(timeout: 5),
            "Disconnection sound picker did not open with expected title"
        )
        snapshot("05b-sounds-disconnection-picker")
        app.buttons["Sounds_PickerCloseButton"].tap()
        XCTAssertTrue(connectionPicker.waitForExistence(timeout: 5), "Did not return to Sounds screen")
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
