import SwiftUI

public struct LifetimePaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(LinearGradient.dashProGoldGradient)
                        .shadow(color: Color.dashGold.opacity(0.5), radius: 16)

                    VStack(spacing: 8) {
                        Text("DashCast Pro")
                            .font(ThemeFonts.speedDisplay(size: 34))
                            .foregroundStyle(Color.dashTextPrimary)

                        Text("One-Time Purchase · Own Forever")
                            .font(ThemeFonts.hudTitle(size: 16))
                            .foregroundStyle(Color.dashGold)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        featureRow(icon: "checkmark.circle.fill", title: "Unlimited IPTV & Local Video Cast")
                        featureRow(icon: "checkmark.circle.fill", title: "Full CarPlay & External Screen Support")
                        featureRow(icon: "checkmark.circle.fill", title: "Unlimited Territory Hex Claims")
                        featureRow(icon: "checkmark.circle.fill", title: "100+ Car Brands & Custom Widgets")
                        featureRow(icon: "checkmark.circle.fill", title: "Viral Sounds & Shortcuts Triggers")
                        featureRow(icon: "xmark.circle.fill", title: "NO Subscriptions · NO Monthly Fees", isNegative: true)
                    }
                    .padding()
                    .background(Color.dashSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Spacer()

                    VStack(spacing: 12) {
                        GlowButton(
                            title: "Unlock Lifetime Access - $19.99",
                            iconName: "sparkles",
                            gradient: .dashProGoldGradient
                        ) {
                            appState.unlockProLifetime()
                            dismiss()
                        }

                        Button("Restore Purchases") {
                            // Will be implemented in StoreKit feature
                        }
                        .font(ThemeFonts.hudCaption(size: 14))
                        .foregroundStyle(Color.dashTextMuted)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.dashTextSecondary)
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, isNegative: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(isNegative ? Color.dashGreen : Color.dashCyan)
                .font(.system(size: 18, weight: .bold))

            Text(title)
                .font(ThemeFonts.hudCaption(size: 14))
                .foregroundStyle(Color.dashTextPrimary)
        }
    }
}
