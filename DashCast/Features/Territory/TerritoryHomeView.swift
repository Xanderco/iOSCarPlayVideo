import SwiftUI
import MapKit

public struct TerritoryHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var territory = TerritoryManager.shared

    @State private var showingShareSheet = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Interactive 3D Hex Map
                TerritoryMapView(claimedHexIDs: territory.claimedHexIDs)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Top Floating Rank & Area Pill
                VStack {
                    topFloatingBadge
                    Spacer()
                }

                // Bottom Floating Territory Console
                bottomTerritoryConsole
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)
                            .padding(8)
                            .background(Color.dashSurface.opacity(0.85))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var topFloatingBadge: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "car.side.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white)

                let areaStr = appState.useMilesPerHour
                    ? String(format: "%.1f mi²", territory.totalAreaSqMi())
                    : String(format: "%.1f km²", territory.totalAreaSqKm())

                Text(areaStr)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.dashSurface.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.3), radius: 6)

            // Rank Pill
            HStack(spacing: 6) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashCyan)

                Text(territory.currentRank.rawValue.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.dashCyan)
                    .tracking(1.0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.dashCyan.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(.top, 10)
    }

    private var bottomTerritoryConsole: some View {
        AutomotiveCard(cornerRadius: 22) {
            VStack(spacing: 16) {
                // Key metrics row
                HStack {
                    metricItem(value: "\(territory.totalHexesCount)", label: "HEXES")
                    Spacer()
                    Divider().frame(height: 36).background(Color.dashBorder)
                    Spacer()
                    metricItem(value: "+\(territory.weeklyHexCount)", label: "THIS WEEK")
                    Spacer()
                    Divider().frame(height: 36).background(Color.dashBorder)
                    Spacer()
                    metricItem(value: "\(territory.totalDrivesCount)", label: "DRIVES")
                }

                // Progress to Next Rank
                VStack(spacing: 8) {
                    HStack {
                        let nextRankTitle = territory.currentRank.nextRank?.rawValue ?? "Maximum Rank"
                        Text("Next: \(nextRankTitle)")
                            .font(ThemeFonts.hudCaption(size: 13))
                            .foregroundStyle(Color.dashTextPrimary)
                            .fontWeight(.semibold)

                        Spacer()

                        if let next = territory.currentRank.nextRank {
                            Text("\(territory.totalHexesCount) / \(next.threshold)")
                                .font(ThemeFonts.monospaceDigits(size: 13))
                                .foregroundStyle(Color.dashTextMuted)
                        } else {
                            Text("Max Level")
                                .font(ThemeFonts.hudCaption(size: 12))
                                .foregroundStyle(Color.dashGold)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.dashSurfaceHighlight)
                                .frame(height: 8)

                            Capsule()
                                .fill(LinearGradient.dashAccentGradient)
                                .frame(width: geo.size.width * territory.progressToNextRank, height: 8)
                                .shadow(color: Color.dashCyan.opacity(0.6), radius: 4)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal)
        .padding(.bottom, 36)
    }

    private func metricItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(ThemeFonts.hudStat(size: 24))
                .foregroundStyle(Color.dashTextPrimary)

            Text(label)
                .font(ThemeFonts.hudCaption(size: 11))
                .foregroundStyle(Color.dashTextMuted)
                .tracking(0.8)
        }
    }
}
