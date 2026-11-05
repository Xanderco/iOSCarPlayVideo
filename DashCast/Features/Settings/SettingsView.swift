import SwiftUI

// MARK: - Links & preferences shared by Settings and onboarding

public enum AppLinks {
    /// Hosted privacy policy (also linked from the paywall). Must be live before App Store submission.
    public static let privacyPolicy = URL(string: "https://dashcast.app/privacy")!
    /// Apple's standard Licensed Application End User License Agreement.
    public static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    public static let supportEmail = "support@dashcast.app"

    public static var feedbackMail: URL {
        URL(string: "mailto:\(supportEmail)?subject=DashCast%20Feedback%20(\(appVersion))") ?? URL(string: "mailto:\(supportEmail)")!
    }

    public static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

public enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, dark, light

    public static let storageKey = "dashcast.appearance"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

/// Screens reachable from Settings. Also used for `-initialTab drive|widgets|sounds` deep links.
public enum SettingsRoute: String, Hashable, CaseIterable {
    case tripLog
    case carScreen
    case chime
    case safety
    case privacy
    case usage
}

// MARK: - Settings

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var store = StoreKitManager.shared
    @AppStorage(AppearancePreference.storageKey) private var appearanceRaw: String = AppearancePreference.dark.rawValue
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding: Bool = false

    @State private var path: [SettingsRoute] = []
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    public init() {}

    private var isPro: Bool { appState.isProLifetimeUnlocked || store.isPro }

    private var speedUnitBinding: Binding<Bool> {
        Binding(
            get: { appState.useMilesPerHour },
            set: { appState.setSpeedUnit(milesPerHour: $0) }
        )
    }

    public var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    proCard
                }

                Section {
                    Picker(selection: speedUnitBinding) {
                        Text("km/h").tag(false)
                        Text("mph").tag(true)
                    } label: {
                        Label("Speed units", systemImage: "speedometer")
                    }
                    NavigationLink(value: SettingsRoute.safety) {
                        Label("Passenger safety", systemImage: "person.2.fill")
                    }
                } header: {
                    Text("Car")
                }

                Section {
                    Picker(selection: $appearanceRaw) {
                        ForEach(AppearancePreference.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    } label: {
                        Label("Theme", systemImage: "circle.lefthalf.filled")
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("The player, car mode and the car display always stay dark.")
                }

                Section {
                    NavigationLink(value: SettingsRoute.carScreen) {
                        extraRow(title: "Car Screen", subtitle: "What the car display shows between videos", systemImage: "rectangle.inset.filled")
                    }
                    NavigationLink(value: SettingsRoute.chime) {
                        extraRow(title: "Car Chime", subtitle: "A short sound when your iPhone connects", systemImage: "bell.badge.fill")
                    }
                    NavigationLink(value: SettingsRoute.tripLog) {
                        extraRow(title: "Trip Log", subtitle: "Passenger-recorded trips, kept on this iPhone", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    }
                } header: {
                    Text("Car Extras")
                } footer: {
                    Text("Optional tools. Nothing here leaves your iPhone.")
                }

                Section {
                    Button {
                        restore()
                    } label: {
                        HStack {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                            Spacer()
                            if isRestoring { ProgressView() }
                        }
                    }
                    .disabled(isRestoring)
                } header: {
                    Text("Purchases")
                }

                Section {
                    Link(destination: AppLinks.feedbackMail) {
                        Label("Send Feedback", systemImage: "envelope.fill")
                    }
                    NavigationLink(value: SettingsRoute.privacy) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    Link(destination: AppLinks.termsOfUse) {
                        Label("Terms of Use", systemImage: "doc.text.fill")
                    }
                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Label("Show Welcome Again", systemImage: "sparkles")
                    }
                    LabeledContent("Version", value: AppLinks.appVersion)
                } header: {
                    Text("Help & About")
                }

                #if DEBUG
                Section {
                    NavigationLink(value: SettingsRoute.usage) {
                        Label("On-device usage stats", systemImage: "chart.bar.fill")
                    }
                } header: {
                    Text("Developer")
                }
                #endif
            }
            .tint(Color.dcAccent)
            .scrollContentBackground(.hidden)
            .background(Color.dcBackgroundElevated.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsRoute.self) { route in
                destination(for: route)
            }
            .onAppear(perform: consumeDeepLink)
            .onChange(of: appState.settingsDeepLink) { _, _ in
                consumeDeepLink()
            }
            .alert("Restore Purchases", isPresented: Binding(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }

    // MARK: Pro card

    @ViewBuilder
    private var proCard: some View {
        if isPro {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(Color.dcPro)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text("DashCast Pro")
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcTextPrimary)
                    Text("Unlocked on this Apple ID. Thank you!")
                        .font(DSTypography.subheadline)
                        .foregroundStyle(Color.dcTextSecondary)
                }
            }
            .padding(.vertical, DSSpacing.xs)
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                HStack(spacing: DSSpacing.sm) {
                    Text("PRO")
                        .font(DSTypography.badge)
                        .foregroundStyle(Color.dcOnAccent)
                        .padding(.horizontal, DSSpacing.sm)
                        .padding(.vertical, DSSpacing.xxs)
                        .background(Color.dcPro, in: RoundedRectangle(cornerRadius: DSRadius.xs, style: .continuous))
                    Text("DashCast Pro")
                        .font(DSTypography.title3)
                        .foregroundStyle(Color.dcTextPrimary)
                }
                Text("One purchase, no subscription. Unlocks car mode and every Pro feature, now and later.")
                    .font(DSTypography.subheadline)
                    .foregroundStyle(Color.dcTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton("See what's included", systemImage: "sparkles", kind: .primary, size: .compact) {
                    appState.showPaywall = true
                }
            }
            .padding(.vertical, DSSpacing.sm)
        }
    }

    private func extraRow(title: String, subtitle: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(title)
                    .foregroundStyle(Color.dcTextPrimary)
                Text(subtitle)
                    .font(DSTypography.footnote)
                    .foregroundStyle(Color.dcTextSecondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }

    // MARK: Navigation

    @ViewBuilder
    private func destination(for route: SettingsRoute) -> some View {
        switch route {
        case .tripLog: TripLogView()
        case .carScreen: CarScreenView()
        case .chime: CarChimeView()
        case .safety: SafetyNoticeView()
        case .privacy: PrivacyPolicyView()
        case .usage: UsageMetricsView()
        }
    }

    private func consumeDeepLink() {
        guard let route = appState.settingsDeepLink else { return }
        appState.settingsDeepLink = nil
        path = [route]
    }

    // MARK: Restore

    private func restore() {
        isRestoring = true
        Task { @MainActor in
            defer { isRestoring = false }
            do {
                // StoreKitManager (#24) mirrors the entitlement into AppState itself.
                if try await store.restorePurchases() {
                    restoreMessage = "Your DashCast Pro purchase has been restored."
                } else {
                    restoreMessage = "No previous DashCast Pro purchase was found for this Apple Account."
                }
            } catch {
                restoreMessage = error.localizedDescription
            }
        }
    }
}

#Preview("Settings") {
    SettingsView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
