import SwiftUI
import StoreKit

/// Localized copy keys for `MeHomeView`.
public enum MeHomeCopy {
    nonisolated public static let navigationTitleString = "DashCast"
    nonisolated public static let proLifetimeBadgeString = "PRO · LIFETIME"
    nonisolated public static let freeBadgeString = "FREE"
    nonisolated public static let drivenLabelString = "driven"
    nonisolated public static let drivesLabelString = "drives"
    nonisolated public static let avgScoreLabelString = "avg score"
    nonisolated public static let proBannerActiveTitleString = "DashCast PRO Active"
    nonisolated public static let proBannerTitleString = "DashCast PRO"
    nonisolated public static let proBannerActiveSubtitleString = "All features unlocked forever"
    nonisolated public static let proBannerSubtitleString = "Unlock everything on your car screen"
    nonisolated public static let managePassButtonString = "Manage Pass"
    nonisolated public static let upgradeNowButtonString = "Upgrade Now"
    nonisolated public static let menuDriveString = "Drive"
    nonisolated public static let menuMediaServersString = "Media Servers"
    nonisolated public static let menuSettingsString = "Settings"
    nonisolated public static let menuAboutString = "About"
    nonisolated public static let menuFeedbackString = "Feedback"
    nonisolated public static let menuRateUsString = "Rate Us"
    nonisolated public static let menuShareString = "Share DashCast"
    nonisolated public static let shareMessageString = "DashCast – play your own videos on the car display (passengers & parked only)."
    nonisolated public static let languageLabelString = "Language"
    nonisolated public static let systemLanguageString = "System"
    nonisolated public static let englishLanguageString = "English"
    nonisolated public static let spanishLanguageString = "Español"
    nonisolated public static let speedUnitsLabelString = "Speed Units"
    nonisolated public static let unitsPickerTitleString = "Units"
    nonisolated public static let kmhUnitString = "KM/H"
    nonisolated public static let mphUnitString = "MPH"
    nonisolated public static let restoringPurchasesString = "Restoring…"
    nonisolated public static let restorePurchasesString = "Restore Purchases"
    nonisolated public static let restoreSuccessString = "Your DashCast Pro purchase has been restored."
    nonisolated public static let restoreNotFoundString = "No previous DashCast Pro purchase was found for this Apple Account."
    nonisolated public static let okButtonString = "OK"
    nonisolated public static let doneButtonString = "Done"
    nonisolated public static let versionFormatString = "Version %@"
    nonisolated public static let privacyPolicyString = "Privacy Policy"
    nonisolated public static let termsOfUseString = "Terms of Use (EULA)"
    nonisolated public static let supportString = "Support"
    nonisolated public static let passengerSafetyNoticeString = "Passenger Safety Notice"

    nonisolated public static let allLocalizationKeys: [String] = [
        navigationTitleString,
        proLifetimeBadgeString,
        freeBadgeString,
        drivenLabelString,
        drivesLabelString,
        avgScoreLabelString,
        proBannerActiveTitleString,
        proBannerTitleString,
        proBannerActiveSubtitleString,
        proBannerSubtitleString,
        managePassButtonString,
        upgradeNowButtonString,
        menuDriveString,
        menuMediaServersString,
        menuSettingsString,
        menuAboutString,
        menuFeedbackString,
        menuRateUsString,
        menuShareString,
        shareMessageString,
        languageLabelString,
        systemLanguageString,
        englishLanguageString,
        spanishLanguageString,
        speedUnitsLabelString,
        unitsPickerTitleString,
        kmhUnitString,
        mphUnitString,
        restoringPurchasesString,
        restorePurchasesString,
        restoreSuccessString,
        restoreNotFoundString,
        okButtonString,
        doneButtonString,
        versionFormatString,
        privacyPolicyString,
        termsOfUseString,
        supportString,
        passengerSafetyNoticeString
    ]

    @MainActor public static var navigationTitleKey: LocalizedStringKey { LocalizedStringKey(navigationTitleString) }
    @MainActor public static var proLifetimeBadgeKey: LocalizedStringKey { LocalizedStringKey(proLifetimeBadgeString) }
    @MainActor public static var freeBadgeKey: LocalizedStringKey { LocalizedStringKey(freeBadgeString) }
    @MainActor public static var drivenLabelKey: LocalizedStringKey { LocalizedStringKey(drivenLabelString) }
    @MainActor public static var drivesLabelKey: LocalizedStringKey { LocalizedStringKey(drivesLabelString) }
    @MainActor public static var avgScoreLabelKey: LocalizedStringKey { LocalizedStringKey(avgScoreLabelString) }
    @MainActor public static var proBannerActiveTitleKey: LocalizedStringKey { LocalizedStringKey(proBannerActiveTitleString) }
    @MainActor public static var proBannerTitleKey: LocalizedStringKey { LocalizedStringKey(proBannerTitleString) }
    @MainActor public static var proBannerActiveSubtitleKey: LocalizedStringKey { LocalizedStringKey(proBannerActiveSubtitleString) }
    @MainActor public static var proBannerSubtitleKey: LocalizedStringKey { LocalizedStringKey(proBannerSubtitleString) }
    @MainActor public static var managePassButtonKey: LocalizedStringKey { LocalizedStringKey(managePassButtonString) }
    @MainActor public static var upgradeNowButtonKey: LocalizedStringKey { LocalizedStringKey(upgradeNowButtonString) }
    @MainActor public static var menuDriveKey: LocalizedStringKey { LocalizedStringKey(menuDriveString) }
    @MainActor public static var menuMediaServersKey: LocalizedStringKey { LocalizedStringKey(menuMediaServersString) }
    @MainActor public static var menuSettingsKey: LocalizedStringKey { LocalizedStringKey(menuSettingsString) }
    @MainActor public static var menuAboutKey: LocalizedStringKey { LocalizedStringKey(menuAboutString) }
    @MainActor public static var menuFeedbackKey: LocalizedStringKey { LocalizedStringKey(menuFeedbackString) }
    @MainActor public static var menuRateUsKey: LocalizedStringKey { LocalizedStringKey(menuRateUsString) }
    @MainActor public static var menuShareKey: LocalizedStringKey { LocalizedStringKey(menuShareString) }
    @MainActor public static var shareMessageKey: LocalizedStringKey { LocalizedStringKey(shareMessageString) }
    @MainActor public static var languageLabelKey: LocalizedStringKey { LocalizedStringKey(languageLabelString) }
    @MainActor public static var systemLanguageKey: LocalizedStringKey { LocalizedStringKey(systemLanguageString) }
    @MainActor public static var englishLanguageKey: LocalizedStringKey { LocalizedStringKey(englishLanguageString) }
    @MainActor public static var spanishLanguageKey: LocalizedStringKey { LocalizedStringKey(spanishLanguageString) }
    @MainActor public static var speedUnitsLabelKey: LocalizedStringKey { LocalizedStringKey(speedUnitsLabelString) }
    @MainActor public static var unitsPickerTitleKey: LocalizedStringKey { LocalizedStringKey(unitsPickerTitleString) }
    @MainActor public static var kmhUnitKey: LocalizedStringKey { LocalizedStringKey(kmhUnitString) }
    @MainActor public static var mphUnitKey: LocalizedStringKey { LocalizedStringKey(mphUnitString) }
    @MainActor public static var restoringPurchasesKey: LocalizedStringKey { LocalizedStringKey(restoringPurchasesString) }
    @MainActor public static var restorePurchasesKey: LocalizedStringKey { LocalizedStringKey(restorePurchasesString) }
    @MainActor public static var okButtonKey: LocalizedStringKey { LocalizedStringKey(okButtonString) }
    @MainActor public static var doneButtonKey: LocalizedStringKey { LocalizedStringKey(doneButtonString) }
    @MainActor public static var privacyPolicyKey: LocalizedStringKey { LocalizedStringKey(privacyPolicyString) }
    @MainActor public static var termsOfUseKey: LocalizedStringKey { LocalizedStringKey(termsOfUseString) }
    @MainActor public static var supportKey: LocalizedStringKey { LocalizedStringKey(supportString) }
    @MainActor public static var passengerSafetyNoticeKey: LocalizedStringKey { LocalizedStringKey(passengerSafetyNoticeString) }
}

/// Pure formatting helpers for profile distance and average driving score in `MeHomeView`.
public enum MeProfileMetricsFormatter {
    nonisolated public static func formattedDistance(km: Double, miles: Double, useMilesPerHour: Bool) -> String {
        if useMilesPerHour {
            let safeMiles = (miles.isFinite && miles >= 0) ? miles : 0
            return String(format: "%.1f mi", safeMiles)
        } else {
            let safeKm = (km.isFinite && km >= 0) ? km : 0
            return String(format: "%.1f km", safeKm)
        }
    }

    nonisolated public static func formattedAverageScore(averageScore: Double, tripsCount: Int) -> String {
        guard tripsCount > 0, averageScore.isFinite else { return "–" }
        let clamped = max(0, averageScore)
        return String(format: "%.0f", clamped)
    }
}

private enum MeRestoreAlertContent: Equatable {
    case localized(String)
    case raw(String)
}

public struct MeHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var metricsManager = UsageMetricsManager.shared
    @StateObject private var storeKit = StoreKitManager.shared
    @Environment(\.requestReview) private var requestReview
    @AppStorage(PassengerSafetyNotice.acceptedKey) private var passengerNoticeAccepted = false

    @State private var showingSettings: Bool = false
    @State private var showingAbout: Bool = false
    @State private var showingFeedback: Bool = false
    @State private var restoreMessage: MeRestoreAlertContent?
    @State private var showingDriveDetails: Bool = false
    @State private var showingMediaServers: Bool = false
    @State private var selectedVehicleIndex: Int = 0

    private let vehicles = VehicleCatalogService.shared.vehicles

    public init() {}

    private var currentVehicle: VehicleModel {
        if vehicles.indices.contains(selectedVehicleIndex) {
            return vehicles[selectedVehicleIndex]
        }
        return vehicles.first ?? VehicleModel(
            id: "porsche_911",
            brandId: "porsche",
            name: "911 GT3 RS",
            year: "2024",
            colorName: "Agate Grey",
            carAccentColor: .dashYellow,
            imageName: "car_porsche_911"
        )
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        // Top Profile & Selected Vehicle Card
                        topVehicleProfileCard

                        // PRO Upgrade Banner
                        proUpgradeBanner

                        // Navigation Menu Rows
                        navigationMenuSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 110) // clearance for LiquidCapsuleTabBar
                }
            }
            .navigationTitle(MeHomeCopy.navigationTitleKey)
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingSettings) {
                settingsSheet
            }
            .sheet(isPresented: $showingAbout) {
                aboutSheet
            }
            .sheet(isPresented: $showingFeedback) {
                FeedbackView()
            }
            .sheet(isPresented: $showingDriveDetails) {
                DriveSettingsView()
            }
            .sheet(isPresented: $showingMediaServers) {
                MediaServersHomeView()
            }
        }
    }

    // MARK: - Top Profile & Vehicle Card

    private var topVehicleProfileCard: some View {
        let metrics = metricsManager.metrics
        let distanceStr = MeProfileMetricsFormatter.formattedDistance(
            km: metrics.totalDistanceKm,
            miles: metrics.totalDistanceMiles,
            useMilesPerHour: appState.useMilesPerHour
        )
        let tripsCount = metrics.totalTripsRecorded
        let avgScoreStr = MeProfileMetricsFormatter.formattedAverageScore(
            averageScore: metrics.averageDrivingScore,
            tripsCount: tripsCount
        )

        return VStack(spacing: 16) {
            // Vehicle & Name Row
            HStack(spacing: 14) {
                // Circular Car Thumbnail
                ZStack {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                        .frame(width: 58, height: 58)
                        .overlay(Circle().stroke(Color.dashYellow.opacity(0.4), lineWidth: 1.5))

                    Image(currentVehicle.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 28)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(currentVehicle.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)

                        Spacer()

                        Menu {
                            ForEach(Array(vehicles.enumerated()), id: \.element.id) { index, vehicle in
                                Button(vehicle.name) {
                                    selectedVehicleIndex = index
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.dashTextMuted)
                        }
                    }

                    // Plan Pill Badge (Free / Pro lifetime)
                    HStack(spacing: 4) {
                        Image(systemName: appState.isProLifetimeUnlocked ? "crown.fill" : "person.fill")
                            .font(.system(size: 10))
                        Text(appState.isProLifetimeUnlocked ? MeHomeCopy.proLifetimeBadgeKey : MeHomeCopy.freeBadgeKey)
                            .font(.system(size: 10, weight: .heavy))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.dashYellow.opacity(0.2))
                    .foregroundStyle(Color.dashYellow)
                    .clipShape(Capsule())
                }
            }

            Divider().background(Color.dashBorder.opacity(0.5))

            // 3-Column Stats Row
            HStack {
                statColumn(value: distanceStr, label: MeHomeCopy.drivenLabelKey)
                Divider().frame(height: 28).background(Color.dashBorder)
                statColumn(value: "\(tripsCount)", label: MeHomeCopy.drivesLabelKey)
                Divider().frame(height: 28).background(Color.dashBorder)
                statColumn(value: avgScoreStr, label: MeHomeCopy.avgScoreLabelKey)
            }
        }
        .padding(16)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    private func statColumn(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dashTextPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.dashTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - PRO Upgrade Banner

    private var proUpgradeBanner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.dashYellow, Color.dashAmber],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 125)

            // Background crown watermark
            Image(systemName: "crown.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.white.opacity(0.18))
                .offset(x: 230, y: 10)

            VStack(alignment: .leading, spacing: 6) {
                Text(appState.isProLifetimeUnlocked ? MeHomeCopy.proBannerActiveTitleKey : MeHomeCopy.proBannerTitleKey)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color.black)

                Text(appState.isProLifetimeUnlocked ? MeHomeCopy.proBannerActiveSubtitleKey : MeHomeCopy.proBannerSubtitleKey)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.85))

                Spacer()

                Button {
                    appState.showPaywall = true
                } label: {
                    Text(appState.isProLifetimeUnlocked ? MeHomeCopy.managePassButtonKey : MeHomeCopy.upgradeNowButtonKey)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
            .padding(16)
        }
    }

    // MARK: - Navigation Menu Rows

    private var navigationMenuSection: some View {
        VStack(spacing: 1) {
            menuItemRow(icon: "car.fill", title: MeHomeCopy.menuDriveKey) {
                showingDriveDetails = true
            }

            Divider().background(Color.dashBorder.opacity(0.5))

            menuItemRow(icon: "server.rack", title: MeHomeCopy.menuMediaServersKey) {
                showingMediaServers = true
            }

            Divider().background(Color.dashBorder.opacity(0.5))

            menuItemRow(icon: "gearshape.fill", title: MeHomeCopy.menuSettingsKey) {
                showingSettings = true
            }

            Divider().background(Color.dashBorder.opacity(0.5))

            menuItemRow(icon: "info.circle.fill", title: MeHomeCopy.menuAboutKey) {
                showingAbout = true
            }

            Divider().background(Color.dashBorder.opacity(0.5))

            menuItemRow(icon: "bubble.left.and.bubble.right.fill", title: MeHomeCopy.menuFeedbackKey) {
                showingFeedback = true
            }

            Divider().background(Color.dashBorder.opacity(0.5))

            menuItemRow(icon: "star.fill", title: MeHomeCopy.menuRateUsKey) {
                requestReview()
            }

            Divider().background(Color.dashBorder.opacity(0.5))

            ShareLink(item: LegalLinks.support,
                      subject: Text(MeHomeCopy.navigationTitleKey),
                      message: Text(MeHomeCopy.shareMessageKey)) {
                menuItemLabel(icon: "arrow.up.right.circle.fill", title: MeHomeCopy.menuShareKey)
            }
            .buttonStyle(.plain)
        }
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    private func menuItemRow(icon: String, title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            menuItemLabel(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }

    private func menuItemLabel(icon: String, title: LocalizedStringKey) -> some View {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dashYellow)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.dashTextPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dashTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
    }

    // MARK: - Settings Sheet (Matching SETTINGS.jpeg)

    private var settingsSheet: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 1) {
                            // Language
                            HStack {
                                HStack(spacing: 12) {
                                    Image(systemName: "globe")
                                        .foregroundStyle(Color.dashYellow)
                                    Text(MeHomeCopy.languageLabelKey)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.dashTextPrimary)
                                }

                                Spacer()

                                Picker(MeHomeCopy.languageLabelKey, selection: Binding(
                                    get: { appState.appLanguage },
                                    set: { appState.setLanguage($0) }
                                )) {
                                    Text(MeHomeCopy.systemLanguageKey).tag("system")
                                    Text(MeHomeCopy.englishLanguageKey).tag("en")
                                    Text(MeHomeCopy.spanishLanguageKey).tag("es")
                                }
                                .pickerStyle(.menu)
                                .tint(Color.dashYellow)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider().background(Color.dashBorder.opacity(0.5))

                            // Speed Units MPH / KMH
                            HStack {
                                HStack(spacing: 12) {
                                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                                        .foregroundStyle(Color.dashYellow)
                                    Text(MeHomeCopy.speedUnitsLabelKey)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.dashTextPrimary)
                                }

                                Spacer()

                                Picker(MeHomeCopy.unitsPickerTitleKey, selection: Binding(
                                    get: { appState.useMilesPerHour },
                                    set: { appState.setSpeedUnit(milesPerHour: $0) }
                                )) {
                                    Text(MeHomeCopy.kmhUnitKey).tag(false)
                                    Text(MeHomeCopy.mphUnitKey).tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 130)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider().background(Color.dashBorder.opacity(0.5))

                            // Restore Purchase
                            Button {
                                Task {
                                    do {
                                        // StoreKitManager mirrors the entitlement into AppState itself.
                                        if try await storeKit.restorePurchases() {
                                            restoreMessage = .localized(MeHomeCopy.restoreSuccessString)
                                        } else {
                                            restoreMessage = .localized(MeHomeCopy.restoreNotFoundString)
                                        }
                                    } catch {
                                        restoreMessage = .raw(error.localizedDescription)
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundStyle(Color.dashYellow)
                                    Text(storeKit.isRestoring ? MeHomeCopy.restoringPurchasesKey : MeHomeCopy.restorePurchasesKey)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.dashTextPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.dashTextMuted)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.dashSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.dashBorder, lineWidth: 1))

                        legalSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
            }
            .navigationTitle(MeHomeCopy.menuSettingsKey)
            .navigationBarTitleDisplayMode(.inline)
            .alert(MeHomeCopy.restorePurchasesKey, isPresented: Binding(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )) {
                Button(MeHomeCopy.okButtonKey, role: .cancel) {}
            } message: {
                switch restoreMessage {
                case .localized(let key):
                    Text(LocalizedStringKey(key))
                case .raw(let text):
                    Text(verbatim: text)
                case nil:
                    Text(verbatim: "")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(MeHomeCopy.doneButtonKey) { showingSettings = false }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }

    // MARK: - About Sheet (Matching About Screen.jpeg)

    private var aboutSheet: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    // App Icon Artwork
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(hex: "#0A0D0F"))
                            .frame(width: 90, height: 90)
                            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.dashGreen.opacity(0.5), lineWidth: 1))
                            .shadow(color: Color.dashGreen.opacity(0.4), radius: 14, y: 6)

                        Image(systemName: "play.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.dashGreen)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 4) {
                        Text(MeHomeCopy.navigationTitleKey)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)
                        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dashTextSecondary)
                    }

                    // Links Card
                    VStack(spacing: 1) {
                        aboutLinkRow(icon: "lock.shield.fill", title: MeHomeCopy.privacyPolicyKey, url: LegalLinks.privacyPolicy)
                        Divider().background(Color.dashBorder.opacity(0.5))
                        aboutLinkRow(icon: "doc.text.fill", title: MeHomeCopy.termsOfUseKey, url: LegalLinks.termsOfUse)
                        Divider().background(Color.dashBorder.opacity(0.5))
                        aboutLinkRow(icon: "questionmark.circle.fill", title: MeHomeCopy.supportKey, url: LegalLinks.support)
                    }
                    .background(Color.dashSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.dashBorder, lineWidth: 1))
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationTitle(MeHomeCopy.menuAboutKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(MeHomeCopy.doneButtonKey) { showingAbout = false }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }

    private func aboutLinkRow(icon: String, title: LocalizedStringKey, url: URL) -> some View {
        Link(destination: url) {
            aboutLinkLabel(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Legal & Safety (Settings)

    private var legalSection: some View {
        VStack(spacing: 1) {
            aboutLinkRow(icon: "lock.shield.fill", title: MeHomeCopy.privacyPolicyKey, url: LegalLinks.privacyPolicy)
            Divider().background(Color.dashBorder.opacity(0.5))
            aboutLinkRow(icon: "doc.text.fill", title: MeHomeCopy.termsOfUseKey, url: LegalLinks.termsOfUse)
            Divider().background(Color.dashBorder.opacity(0.5))
            aboutLinkRow(icon: "questionmark.circle.fill", title: MeHomeCopy.supportKey, url: LegalLinks.support)
            Divider().background(Color.dashBorder.opacity(0.5))
            Button {
                showingSettings = false
                passengerNoticeAccepted = false
            } label: {
                aboutLinkLabel(icon: "car.side.and.exclamationmark", title: MeHomeCopy.passengerSafetyNoticeKey)
            }
            .buttonStyle(.plain)
        }
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.dashBorder, lineWidth: 1))
    }

    private func aboutLinkLabel(icon: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.dashYellow)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.dashTextPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.dashTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
