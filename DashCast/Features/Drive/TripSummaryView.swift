import SwiftUI

public struct TripSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    public let trip: TripModel

    @State private var showShareModal: Bool = false

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
                            statCard(title: "DISTANCE", value: String(format: "%.2f km", trip.distanceKilometers), icon: "road.lanes")
                            statCard(title: "DURATION", value: formatDuration(trip.durationSeconds), icon: "clock.fill")
                            statCard(title: "AVG SPEED", value: String(format: "%.0f km/h", trip.averageSpeedKmh), icon: "gauge.medium")
                            statCard(title: "TOP SPEED", value: String(format: "%.0f km/h", trip.maxSpeedKmh), icon: "bolt.fill")
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

                        // Social Story Share Card CTA
                        Button(action: { showShareModal = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Share Story Card (1080x1920)")
                                    .font(ThemeFonts.hudStat(size: 16))
                            }
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(
                                    colors: [Color.dashYellow, Color.dashGold],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.dashYellow.opacity(0.35), radius: 6, y: 2)
                        }
                        .padding(.horizontal)

                        GlowButton(title: "Done", iconName: "checkmark") {
                            dismiss()
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Trip Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showShareModal = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.dashYellow)
                    }
                }
            }
            .sheet(isPresented: $showShareModal) {
                DriveStoryShareModalView(trip: trip)
            }
        }
    }

    private var scoreColor: Color {
        if trip.drivingScore >= 85 { return .dashGreen }
        if trip.drivingScore >= 70 { return .dashOrange }
        return .dashRed
    }

    private var scoreMessage: String {
        if trip.drivingScore >= 90 { return "Flawless Driving!" }
        if trip.drivingScore >= 80 { return "Smooth & Safe Drive" }
        if trip.drivingScore >= 70 { return "Moderate Ride" }
        return "Aggressive Driving Detected"
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
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

    private func telemetryPill(label: String, count: Int, color: Color) -> some View {
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
