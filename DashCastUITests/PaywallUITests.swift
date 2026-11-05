import StoreKitTest
import XCTest

/// One-time lifetime unlock: price, purchase and restore through a local StoreKit test session
/// (DashCastStore.storekit). Dialogs are disabled so no App Store sheet appears.
final class PaywallUITests: DashCastUITestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        try super.setUpWithError()
        session = try SKTestSession(configurationFileNamed: "DashCastStore")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDownWithError() throws {
        session?.clearTransactions()
        session = nil
        try super.tearDownWithError()
    }

    private func openPaywallFromCast() {
        tap(app.buttons["Cast_ProButton"])
        waitFor(app.buttons["Paywall_BuyButton"], "paywall")
    }

    func testPaywallShowsLocalizedLifetimePrice() {
        launch()
        openPaywallFromCast()
        waitForLabel(app.staticTexts["Paywall_Price"], containing: "19.99")
        waitForLabel(app.buttons["Paywall_BuyButton"], containing: "19.99")
        waitFor(app.buttons["Paywall_RestoreButton"])
        snapshot("20-paywall")
        tap(app.buttons["Paywall_Close"])
        waitForDisappearance(app.buttons["Paywall_BuyButton"])
    }

    func testPurchaseUnlocksPro() {
        launch()
        openPaywallFromCast()
        // Wait until StoreKit finished loading (the button title shows the product price, not "Connecting…").
        waitForLabel(app.buttons["Paywall_BuyButton"], containing: "Forever")
        tap(app.buttons["Paywall_BuyButton"])

        let welcome = app.alerts["Welcome to DashCast Pro!"]
        waitFor(welcome, "purchase success alert")
        snapshot("21-purchase-success")
        welcome.buttons.firstMatch.tap()

        waitForDisappearance(app.buttons["Paywall_BuyButton"], "paywall closes after purchase")
        waitForDisappearance(app.buttons["Cast_ProButton"], "PRO badge hidden once unlocked")
        XCTAssertEqual(session.allTransactions().count, 1)
    }

    func testRestoreFindsEarlierPurchase() throws {
        try session.buyProduct(productIdentifier: "com.dashcast.lifetime")
        launch()
        openPaywallFromCast()
        tap(app.buttons["Paywall_RestoreButton"])

        let welcome = app.alerts["Welcome to DashCast Pro!"]
        waitFor(welcome, "restore success alert")
        snapshot("22-restore-success")
        welcome.buttons.firstMatch.tap()
        waitForDisappearance(app.buttons["Cast_ProButton"], "PRO badge hidden after restore")
    }
}
