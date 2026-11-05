import XCTest
import StoreKit
import StoreKitTest
@testable import DashCast

/// Integration tests against the local StoreKit configuration (`DashCastStore.storekit`)
/// using `SKTestSession`, plus pure entitlement-resolution tests.
final class StoreKitTests: XCTestCase {

    // MARK: - Helpers

    private static func configurationURL() -> URL? {
        Bundle(for: StoreKitTests.self).url(forResource: "DashCastStore", withExtension: "storekit")
            ?? Bundle.main.url(forResource: "DashCastStore", withExtension: "storekit")
    }

    private func makeSession() throws -> SKTestSession {
        let url = try XCTUnwrap(Self.configurationURL(), "DashCastStore.storekit must be bundled with the tests")
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()
        addTeardownBlock { session.clearTransactions() }
        return session
    }

    private func makeDefaults() -> UserDefaults {
        let name = "StoreKitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    /// Re-reads entitlements until `condition` holds; StoreKit test changes can take a moment to land.
    @MainActor
    private func refresh(_ manager: StoreKitManager,
                         until condition: @MainActor () -> Bool,
                         timeout: TimeInterval = 15) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            await manager.refreshEntitlements()
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return condition()
    }

    private struct SyncFailure: Error {}

    // MARK: - Configuration

    func testCatalogueIsASingleLifetimeProduct() {
        XCTAssertEqual(ProProduct.allIDs, ["pro.lifetime"])
    }

    @MainActor
    func testLifetimeProductLoadsAsFamilyShareableNonConsumable() async throws {
        _ = try makeSession()
        let manager = StoreKitManager(defaults: makeDefaults(), startImmediately: false)

        await manager.loadProducts()

        let product = try XCTUnwrap(manager.proProduct)
        XCTAssertEqual(manager.loadState, .loaded)
        XCTAssertEqual(product.id, "pro.lifetime")
        XCTAssertEqual(product.type, .nonConsumable)
        XCTAssertTrue(product.isFamilyShareable)
        XCTAssertNil(product.subscription, "DashCast Pro must not be a subscription")
        XCTAssertEqual(product.price, Decimal(string: "19.99"))
        XCTAssertFalse(product.displayPrice.isEmpty)
    }

    // MARK: - Purchase

    @MainActor
    func testPurchaseUnlocksProAndCachesEntitlement() async throws {
        _ = try makeSession()
        let defaults = makeDefaults()
        var reported: [ProEntitlement] = []
        let manager = StoreKitManager(defaults: defaults, startImmediately: false) { reported.append($0) }
        XCTAssertFalse(manager.isPro)

        await manager.loadProducts()
        let outcome = try await manager.purchasePro()

        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(manager.isPro)
        XCTAssertEqual(manager.entitlement, .lifetime)
        XCTAssertEqual(reported.last, .lifetime)
        XCTAssertFalse(manager.isPurchasing)

        // A fresh launch picks the cached entitlement up before StoreKit answers.
        let relaunched = StoreKitManager(defaults: defaults, startImmediately: false)
        XCTAssertTrue(relaunched.isPro)
    }

    @MainActor
    func testPurchaseLoadsProductOnDemand() async throws {
        _ = try makeSession()
        let manager = StoreKitManager(defaults: makeDefaults(), startImmediately: false)
        XCTAssertNil(manager.proProduct)

        let outcome = try await manager.purchasePro()

        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(manager.isPro)
    }

    @MainActor
    func testFailedPurchaseKeepsProLocked() async throws {
        let session = try makeSession()
        session.failTransactionsEnabled = true
        let manager = StoreKitManager(defaults: makeDefaults(), startImmediately: false)
        await manager.loadProducts()

        // Depending on the OS, a failed test transaction throws or never reports success.
        let outcome = try? await manager.purchasePro()
        XCTAssertNotEqual(outcome, .purchased)
        await manager.refreshEntitlements()
        XCTAssertFalse(manager.isPro)
    }

    // MARK: - Restore

    @MainActor
    func testRestoreUnlocksProOnFreshInstall() async throws {
        _ = try makeSession()
        let buyer = StoreKitManager(defaults: makeDefaults(), startImmediately: false)
        try await buyer.purchasePro()
        XCTAssertTrue(buyer.isPro)

        // Simulates a reinstall / new device: empty cache, nothing known yet.
        let reinstalled = StoreKitManager(defaults: makeDefaults(), startImmediately: false)
        XCTAssertFalse(reinstalled.isPro)

        var synced = false
        let restored = try await reinstalled.restorePurchases(sync: { synced = true })

        XCTAssertTrue(synced)
        XCTAssertTrue(restored)
        XCTAssertTrue(reinstalled.isPro)
        XCTAssertFalse(reinstalled.isRestoring)
    }

    @MainActor
    func testRestoreWithNothingPurchasedReportsFalse() async throws {
        _ = try makeSession()
        let manager = StoreKitManager(defaults: makeDefaults(), startImmediately: false)
        let cleared = await refresh(manager, until: { !manager.isPro })
        XCTAssertTrue(cleared, "StoreKit session transactions must be cleared before asserting on restore")

        let restored = try await manager.restorePurchases(sync: {})

        XCTAssertFalse(restored)
        XCTAssertFalse(manager.isPro)
    }

    @MainActor
    func testRestoreSurfacesSyncErrorOnlyWhenNothingWasFound() async throws {
        _ = try makeSession()
        let manager = StoreKitManager(defaults: makeDefaults(), startImmediately: false)
        let cleared = await refresh(manager, until: { !manager.isPro })
        XCTAssertTrue(cleared, "StoreKit session transactions must be cleared before asserting on restore")

        do {
            try await manager.restorePurchases(sync: { throw SyncFailure() })
            XCTFail("Expected the sync error to be thrown when nothing is owned")
        } catch is SyncFailure {
            // expected
        }

        try await manager.purchasePro()
        let restored = try await manager.restorePurchases(sync: { throw SyncFailure() })
        XCTAssertTrue(restored, "A locally known purchase must still restore when the network sync fails")
    }

    // MARK: - Refund / revocation

    @MainActor
    func testRefundedPurchaseRevokesPro() async throws {
        let session = try makeSession()
        let defaults = makeDefaults()
        let manager = StoreKitManager(defaults: defaults, startImmediately: false)
        try await manager.purchasePro()
        XCTAssertTrue(manager.isPro)

        let latest = await Transaction.latest(for: ProProduct.lifetime.rawValue)
        guard case .verified(let transaction)? = latest else {
            return XCTFail("Expected a verified lifetime transaction")
        }
        try session.refundTransaction(identifier: UInt(transaction.id))

        let locked = await refresh(manager, until: { !manager.isPro })
        XCTAssertTrue(locked, "Pro must be revoked after a refund")
        XCTAssertEqual(manager.entitlement, .none)

        // The cache is cleared too, so a relaunch doesn't resurrect Pro.
        let relaunched = StoreKitManager(defaults: defaults, startImmediately: false)
        XCTAssertFalse(relaunched.isPro)
    }

    // MARK: - Pure entitlement resolution

    func testResolverGrantsLifetimeForOwnedProduct() {
        let result = EntitlementResolver.resolve([EntitlementSnapshot(productID: "pro.lifetime")])
        XCTAssertEqual(result, .lifetime)
    }

    func testResolverIgnoresRevokedTransactions() {
        let revoked = EntitlementSnapshot(productID: "pro.lifetime", revocationDate: Date())
        XCTAssertEqual(EntitlementResolver.resolve([revoked]), .none)
    }

    func testResolverIgnoresUnknownProducts() {
        let legacy = EntitlementSnapshot(productID: "com.dashcast.lifetime")
        XCTAssertEqual(EntitlementResolver.resolve([legacy]), .none)
        XCTAssertEqual(EntitlementResolver.resolve([]), .none)
    }

    func testResolverKeepsProWhenAnyValidTransactionRemains() {
        let snapshots = [
            EntitlementSnapshot(productID: "pro.lifetime", revocationDate: Date()),
            EntitlementSnapshot(productID: "pro.lifetime"),
        ]
        XCTAssertEqual(EntitlementResolver.resolve(snapshots), .lifetime)
    }

    @MainActor
    func testStoreErrorsHaveUserFacingDescriptions() {
        XCTAssertNotNil(StoreKitManager.StoreError.productNotFound.errorDescription)
        XCTAssertNotNil(StoreKitManager.StoreError.failedVerification.errorDescription)
    }
}
