import SwiftUI

public enum TripSummaryFormatter {
    public static let kmToMiles = 0.621371
    public static let metersToMiles = 0.000621371

    public static func formatDistance(meters: Double, useMilesPerHour: Bool) -> String {
        if useMilesPerHour {
            return String(format: "%.2f mi", meters * metersToMiles)
        } else {
            return String(format: "%.2f km", meters / 1000.0)
        }
    }

    public static func formatSpeed(kmh: Double, useMilesPerHour: Bool) -> String {
        if useMilesPerHour {
            return String(format: "%.0f mph", kmh * kmToMiles)
        } else {
            return String(format: "%.0f km/h", kmh)
        }
    }

    public static func scoreMessageKey(for score: Int) -> String {
        if score >= 90 { return "Flawless Driving!" }
        if score >= 80 { return "Smooth & Safe Drive" }
        if score >= 70 { return "Moderate Ride" }
        return "Aggressive Driving Detected"
    }
}

public struct TripSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    public let trip: TripModel

    public init(trip: TripModel) {
        self.trip = trip
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Route Map Preview
                        SpeedGradientRouteView(points: trip.points)
                            .frame(height: 220)
                            .padding(.horizontal)

                        // Driving Score Circle
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.dashSurface)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Circle()
                                            .stroke(scoreColor, lineWidth: 6)
                                    )

                                VStack(spacing: 0) {
                                    Text("\(trip.drivingScore)")
                                        .font(ThemeFonts.speedDisplay(size: 38))
                                        .foregroundStyle(Color.dashTextPrimary)
                                    Text("SCORE")
                                        .font(ThemeFonts.hudCaption(size: 10))
                                        .foregroundStyle(scoreColor)
                                        .fontWeight(.bold)
                                }
                            }

                            Text(scoreMessage)
                                .font(ThemeFonts.hudTitle(size: 16))
                                .foregroundStyle(scoreColor)
                        }

                        // Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            statCard(
                                title: "DISTANCE",
                                value: TripSummaryFormatter.formatDistance(
                                    meters: trip.distanceMeters,
                                    useMilesPerHour: appState.useMilesPerHour
                                ),
                                icon: "road.lanes"
                            )
                            statCard(title: "DURATION", value: formatDuration(trip.durationSeconds), icon: "clock.fill")
                            statCard(
                                title: "AVG SPEED",
                                value: TripSummaryFormatter.formatSpeed(
                                    kmh: trip.averageSpeedKmh,
                                    useMilesPerHour: appState.useMilesPerHour
                                ),
                                icon: "gauge.medium"
                            )
                            statCard(
                                title: "TOP SPEED",
                                value: TripSummaryFormatter.formatSpeed(
                                    kmh: trip.maxSpeedKmh,
                                    useMilesPerHour: appState.useMilesPerHour
                                ),
                                icon: "bolt.fill"
                            )
                        }
                        .padding(.horizontal)

                        // Smoothness Telemetry breakdown
                        AutomotiveCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DRIVING SMOOTHNESS")
                                    .font(ThemeFonts.hudCaption(size: 12))
                                    .foregroundStyle(Color.dashTextMuted)
                                    .tracking(1.2)

                                HStack {
                                    telemetryPill(label: "Hard Brakes", count: trip.harshBrakingCount, color: .dashOrange)
                                    Spacer()
                                    telemetryPill(label: "Rapid Accel", count: trip.harshAccelerationCount, color: .dashYellow)
                                    Spacer()
                                    telemetryPill(label: "Sharp Turns", count: trip.harshCorneringCount, color: .dashGold)
                                }
                            }
                        }
                        .padding(.horizontal)

                        GlowButton(title: "Done", iconName: "checkmark") {
                            dismiss()
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Trip Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var scoreColor: Color {
        if trip.drivingScore >= 85 { return .dashGreen }
        if trip.drivingScore >= 70 { return .dashOrange }
        return .dashRed
    }

    private var scoreMessage: LocalizedStringKey {
        LocalizedStringKey(TripSummaryFormatter.scoreMessageKey(for: trip.drivingScore))
    }

    private func statCard(title: LocalizedStringKey, value: String, icon: String) -> some View {
        AutomotiveCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(Color.dashYellow)
                    Spacer()
                }
                Text(title)
                    .font(ThemeFonts.hudCaption(size: 11))
                    .foregroundStyle(Color.dashTextMuted)
                Text(value)
                    .font(ThemeFonts.hudStat(size: 20))
                    .foregroundStyle(Color.dashTextPrimary)
            }
        }
    }

    private func telemetryPill(label: LocalizedStringKey, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(ThemeFonts.hudStat(size: 18))
                .foregroundStyle(count == 0 ? Color.dashGreen : color)
            Text(label)
                .font(ThemeFonts.hudCaption(size: 10))
                .foregroundStyle(Color.dashTextSecondary)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%dm %02ds", mins, secs)
    }
}
