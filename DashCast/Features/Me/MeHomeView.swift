import SwiftUI

public struct MeHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var metricsManager = UsageMetricsManager.shared
    @StateObject private var territoryManager = TerritoryManager.shared

    @State private var showingShortcuts: Bool = false
    @State private var showingTerritory: Bool = false
    @State private var showingMetrics: Bool = false
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
                    VStack(spacing: 20) {
                        // Profile Banner Header
                        profileHeaderView

                        // Garage & Active Car Card
                        garageCardView

                        // Lifetime Pro Status Banner
                        proStatusCardView

                        // Driving Stats Overview
                        telemetryStatsView

                        // Territory Conquest Link Card
                        territoryConquestCardView

                        // Preferences & Settings List
                        settingsSectionView

                        // Privacy & About Footer
                        aboutFooterView
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 90) // clearance for liquid tab bar
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShortcuts) {
                ShortcutsGuideView()
            }
            .sheet(isPresented: $showingTerritory) {
                NavigationStack {
                    TerritoryHomeView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") {
                                    showingTerritory = false
                                }
                                .foregroundStyle(Color.dashYellow)
                            }
                        }
                }
            }
            .sheet(isPresented: $showingMetrics) {
                UsageMetricsView()
            }
        }
    }

    // MARK: - Subviews

    private var profileHeaderView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient.dashAccentGradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.dashYellow.opacity(0.35), radius: 10)

                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .foregroundStyle(Color.dashBackground)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Driver 01")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    if appState.isProLifetimeUnlocked {
                        HStack(spacing: 3) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                            Text("PRO")
                                .font(.system(size: 10, weight: .heavy))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(LinearGradient.dashProGoldGradient)
                        .foregroundStyle(Color.black)
                        .clipShape(Capsule())
                    }
                }

                Text("CarPlay Driver & In-Car Enthusiast")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dashTextSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    private var garageCardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("MY GARAGE", systemImage: "car.side.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.dashYellow)

                Spacer()

                Menu {
                    ForEach(Array(vehicles.enumerated()), id: \.element.id) { index, vehicle in
                        Button {
                            selectedVehicleIndex = index
                        } label: {
                            HStack {
                                Text(vehicle.name)
                                if selectedVehicleIndex == index {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Switch")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Color.dashYellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.dashYellow.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            HStack(alignment: .center, spacing: 16) {
                Image(currentVehicle.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 75)
                    .shadow(color: Color.black.opacity(0.5), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentVehicle.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    Text("\(currentVehicle.year) · \(currentVehicle.colorName)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.dashGreen)
                            .frame(width: 6, height: 6)
                        Text("Connected & Synced")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.dashGreen)
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    private var proStatusCardView: some View {
        Group {
            if appState.isProLifetimeUnlocked {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(LinearGradient.dashProGoldGradient)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lifetime Pass Active")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)
                        Text("All in-car video, telemetry, and sounds unlocked forever")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dashTextSecondary)
                    }

                    Spacer()
                }
                .padding(16)
                .background(Color.dashYellow.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.dashYellow.opacity(0.4), lineWidth: 1)
                )
            } else {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unlock DashCast PRO")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)
                        Text("Pay once. Own forever. No monthly subscriptions.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dashTextSecondary)
                    }

                    Spacer()

                    Button {
                        appState.showPaywall = true
                    } label: {
                        Text("GET PRO")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(LinearGradient.dashAccentGradient)
                            .clipShape(Capsule())
                    }
                }
                .padding(16)
                .background(Color.dashSurfaceHighlight)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.dashYellow.opacity(0.5), lineWidth: 1)
                )
            }
        }
    }

    private var telemetryStatsView: some View {
        let metrics = metricsManager.metrics
        let distanceStr = appState.useMilesPerHour
            ? String(format: "%.1f mi", metrics.totalDistanceMiles)
            : String(format: "%.1f km", metrics.totalDistanceKm)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("DRIVING TELEMETRY", systemImage: "chart.bar.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.dashYellow)

                Spacer()

                Button {
                    showingMetrics = true
                } label: {
                    Text("Details")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dashYellow)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricTile(title: "DISTANCE", value: distanceStr, icon: "road.lanes", color: .dashYellow)
                metricTile(title: "TOTAL TRIPS", value: "\(metrics.totalTripsRecorded)", icon: "car.side.fill", color: .dashGold)
                metricTile(title: "DRIVE TIME", value: formatDuration(metrics.totalDurationSeconds), icon: "clock.fill", color: .dashAmber)
                metricTile(title: "AVG SCORE", value: "\(Int(metrics.averageDrivingScore))/100", icon: "shield.checkered", color: .dashGreen)
            }
        }
        .padding(16)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    private func formatDuration(_ seconds: Double) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        if hrs > 0 {
            return "\(hrs)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 14))
                Spacer()
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.dashTextMuted)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dashTextPrimary)
        }
        .padding(12)
        .background(Color.dashSurfaceHighlight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var territoryConquestCardView: some View {
        Button {
            showingTerritory = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.dashYellow.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.dashYellow)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Territory Conquest")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    Text("\(territoryManager.totalHexesCount) hexes conquered · \(territoryManager.currentRank.rawValue)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dashTextMuted)
            }
            .padding(14)
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.dashBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var settingsSectionView: some View {
        VStack(spacing: 1) {
            // Speed Unit Setting
            HStack {
                Label("Speed Units", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.dashTextPrimary)

                Spacer()

                Picker("Speed Units", selection: Binding(
                    get: { appState.useMilesPerHour },
                    set: { appState.setSpeedUnit(milesPerHour: $0) }
                )) {
                    Text("KM/H").tag(false)
                    Text("MPH").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().background(Color.dashBorder)

            // Shortcuts Guide
            Button {
                showingShortcuts = true
            } label: {
                HStack {
                    Label("Siri Shortcuts & Automations", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .medium))
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

            Divider().background(Color.dashBorder)

            // Restore Purchases
            Button {
                appState.showPaywall = true
            } label: {
                HStack {
                    Label("Purchases & Subscriptions", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.dashTextPrimary)

                    Spacer()

                    Text(appState.isProLifetimeUnlocked ? "PRO Active" : "Restore")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dashYellow)

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
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    private var aboutFooterView: some View {
        VStack(spacing: 6) {
            Text("DashCast v1.2.0 (Build 42)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.dashTextMuted)

            HStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10))
                Text("Zero Analytics · 100% Private On-Device Storage")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(Color.dashGreen)
        }
        .padding(.vertical, 12)
    }
}
