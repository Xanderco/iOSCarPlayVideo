import XCTest
@testable import DashCast

final class StoreKitTests: XCTestCase {
    @MainActor
    func testStoreKitProductID() {
        XCTAssertEqual(StoreKitManager.lifetimeProductID, "com.dashcast.lifetime")
    }

    @MainActor
    func testCachedEntitlementBehavior() {
        let testDefaults = UserDefaults.standard
        let cachedKey = "dashcast_pro_lifetime_entitlement_cached"

        // Store true and verify initial load
        testDefaults.set(true, forKey: cachedKey)
        let manager = StoreKitManager()
        XCTAssertTrue(manager.isPurchased)

        // Store false and verify initial load
        testDefaults.set(false, forKey: cachedKey)
        let freshManager = StoreKitManager()
        XCTAssertFalse(freshManager.isPurchased)
    }

    @MainActor
    func testStoreKitErrorDescription() {
        let error = StoreKitManager.StoreKitError.productNotFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("product could not be found"))
    }
}
