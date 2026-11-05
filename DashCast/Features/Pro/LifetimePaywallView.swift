import SwiftUI
import StoreKit

/// Legal links shown on the paywall (App Review guideline 3.1.2 / 5.1.1).
public enum PaywallLegal {
    /// Apple's standard EULA. Swap for a custom EULA URL if one is set in App Store Connect.
    public static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    public static let privacyPolicy = URL(string: "https://dashcast.app/privacy")!
}

/// DashCast Pro paywall: a single one-time, non-consumable purchase. No subscription.
public struct LifetimePaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchaseAction
    @ObservedObject private var store: StoreKitManager
    @ObservedObject private var gate: EntitlementGate

    @State private var alert: PaywallAlert?

    public init(store: StoreKitManager = .shared, gate: EntitlementGate = .shared) {
        self.store = store
        self.gate = gate
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.dashBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    if let reason = gate.lastBlock?.message, !store.isPro {
                        limitBanner(reason)
                    }
                    noSubscriptionPledge
                    comparisonTable
                    priceAndPurchase
                    finePrint
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 32)
            }

            closeButton
        }
        .task {
            if store.proProduct == nil { await store.loadProducts() }
        }
        .alert(item: $alert) { alert in
            Alert(title: Text(alert.title),
                  message: Text(alert.message),
                  dismissButton: .default(Text("OK")) {
                      if alert.dismissesPaywall { dismiss() }
                  })
        }
    }

    // MARK: Sections

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.dashTextSecondary)
                .frame(width: 34, height: 34)
                .background(Color.dashSurfaceHighlight)
                .clipShape(Circle())
        }
        .padding(.trailing, 16)
        .padding(.top, 12)
        .accessibilityLabel("Close")
        .accessibilityIdentifier("paywall.close")
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "key.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(width: 76, height: 76)
                .background(LinearGradient.dashProGoldGradient)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.dashGold.opacity(0.45), radius: 16, y: 6)

            Text("DashCast Pro")
                .font(ThemeFonts.speedDisplay(size: 30))
                .foregroundStyle(Color.dashTextPrimary)

            Text("Pay once. Own it forever.")
                .font(ThemeFonts.hudTitle(size: 17))
                .foregroundStyle(Color.dashYellow)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func limitBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.dashAmber)
            Text(text)
                .font(ThemeFonts.hudCaption(size: 13))
                .foregroundStyle(Color.dashTextPrimary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.dashAmber.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// The key differentiator, stated plainly and only with things that are true of this purchase.
    private var noSubscriptionPledge: some View {
        AutomotiveCard(cornerRadius: 18, borderColor: Color.dashYellow.opacity(0.35)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("No subscription")
                    .font(ThemeFonts.hudTitle(size: 18))
                    .foregroundStyle(Color.dashTextPrimary)
                pledgeRow("1.circle.fill", "You're charged once, at purchase.")
                pledgeRow("arrow.triangle.2.circlepath", "It never renews, so there's nothing to cancel.")
                pledgeRow("person.3.fill", "Shared with your family through Family Sharing.")
                pledgeRow("iphone.and.arrow.forward", "Restore it free on any device with your Apple Account.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func pledgeRow(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.dashYellow)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.dashTextSecondary)
        }
    }

    private var comparisonTable: some View {
        let limits = gate.limits
        return VStack(spacing: 0) {
            comparisonRow("", free: "Free", pro: "Pro", isHeader: true)
            Divider().background(Color.dashBorder)
            comparisonRow("Playlist sources",
                          free: "\(limits.maxPlaylistSources)",
                          pro: "Unlimited")
            Divider().background(Color.dashBorder)
            comparisonRow("Casting time",
                          free: "\(limits.dailyCastingMinutes) min / day",
                          pro: "Unlimited")
        }
        .padding(.horizontal, 14)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func comparisonRow(_ title: LocalizedStringKey, free: LocalizedStringKey, pro: LocalizedStringKey, isHeader: Bool = false) -> some View {
        HStack {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color.dashTextPrimary)
            Text(free)
                .frame(width: 92)
                .foregroundStyle(Color.dashTextSecondary)
            Text(pro)
                .frame(width: 84)
                .foregroundStyle(isHeader ? Color.dashYellow : Color.dashTextPrimary)
        }
        .font(isHeader ? ThemeFonts.hudCaption(size: 12).weight(.bold) : .system(size: 14, weight: .medium))
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var priceAndPurchase: some View {
        VStack(spacing: 12) {
            if store.isPro {
                Label("DashCast Pro is unlocked", systemImage: "checkmark.seal.fill")
                    .font(ThemeFonts.hudTitle(size: 17))
                    .foregroundStyle(Color.dashGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else if let product = store.proProduct {
                VStack(spacing: 2) {
                    Text(product.displayPrice)
                        .font(ThemeFonts.hudStat(size: 34))
                        .foregroundStyle(Color.dashTextPrimary)
                    Text("one-time purchase")
                        .font(ThemeFonts.hudCaption(size: 13))
                        .foregroundStyle(Color.dashTextSecondary)
                }
                .accessibilityElement(children: .combine)

                GlowButton(
                    title: store.isPurchasing ? "Contacting the App Store…" : "Unlock Pro for \(product.displayPrice)",
                    iconName: "lock.open.fill",
                    gradient: .dashProGoldGradient
                ) {
                    buy()
                }
                .disabled(store.isPurchasing || store.isRestoring)
                .accessibilityIdentifier("paywall.purchase")
            } else if case .failed(let message) = store.loadState {
                VStack(spacing: 10) {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dashTextSecondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await store.loadProducts() }
                    }
                    .font(ThemeFonts.hudTitle(size: 15))
                    .foregroundStyle(Color.dashYellow)
                }
                .padding(.vertical, 8)
            } else {
                ProgressView()
                    .tint(Color.dashYellow)
                    .padding(.vertical, 20)
            }

            Button {
                restore()
            } label: {
                Text(store.isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(ThemeFonts.hudCaption(size: 14))
                    .foregroundStyle(Color.dashTextSecondary)
                    .underline()
            }
            .disabled(store.isPurchasing || store.isRestoring)
            .accessibilityIdentifier("paywall.restore")
        }
    }

    private var finePrint: some View {
        VStack(spacing: 10) {
            if let product = store.proProduct, !store.isPro {
                Text("\(product.displayPrice) is charged once to your Apple Account when you confirm the purchase. This is not a subscription and will never renew.")
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 14) {
                Link("Terms of Use (EULA)", destination: PaywallLegal.termsOfUse)
                Text("·")
                Link("Privacy Policy", destination: PaywallLegal.privacyPolicy)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(Color.dashTextMuted)
        .tint(Color.dashTextSecondary)
    }

    // MARK: Actions

    private func buy() {
        Task {
            do {
                let outcome = try await store.purchasePro { product in
                    try await purchaseAction(product)
                }
                switch outcome {
                case .purchased:
                    alert = .purchased
                case .pending:
                    alert = .pending
                case .cancelled:
                    break
                }
            } catch {
                alert = .error(error.localizedDescription)
            }
        }
    }

    private func restore() {
        Task {
            do {
                let restored = try await store.restorePurchases()
                alert = restored ? .restored : .nothingToRestore
            } catch {
                alert = .error(error.localizedDescription)
            }
        }
    }
}

private enum PaywallAlert: Identifiable {
    case purchased, restored, pending, nothingToRestore
    case error(String)

    var id: String { title + message }

    var title: String {
        switch self {
        case .purchased: return "Welcome to DashCast Pro"
        case .restored: return "Purchase Restored"
        case .pending: return "Waiting for Approval"
        case .nothingToRestore: return "Nothing to Restore"
        case .error: return "Something Went Wrong"
        }
    }

    var message: String {
        switch self {
        case .purchased: return "Pro is unlocked on this device and on any device signed in to your Apple Account."
        case .restored: return "DashCast Pro is unlocked again."
        case .pending: return "Your purchase is waiting for approval. Pro unlocks automatically once it's approved."
        case .nothingToRestore: return "No DashCast Pro purchase was found for this Apple Account."
        case .error(let message): return message
        }
    }

    var dismissesPaywall: Bool {
        switch self {
        case .purchased, .restored: return true
        default: return false
        }
    }
}
