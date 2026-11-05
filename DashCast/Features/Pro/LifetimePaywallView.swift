import SwiftUI
import StoreKit

public struct LifetimePaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var storeKit = StoreKitManager.shared

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        valueComparisonCard

                        featuresList

                        purchaseCTASection

                        legalLinks
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.dashTextMuted)
                    }
                }
            }
            .alert("Purchase Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Welcome to DashCast Pro!", isPresented: $showingSuccess) {
                Button("Let's Drive!", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Lifetime access is permanently unlocked on all your devices.")
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.dashGold.opacity(0.15))
                    .frame(width: 90, height: 90)

                Image(systemName: "crown.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(LinearGradient.dashProGoldGradient)
                    .shadow(color: Color.dashGold.opacity(0.6), radius: 14)
            }

            VStack(spacing: 6) {
                Text("DashCast Pro")
                    .font(ThemeFonts.speedDisplay(size: 32))
                    .foregroundStyle(Color.dashTextPrimary)

                Text("Pay Once · Own Forever")
                    .font(ThemeFonts.hudTitle(size: 16))
                    .foregroundStyle(Color.dashGold)
                    .tracking(0.5)
            }
        }
    }

    private var valueComparisonCard: some View {
        AutomotiveCard(cornerRadius: 18, borderColor: Color.dashGold.opacity(0.3)) {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Traditional Apps")
                            .font(ThemeFonts.hudCaption(size: 13))
                            .foregroundStyle(Color.dashTextMuted)
                        Text("$4.99 / Month")
                            .font(ThemeFonts.hudStat(size: 17))
                            .strikethrough()
                            .foregroundStyle(Color.dashRed)
                        Text("$59.88 every year forever")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dashTextMuted)
                    }

                    Spacer()

                    Divider()
                        .frame(height: 50)
                        .background(Color.dashBorder)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("DashCast Lifetime")
                            .font(ThemeFonts.hudCaption(size: 13))
                            .foregroundStyle(Color.dashGold)
                            .fontWeight(.bold)
                        Text(storeKit.lifetimeProduct?.displayPrice ?? "$19.99")
                            .font(ThemeFonts.hudStat(size: 22))
                            .foregroundStyle(Color.dashGreen)
                        Text("One single payment")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.dashGreen)
                    }
                }

                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.dashGold)
                    Text("Save over $100 in the first 2 years alone")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.dashGold)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.dashGold.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var featuresList: some View {
        VStack(spacing: 12) {
            featureRow(icon: "play.tv.fill", title: "Unlimited IPTV & Local Video Cast", subtitle: "Import any M3U playlist & Photos/Files videos")
            featureRow(icon: "car.side.fill", title: "Car Display & External Screen Output", subtitle: "For passengers or while parked, on compatible car screens")
            featureRow(icon: "gauge.with.dots.needle.67percent", title: "Drive Stats & Trip History", subtitle: "Speed, distance and smooth-driving score for every trip")
            featureRow(icon: "sparkle", title: "All Car Widgets & Live Wallpapers", subtitle: "Every vehicle design, plate, countdown & sticker")
            featureRow(icon: "speaker.wave.3.fill", title: "Full Sound Library & Shortcuts Triggers", subtitle: "Arrival, connect & disconnect sounds, played automatically")
            featureRow(icon: "checkmark.seal.fill", title: "All Future Updates Included", subtitle: "Never pay another cent for new features")
        }
        .padding()
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.dashYellow)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.dashTextPrimary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashTextSecondary)
            }

            Spacer()
        }
    }

    private var purchaseCTASection: some View {
        VStack(spacing: 14) {
            let priceText = storeKit.lifetimeProduct?.displayPrice ?? "$19.99"
            GlowButton(
                title: storeKit.isLoading ? "Connecting to App Store..." : "Own DashCast Forever · \(priceText)",
                iconName: "crown.fill",
                gradient: .dashProGoldGradient
            ) {
                Task {
                    do {
                        let success = try await storeKit.purchaseLifetime()
                        if success {
                            appState.unlockProLifetime()
                            showingSuccess = true
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
            .disabled(storeKit.isLoading)

            Button {
                Task {
                    await storeKit.restorePurchases()
                    if storeKit.isPurchased {
                        appState.unlockProLifetime()
                        showingSuccess = true
                    }
                }
            } label: {
                Text("Restore Previous Purchase")
                    .font(ThemeFonts.hudCaption(size: 14))
                    .foregroundStyle(Color.dashTextMuted)
                    .underline()
            }
            .disabled(storeKit.isLoading)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
            Text("·").foregroundStyle(Color.dashTextMuted)
            Link("Terms of Use (EULA)", destination: LegalLinks.termsOfUse)
        }
        .font(.system(size: 12))
        .foregroundStyle(Color.dashTextMuted)
        .padding(.top, 8)
    }
}
