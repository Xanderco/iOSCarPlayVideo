import XCTest

/// Me tab: settings, about, feedback and upgrade links.
final class MeAndSettingsUITests: DashCastUITestCase {
    func testSettingsSheetAndRestoreLinkOpensPaywall() {
        launch(initialTab: "me")
        waitFor(app.otherElements["Screen_Me"])
        tap(app.buttons["Me_Settings"])
        waitFor(navBar("Settings"), "settings sheet")
        snapshot("30-settings")

        let restore = app.buttons["Settings_RestorePurchase"]
        scrollTo(restore)
        waitFor(restore, "Restore Purchase link")
        tap(navBar("Settings").buttons["Done"])
        waitForDisappearance(navBar("Settings"))
    }

    func testAboutAndFeedbackOpen() {
        launch(initialTab: "me")
        tap(app.buttons["Me_About"])
        waitFor(navBar("About"))
        snapshot("31-about")
        tap(navBar("About").buttons["Done"])
        waitForDisappearance(navBar("About"))

        tap(app.buttons["Me_Feedback"])
        waitFor(navBar("Feedback"))
        snapshot("32-feedback")
        tap(navBar("Feedback").buttons["Cancel"])
        waitForDisappearance(navBar("Feedback"))
    }

    func testUpgradeButtonOpensPaywall() {
        launch(initialTab: "me")
        tap(app.buttons["Me_UpgradeButton"])
        waitFor(app.buttons["Paywall_BuyButton"], "paywall from Me")
        waitForLabel(app.staticTexts["Paywall_Price"], containing: "19.99")
        tap(app.buttons["Paywall_Close"])
    }

    func testDriveDetailsOpen() {
        launch(initialTab: "me")
        tap(app.buttons["Me_Drive"])
        waitFor(navBar("Drive"), "drive settings sheet")
        snapshot("33-drive-settings")
    }
}
