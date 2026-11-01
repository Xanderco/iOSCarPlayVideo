import Foundation
import StoreKit

@MainActor
public final class StoreKitManager: ObservableObject {
    public static let shared = StoreKitManager()

    public static let lifetimeProductID = "com.dashcast.lifetime"

    @Published public private(set) var products: [Product] = []
    @Published public private(set) var isPurchased: Bool = false
    @Published public private(set) var isLoading: Bool = false
    @Published public var errorMessage: String?

    private var transactionListener: Task<Void, Error>?
    private let entitlementKey = "dashcast_pro_lifetime_entitlement_cached"

    public init() {
        // Load cached entitlement immediately for instant offline launch
        self.isPurchased = UserDefaults.standard.bool(forKey: entitlementKey)
        self.transactionListener = listenForTransactions()

        Task {
            await fetchProducts()
            await updatePurchasedStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    public var lifetimeProduct: Product? {
        products.first(where: { $0.id == Self.lifetimeProductID })
    }

    public func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await Product.products(for: [Self.lifetimeProductID])
            self.products = fetched
        } catch {
            self.errorMessage = "Failed to load product: \(error.localizedDescription)"
        }
    }

    public func purchaseLifetime() async throws -> Bool {
        guard let product = lifetimeProduct ?? products.first else {
            throw StoreKitError.productNotFound
        }

        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedStatus()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    public func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchasedStatus()
        } catch {
            self.errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    public func updatePurchasedStatus() async {
        var purchased = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == Self.lifetimeProductID && transaction.revocationDate == nil {
                    purchased = true
                    break
                }
            } catch {
                continue
            }
        }

        self.isPurchased = purchased
        UserDefaults.standard.set(purchased, forKey: entitlementKey)

        if purchased {
            AppState.shared.unlockProLifetime()
        }
    }

    public func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await MainActor.run {
                        try self.checkVerified(result)
                    }
                    await transaction.finish()
                    await self.updatePurchasedStatus()
                } catch {
                    // Ignore unverified or cancelled
                }
            }
        }
    }

    public enum StoreKitError: LocalizedError {
        case productNotFound

        public var errorDescription: String? {
            switch self {
            case .productNotFound:
                return "The lifetime product could not be found."
            }
        }
    }
}
