import SwiftUI

/// Pure formatting and clamping helpers for `UsageMetricsView`.
public enum UsageMetricsFormatter {
    nonisolated public static func distanceString(
        distanceKm: Double,
        distanceMiles: Double,
        useMilesPerHour: Bool
    ) -> String {
        let raw = useMilesPerHour ? distanceMiles : distanceKm
        let safe = (raw.isFinite && raw > 0) ? raw : 0
        return useMilesPerHour
            ? String(format: "%.1f mi", safe)
            : String(format: "%.1f km", safe)
    }

    nonisolated public static func durationString(totalSeconds: Double) -> String {
        let safe = (totalSeconds.isFinite && totalSeconds > 0) ? totalSeconds : 0
        let total = Int(safe)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        return "\(hours)h \(mins)m"
    }

    nonisolated public static func safetyScoreString(score: Double) -> String {
        guard score.isFinite else { return "0 / 100" }
        let clamped = min(100, max(0, score))
        return String(format: "%.0f / 100", clamped)
    }
}

/// Localized copy keys for `UsageMetricsView`.
public enum UsageMetricsCopy {
    nonisolated public static let navigationTitleString = "Usage Metrics"
    nonisolated public static let headerTitleString = "Driver Analytics & Usage"
    nonisolated public static let headerSubtitleString = "100% Private · Stored locally on this device"
    nonisolated public static let totalDistanceString = "TOTAL DISTANCE"
    nonisolated public static let totalTripsString = "TOTAL TRIPS"
    nonisolated public static let avgSafetyScoreString = "AVG SAFETY SCORE"
    nonisolated public static let videosWatchedString = "VIDEOS WATCHED"
    nonisolated public static let soundsPlayedString = "SOUNDS PLAYED"
    nonisolated public static let driveTimeTrackedString = "DRIVE TIME TRACKED"
    nonisolated public static let firstActiveFormatString = "First active: %@"
    nonisolated public static let privacyTitleString = "On-Device Privacy Guarantee"
    nonisolated public static let privacyBodyString = "DashCast never sells, uploads, or tracks your location or driving telemetry to external servers."
    nonisolated public static let doneString = "Done"

    nonisolated public static let allLocalizationKeys: [String] = [
        navigationTitleString,
        headerTitleString,
        headerSubtitleString,
        totalDistanceString,
        totalTripsString,
        avgSafetyScoreString,
        videosWatchedString,
        soundsPlayedString,
        driveTimeTrackedString,
        firstActiveFormatString,
        privacyTitleString,
        privacyBodyString,
        doneString
    ]

    @MainActor public static var navigationTitleKey: LocalizedStringKey { LocalizedStringKey(navigationTitleString) }
    @MainActor public static var headerTitleKey: LocalizedStringKey { LocalizedStringKey(headerTitleString) }
    @MainActor public static var headerSubtitleKey: LocalizedStringKey { LocalizedStringKey(headerSubtitleString) }
    @MainActor public static var totalDistanceKey: LocalizedStringKey { LocalizedStringKey(totalDistanceString) }
    @MainActor public static var totalTripsKey: LocalizedStringKey { LocalizedStringKey(totalTripsString) }
    @MainActor public static var avgSafetyScoreKey: LocalizedStringKey { LocalizedStringKey(avgSafetyScoreString) }
    @MainActor public static var videosWatchedKey: LocalizedStringKey { LocalizedStringKey(videosWatchedString) }
    @MainActor public static var soundsPlayedKey: LocalizedStringKey { LocalizedStringKey(soundsPlayedString) }
    @MainActor public static var driveTimeTrackedKey: LocalizedStringKey { LocalizedStringKey(driveTimeTrackedString) }
    @MainActor public static var privacyTitleKey: LocalizedStringKey { LocalizedStringKey(privacyTitleString) }
    @MainActor public static var privacyBodyKey: LocalizedStringKey { LocalizedStringKey(privacyBodyString) }
    @MainActor public static var doneKey: LocalizedStringKey { LocalizedStringKey(doneString) }

    @MainActor
    public static func firstActiveKey(_ formattedDate: String) -> LocalizedStringKey {
        LocalizedStringKey("First active: \(formattedDate)")
    }
}

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
                            Text(UsageMetricsCopy.headerTitleKey)
                                .font(ThemeFonts.hudTitle(size: 22))
                                .foregroundStyle(Color.dashTextPrimary)

                            Text(UsageMetricsCopy.headerSubtitleKey)
                                .font(ThemeFonts.hudCaption(size: 13))
                                .foregroundStyle(Color.dashGreen)
                        }
                        .padding(.top, 10)

                        // Big Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            let distanceStr = UsageMetricsFormatter.distanceString(
                                distanceKm: metrics.totalDistanceKm,
                                distanceMiles: metrics.totalDistanceMiles,
                                useMilesPerHour: appState.useMilesPerHour
                            )
                            let scoreStr = UsageMetricsFormatter.safetyScoreString(score: metrics.averageDrivingScore)

                            metricCard(title: UsageMetricsCopy.totalDistanceKey, value: distanceStr, icon: "road.lanes", color: .dashCyan)
                            metricCard(title: UsageMetricsCopy.totalTripsKey, value: "\(metrics.totalTripsRecorded)", icon: "car.side.fill", color: .dashBlue)
                            metricCard(title: UsageMetricsCopy.avgSafetyScoreKey, value: scoreStr, icon: "shield.checkered", color: .dashGreen)
                            metricCard(title: UsageMetricsCopy.videosWatchedKey, value: "\(metrics.totalVideosWatched)", icon: "play.tv.fill", color: .dashGold)
                            metricCard(title: UsageMetricsCopy.soundsPlayedKey, value: "\(metrics.totalSoundsPlayed)", icon: "speaker.wave.3.fill", color: .dashOrange)
                        }
                        .padding(.horizontal)

                        // Drive Hours Breakdown
                        AutomotiveCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(UsageMetricsCopy.driveTimeTrackedKey)
                                    .font(ThemeFonts.hudCaption(size: 11))
                                    .foregroundStyle(Color.dashTextMuted)
                                    .tracking(1.0)

                                HStack {
                                    Text(UsageMetricsFormatter.durationString(totalSeconds: metrics.totalDurationSeconds))
                                        .font(ThemeFonts.speedDisplay(size: 28))
                                        .foregroundStyle(Color.dashTextPrimary)

                                    Spacer()

                                    let formattedDate = metrics.firstLaunchDate.formatted(date: .abbreviated, time: .omitted)
                                    Text(UsageMetricsCopy.firstActiveKey(formattedDate))
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
                                    Text(UsageMetricsCopy.privacyTitleKey)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text(UsageMetricsCopy.privacyBodyKey)
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
            .navigationTitle(UsageMetricsCopy.navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(UsageMetricsCopy.doneKey) {
                        dismiss()
                    }
                    .foregroundStyle(Color.dashCyan)
                }
            }
        }
    }

    private func metricCard(title: LocalizedStringKey, value: String, icon: String, color: Color) -> some View {
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
