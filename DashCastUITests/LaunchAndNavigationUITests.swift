import XCTest

/// Launch + every tab.
final class LaunchAndNavigationUITests: DashCastUITestCase {
    private let tabs = ["Cast", "Drive", "Widgets", "Sounds", "Me"]

    func testAppLaunchesToCastTab() {
        launch()
        waitFor(app.otherElements["Screen_Cast"], "Cast screen")
        waitFor(app.buttons["Cast_MediaSourceRow"], "Media Source row")
        XCTAssertTrue(app.buttons["Tab_Cast"].isSelected, "Cast tab should be selected at launch")
        snapshot("01-launch")
    }

    func testEveryTabOpens() {
        launch()
        for (index, tab) in tabs.enumerated() {
            openTab(tab)
            XCTAssertTrue(app.buttons["Tab_\(tab)"].isSelected, "Tab \(tab) is not marked selected")
            snapshot(String(format: "02-tab-%02d-%@", index + 1, tab))
        }
    }

    func testInitialTabLaunchArgument() {
        launch(initialTab: "me")
        waitFor(app.otherElements["Screen_Me"], "Me screen")
        XCTAssertTrue(app.buttons["Tab_Me"].isSelected)
    }
}
