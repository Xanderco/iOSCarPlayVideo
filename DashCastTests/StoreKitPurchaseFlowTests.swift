import StoreKit
import StoreKitTest
import XCTest
@testable import DashCast

/// End-to-end purchase / restore / refund of the one-time lifetime unlock against the local
/// StoreKit configuration (DashCast/Resources/DashCastStore.storekit). No App Store account,
/// no network, no system dialogs.
@MainActor
final class StoreKitPurchaseFlowTests: XCTestCase {
    private var session: SKTestSession!
    private let cacheKey = "dashcast_pro_lifetime_entitlement_cached"

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "DashCastStore")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        UserDefaults.standard.removeObject(forKey: cacheKey)
        AppState.shared.isProLifetimeUnlocked = false
    }

    override func tearDown() async throws {
        session.clearTransactions()
        session.askToBuyEnabled = false
        session.failTransactionsEnabled = false
        UserDefaults.standard.removeObject(forKey: cacheKey)
        AppState.shared.isProLifetimeUnlocked = false
        AppState.shared.showPaywall = false
        session = nil
    }

    private func makeLoadedManager(file: StaticString = #filePath, line: UInt = #line) async throws -> (StoreKitManager, Product) {
        let manager = StoreKitManager()
        await manager.fetchProducts()
        let product = try XCTUnwrap(manager.lifetimeProduct, "Lifetime product did not load from the .storekit config",
                                    file: file, line: line)
        return (manager, product)
    }

    func testLifetimeProductLoadsAsNonConsumableAt19_99() async throws {
        let (_, product) = try await makeLoadedManager()
        XCTAssertEqual(product.id, StoreKitManager.lifetimeProductID)
        XCTAssertEqual(product.type, .nonConsumable)
        XCTAssertEqual(product.price, Decimal(string: "19.99"))
        XCTAssertTrue(product.displayPrice.contains("19.99"), "Localized price was \(product.displayPrice)")
        XCTAssertFalse(product.displayName.isEmpty)
    }

    func testPurchaseUnlocksProAndCachesEntitlement() async throws {
        let (manager, _) = try await makeLoadedManager()
        XCTAssertFalse(manager.isPurchased)

        let success = try await manager.purchaseLifetime()

        XCTAssertTrue(success)
        XCTAssertTrue(manager.isPurchased)
        XCTAssertTrue(AppState.shared.isProLifetimeUnlocked)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: cacheKey), "Entitlement must be cached for offline launch")
        XCTAssertFalse(manager.isLoading)
    }

    func testRestoreFindsAnEarlierPurchase() async throws {
        // A purchase made "on another device" / before reinstall.
        _ = try await session.buyProduct(identifier: StoreKitManager.lifetimeProductID)

        let manager = StoreKitManager()
        XCTAssertFalse(UserDefaults.standard.bool(forKey: cacheKey))
        await manager.updatePurchasedStatus() // what restorePurchases() runs after AppStore.sync()

        XCTAssertTrue(manager.isPurchased)
        XCTAssertTrue(AppState.shared.isProLifetimeUnlocked)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: cacheKey))
    }

    func testRefundRevokesEntitlement() async throws {
        let transaction = try await session.buyProduct(identifier: StoreKitManager.lifetimeProductID)
        let manager = StoreKitManager()
        await manager.updatePurchasedStatus()
        XCTAssertTrue(manager.isPurchased)

        try session.refundTransaction(identifier: UInt(transaction.id))
        await manager.updatePurchasedStatus()

        XCTAssertFalse(manager.isPurchased)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: cacheKey))
    }

    func testAskToBuyPendingDoesNotUnlock() async throws {
        session.askToBuyEnabled = true
        let (manager, _) = try await makeLoadedManager()

        let success = try await manager.purchaseLifetime()

        XCTAssertFalse(success, "A pending (Ask to Buy) purchase must not report success")
        XCTAssertFalse(manager.isPurchased)
        XCTAssertFalse(AppState.shared.isProLifetimeUnlocked)
    }

    func testFailedTransactionDoesNotUnlock() async throws {
        let (manager, _) = try await makeLoadedManager()
        session.failTransactionsEnabled = true

        do {
            let success = try await manager.purchaseLifetime()
            XCTAssertFalse(success)
        } catch {
            // Throwing is the expected path; the UI shows `error.localizedDescription`.
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        XCTAssertFalse(manager.isPurchased)
        XCTAssertFalse(manager.isLoading, "Loading state must be cleared after a failure")
    }
}
