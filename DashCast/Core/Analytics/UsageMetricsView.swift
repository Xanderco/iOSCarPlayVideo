import SwiftUI

public struct UsageMetricsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var metricsManager = UsageMetricsManager.shared

    public init() {}

    private var metrics: LocalUsageMetrics {
        metricsManager.metrics
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header summary
                        VStack(spacing: 6) {
                            Text("Driver Analytics & Usage")
                                .font(ThemeFonts.hudTitle(size: 22))
                                .foregroundStyle(Color.dashTextPrimary)

                            Text("100% Private · Stored locally on this device")
                                .font(ThemeFonts.hudCaption(size: 13))
                                .foregroundStyle(Color.dashGreen)
                        }
                        .padding(.top, 10)

                        // Big Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            let distanceStr = appState.useMilesPerHour
                                ? String(format: "%.1f mi", metrics.totalDistanceMiles)
                                : String(format: "%.1f km", metrics.totalDistanceKm)

                            metricCard(title: "TOTAL DISTANCE", value: distanceStr, icon: "road.lanes", color: .dashCyan)
                            metricCard(title: "TOTAL TRIPS", value: "\(metrics.totalTripsRecorded)", icon: "car.side.fill", color: .dashBlue)
                            metricCard(title: "AVG SAFETY SCORE", value: String(format: "%.0f / 100", metrics.averageDrivingScore), icon: "shield.checkered", color: .dashGreen)
                            metricCard(title: "VIDEOS WATCHED", value: "\(metrics.totalVideosWatched)", icon: "play.tv.fill", color: .dashGold)
                            metricCard(title: "SOUNDS PLAYED", value: "\(metrics.totalSoundsPlayed)", icon: "speaker.wave.3.fill", color: .dashOrange)
                        }
                        .padding(.horizontal)

                        // Drive Hours Breakdown
                        AutomotiveCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DRIVE TIME TRACKED")
                                    .font(ThemeFonts.hudCaption(size: 11))
                                    .foregroundStyle(Color.dashTextMuted)
                                    .tracking(1.0)

                                HStack {
                                    let hours = Int(metrics.totalDurationSeconds) / 3600
                                    let mins = (Int(metrics.totalDurationSeconds) % 3600) / 60
                                    Text("\(hours)h \(mins)m")
                                        .font(ThemeFonts.speedDisplay(size: 28))
                                        .foregroundStyle(Color.dashTextPrimary)

                                    Spacer()

                                    Text("First active: \(metrics.firstLaunchDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.dashTextMuted)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Privacy Guarantee Card
                        AutomotiveCard(cornerRadius: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.dashGreen)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("On-Device Privacy Guarantee")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("DashCast never sells, uploads, or tracks your location or driving telemetry to external servers.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.dashTextSecondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Usage Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.dashCyan)
                }
            }
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        AutomotiveCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Spacer()
                }
                Text(title)
                    .font(ThemeFonts.hudCaption(size: 10))
                    .foregroundStyle(Color.dashTextMuted)
                Text(value)
                    .font(ThemeFonts.hudStat(size: 20))
                    .foregroundStyle(Color.dashTextPrimary)
            }
        }
    }
}
