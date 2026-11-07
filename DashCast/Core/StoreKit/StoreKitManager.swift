import Foundation
import StoreKit

// MARK: - Product

/// DashCast sells exactly one product: a one-time, non-consumable "DashCast Pro" unlock.
/// No subscriptions. The raw value is the App Store Connect product ID and must match
/// `DashCastStore.storekit`.
public enum ProProduct: String, CaseIterable, Sendable {
    case lifetime = "pro.lifetime"

    public static var allIDs: Set<String> { Set(allCases.map(\.rawValue)) }
}

// MARK: - Entitlement model

public enum ProEntitlement: String, Equatable, Codable, Sendable {
    case none
    case lifetime

    public var isPro: Bool { self == .lifetime }
}

/// StoreKit-independent copy of the `Transaction` fields that matter for the entitlement.
/// Keeping resolution pure makes refund / revocation logic testable without a StoreKit session.
public struct EntitlementSnapshot: Equatable, Sendable {
    public var productID: String
    public var revocationDate: Date?

    public init(productID: String, revocationDate: Date? = nil) {
        self.productID = productID
        self.revocationDate = revocationDate
    }

    public init(_ transaction: Transaction) {
        self.init(productID: transaction.productID, revocationDate: transaction.revocationDate)
    }
}

public enum EntitlementResolver {
    /// Pro is active when there is a non-revoked transaction for the lifetime product.
    /// Refunded / revoked purchases (Family Sharing removal included) unlock nothing.
    public static func resolve(_ snapshots: [EntitlementSnapshot]) -> ProEntitlement {
        let owned = snapshots.contains {
            $0.productID == ProProduct.lifetime.rawValue && $0.revocationDate == nil
        }
        return owned ? .lifetime : .none
    }
}

// MARK: - Manager

/// StoreKit 2 store: loads the product, purchases, restores, and keeps the Pro entitlement in
/// sync through `Transaction.currentEntitlements` and the `Transaction.updates` listener.
@MainActor
public final class StoreKitManager: ObservableObject {
    public static let shared = StoreKitManager(onEntitlementChange: { entitlement in
        // Keep the app-wide flag that other screens read in step with StoreKit, in both
        // directions, so a refund locks Pro again.
        if AppState.shared.isProLifetimeUnlocked != entitlement.isPro {
            AppState.shared.isProLifetimeUnlocked = entitlement.isPro
        }
    })

    public enum LoadState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    public enum PurchaseOutcome: Equatable {
        case purchased
        /// Awaiting approval (Ask to Buy / SCA). The listener unlocks Pro once approved.
        case pending
        case cancelled
    }

    public enum StoreError: LocalizedError, Equatable {
        case productNotFound
        case failedVerification

        public var errorDescription: String? {
            switch self {
            case .productNotFound:
                return "DashCast Pro isn't available from the App Store right now. Please try again later."
            case .failedVerification:
                return "The App Store couldn't verify this purchase."
            }
        }
    }

    /// Performs the App Store purchase. The paywall injects SwiftUI's `PurchaseAction` so the
    /// confirmation sheet is anchored to the right scene; tests fall back to `Product.purchase()`.
    public typealias PurchasePerformer = @MainActor (Product) async throws -> Product.PurchaseResult

    @Published public private(set) var proProduct: Product?
    @Published public private(set) var loadState: LoadState = .idle
    @Published public private(set) var entitlement: ProEntitlement = .none
    @Published public private(set) var isPurchasing: Bool = false
    @Published public private(set) var isRestoring: Bool = false

    public var isPro: Bool { entitlement.isPro }

    private let defaults: UserDefaults
    private let onEntitlementChange: (@MainActor (ProEntitlement) -> Void)?
    private var updatesTask: Task<Void, Never>?

    static let cacheKey = "dashcast_pro_entitlement_cache_v2"

    public init(defaults: UserDefaults = .standard,
                startImmediately: Bool = true,
                onEntitlementChange: (@MainActor (ProEntitlement) -> Void)? = nil) {
        self.defaults = defaults
        self.onEntitlementChange = onEntitlementChange

        // Instant offline launch; StoreKit is re-checked right after and wins.
        if let raw = defaults.string(forKey: Self.cacheKey),
           let cached = ProEntitlement(rawValue: raw) {
            self.entitlement = cached
        }
        onEntitlementChange?(entitlement)

        if startImmediately {
            start()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Starts the transaction listener and refreshes the product and entitlement.
    public func start() {
        guard updatesTask == nil else { return }
        updatesTask = listenForTransactions()
        Task {
            await finishUnfinishedTransactions()
            await loadProducts()
            await refreshEntitlements()
        }
    }

    public func stop() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    // MARK: Product

    public func loadProducts() async {
        loadState = .loading
        do {
            let fetched = try await Product.products(for: ProProduct.allIDs)
            proProduct = fetched.first { $0.id == ProProduct.lifetime.rawValue }
            loadState = proProduct == nil
                ? .failed("DashCast Pro couldn't be loaded from the App Store.")
                : .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: Purchase

    @discardableResult
    public func purchasePro(using performer: PurchasePerformer? = nil) async throws -> PurchaseOutcome {
        if proProduct == nil { await loadProducts() }
        guard let product = proProduct else { throw StoreError.productNotFound }

        isPurchasing = true
        defer { isPurchasing = false }

        let result: Product.PurchaseResult
        if let performer {
            result = try await performer(product)
        } else {
            result = try await product.purchase()
        }

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw StoreError.failedVerification
            }
            await transaction.finish()
            await refreshEntitlements()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    // MARK: Restore

    /// Syncs with the App Store and re-reads entitlements. Returns whether Pro is active afterwards.
    /// `sync` is injectable for tests; production uses `AppStore.sync()`.
    @discardableResult
    public func restorePurchases(sync: (() async throws -> Void)? = nil) async throws -> Bool {
        isRestoring = true
        defer { isRestoring = false }

        var syncError: Error?
        do {
            if let sync {
                try await sync()
            } else {
                try await AppStore.sync()
            }
        } catch {
            syncError = error
        }

        // Local entitlements may already hold the purchase even if the network sync failed.
        await refreshEntitlements()
        if !isPro, let syncError {
            throw syncError
        }
        return isPro
    }

    // MARK: Entitlements

    public func refreshEntitlements() async {
        var snapshots: [EntitlementSnapshot] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                snapshots.append(EntitlementSnapshot(transaction))
            }
        }
        // Debug device builds from Xcode count as Pro (see DeveloperProUnlock); Release never does.
        apply(DeveloperProUnlock.isActive ? .lifetime : EntitlementResolver.resolve(snapshots))
    }

    func apply(_ newValue: ProEntitlement) {
        if entitlement != newValue {
            entitlement = newValue
        }
        defaults.set(newValue.rawValue, forKey: Self.cacheKey)
        onEntitlementChange?(newValue)
    }

    private func finishUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            // Ask-to-Buy approvals, refunds, Family Sharing changes and purchases made on
            // other devices all arrive here.
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
    }
}
