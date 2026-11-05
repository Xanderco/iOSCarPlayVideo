import SwiftUI
import StoreKit

public struct MeHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var metricsManager = UsageMetricsManager.shared
    @StateObject private var storeKit = StoreKitManager.shared
    @Environment(\.requestReview) private var requestReview
    @AppStorage(PassengerSafetyNotice.acceptedKey) private var passengerNoticeAccepted = false

    @State private var showingSettings: Bool = false
    @State private var showingAbout: Bool = false
    @State private var showingFeedback: Bool = false
    @State private var restoreMessage: String?
    @State private var showingDriveDetails: Bool = false
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
                        // Top Profile & Selected Vehicle Card (Exact 1:1 match)
                        topVehicleProfileCard

                        // PRO Upgrade Banner (Exact 1:1 match)
                        proUpgradeBanner

                        // Navigation Menu Rows (Exact 1:1 match)
                        navigationMenuSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 110) // clearance for LiquidCapsuleTabBar
                }
            }
            .navigationTitle("DashCast")
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
        }
    }

    // MARK: - Top Profile & Vehicle Card

    private var topVehicleProfileCard: some View {
        let metrics = metricsManager.metrics
        let distanceStr = appState.useMilesPerHour
            ? String(format: "%.1f mi", metrics.totalDistanceMiles)
            : String(format: "%.1f km", metrics.totalDistanceKm)
        let tripsCount = metrics.totalTripsRecorded

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
                        Text(appState.isProLifetimeUnlocked ? "PRO · LIFETIME" : "FREE")
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
                statColumn(value: distanceStr, label: "driven")
                Divider().frame(height: 28).background(Color.dashBorder)
                statColumn(value: "\(tripsCount)", label: "drives")
                Divider().frame(height: 28).background(Color.dashBorder)
                statColumn(value: tripsCount > 0 ? String(format: "%.0f", metrics.averageDrivingScore) : "–", label: "avg score")
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

    private func statColumn(value: String, label: String) -> some View {
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
                Text(appState.isProLifetimeUnlocked ? "DashCast PRO Active" : "DashCast PRO")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color.black)

                Text(appState.isProLifetimeUnlocked ? "All features unlocked forever" : "Unlock everything on your car screen")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.85))

                Spacer()

                Button {
                    appState.showPaywall = true
                } label: {
                    Text(appState.isProLifetimeUnlocked ? "Manage Pass" : "Upgrade Now")
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
            menuItemRow(icon: "car.fill", title: "Drive") {
                showingDriveDetails = true
            }

            Divider().background(Color.dashBorder.opacity(0.5))

            menuItemRow(icon: "gearshape.fill", title: "Settings") {
                showingSettings = true
            }

            Divider().background(Color.dashBorder.opacity(0.5))

            menuItemRow(icon: "info.circle.fill", title: "About") {
                showingAbout = true
            }

            Divider().background(Color.dashBorder.opacity(0.5))

            menuItemRow(icon: "bubble.left.and.bubble.right.fill", title: "Feedback") {
                showingFeedback = true
            }

            Divider().background(Color.dashBorder.opacity(0.5))

            menuItemRow(icon: "star.fill", title: "Rate Us") {
                requestReview()
            }

            Divider().background(Color.dashBorder.opacity(0.5))

            ShareLink(item: LegalLinks.support,
                      subject: Text("DashCast"),
                      message: Text("DashCast – play your own videos on the car display (passengers & parked only).")) {
                menuItemLabel(icon: "arrow.up.right.circle.fill", title: "Share DashCast")
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

    private func menuItemRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            menuItemLabel(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }

    private func menuItemLabel(icon: String, title: String) -> some View {
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
                            // Speed Units MPH / KMH
                            HStack {
                                HStack(spacing: 12) {
                                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                                        .foregroundStyle(Color.dashYellow)
                                    Text("Speed Units")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.dashTextPrimary)
                                }

                                Spacer()

                                Picker("Units", selection: Binding(
                                    get: { appState.useMilesPerHour },
                                    set: { appState.setSpeedUnit(milesPerHour: $0) }
                                )) {
                                    Text("KM/H").tag(false)
                                    Text("MPH").tag(true)
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
                                    await storeKit.restorePurchases()
                                    if storeKit.isPurchased {
                                        appState.unlockProLifetime()
                                        restoreMessage = "Your DashCast Pro purchase has been restored."
                                    } else {
                                        restoreMessage = storeKit.errorMessage ?? "No previous purchase was found for this Apple ID."
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundStyle(Color.dashYellow)
                                    Text(storeKit.isLoading ? "Restoring…" : "Restore Purchases")
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Restore Purchases", isPresented: Binding(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { showingSettings = false }
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
                        Text("DashCast")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)
                        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dashTextSecondary)
                    }

                    // Links Card
                    VStack(spacing: 1) {
                        aboutLinkRow(icon: "lock.shield.fill", title: "Privacy Policy", url: LegalLinks.privacyPolicy)
                        Divider().background(Color.dashBorder.opacity(0.5))
                        aboutLinkRow(icon: "doc.text.fill", title: "Terms of Use (EULA)", url: LegalLinks.termsOfUse)
                        Divider().background(Color.dashBorder.opacity(0.5))
                        aboutLinkRow(icon: "questionmark.circle.fill", title: "Support", url: LegalLinks.support)
                    }
                    .background(Color.dashSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.dashBorder, lineWidth: 1))
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { showingAbout = false }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }

    private func aboutLinkRow(icon: String, title: String, url: URL) -> some View {
        Link(destination: url) {
            aboutLinkLabel(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Legal & Safety (Settings)

    private var legalSection: some View {
        VStack(spacing: 1) {
            aboutLinkRow(icon: "lock.shield.fill", title: "Privacy Policy", url: LegalLinks.privacyPolicy)
            Divider().background(Color.dashBorder.opacity(0.5))
            aboutLinkRow(icon: "doc.text.fill", title: "Terms of Use (EULA)", url: LegalLinks.termsOfUse)
            Divider().background(Color.dashBorder.opacity(0.5))
            aboutLinkRow(icon: "questionmark.circle.fill", title: "Support", url: LegalLinks.support)
            Divider().background(Color.dashBorder.opacity(0.5))
            Button {
                showingSettings = false
                passengerNoticeAccepted = false
            } label: {
                aboutLinkLabel(icon: "car.side.and.exclamationmark", title: "Passenger Safety Notice")
            }
            .buttonStyle(.plain)
        }
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.dashBorder, lineWidth: 1))
    }

    private func aboutLinkLabel(icon: String, title: String) -> some View {
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
