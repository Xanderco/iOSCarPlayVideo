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
                Color.dcBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header summary
                        VStack(spacing: 6) {
                            Text("Driver Analytics & Usage")
                                .font(DSTypography.title2)
                                .foregroundStyle(Color.dcTextPrimary)

                            Text("100% Private · Stored locally on this device")
                                .font(DSTypography.footnote)
                                .foregroundStyle(Color.dcSuccess)
                        }
                        .padding(.top, 10)

                        // Big Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            let distanceStr = appState.useMilesPerHour
                                ? String(format: "%.1f mi", metrics.totalDistanceMiles)
                                : String(format: "%.1f km", metrics.totalDistanceKm)

                            metricCard(title: "TOTAL DISTANCE", value: distanceStr, icon: "road.lanes", color: .dcAccent)
                            metricCard(title: "TOTAL TRIPS", value: "\(metrics.totalTripsRecorded)", icon: "car.side.fill", color: .dcAccent)
                            metricCard(title: "AVG SAFETY SCORE", value: String(format: "%.0f / 100", metrics.averageDrivingScore), icon: "shield.checkered", color: .dcSuccess)
                            metricCard(title: "VIDEOS WATCHED", value: "\(metrics.totalVideosWatched)", icon: "play.tv.fill", color: .dcPro)
                            metricCard(title: "SOUNDS PLAYED", value: "\(metrics.totalSoundsPlayed)", icon: "speaker.wave.3.fill", color: .dcWarning)
                        }
                        .padding(.horizontal)

                        // Drive Hours Breakdown
                        AutomotiveCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DRIVE TIME TRACKED")
                                    .font(DSTypography.caption)
                                    .foregroundStyle(Color.dcTextTertiary)
                                    .tracking(1.0)

                                HStack {
                                    let hours = Int(metrics.totalDurationSeconds) / 3600
                                    let mins = (Int(metrics.totalDurationSeconds) % 3600) / 60
                                    Text("\(hours)h \(mins)m")
                                        .font(DSTypography.title.monospacedDigit())
                                        .foregroundStyle(Color.dcTextPrimary)

                                    Spacer()

                                    Text("First active: \(metrics.firstLaunchDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.dcTextTertiary)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Privacy Guarantee Card
                        AutomotiveCard(cornerRadius: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.dcSuccess)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("On-Device Privacy Guarantee")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("DashCast never sells, uploads, or tracks your location or driving telemetry to external servers.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.dcTextSecondary)
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
                    .foregroundStyle(Color.dcAccent)
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
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dcTextTertiary)
                Text(value)
                    .font(DSTypography.title3.monospacedDigit())
                    .foregroundStyle(Color.dcTextPrimary)
            }
        }
    }
}
