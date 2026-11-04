import SwiftUI
import ActivityKit

public struct DashCastLockScreenLiveActivityView: View {
    public let state: DashCastTelemetryAttributes.ContentState
    public let attributes: DashCastTelemetryAttributes

    public init(state: DashCastTelemetryAttributes.ContentState, attributes: DashCastTelemetryAttributes) {
        self.state = state
        self.attributes = attributes
    }

    public var body: some View {
        Group {
            if state.teaserMode {
                teaserBannerView
            } else {
                telemetryCardView
            }
        }
        .padding(14)
        .background(Color.dashBackground)
    }

    // MARK: - Telemetry Card View (Live HUD)

    private var telemetryCardView: some View {
        VStack(spacing: 12) {
            // Header Row: Brand, Vehicle, Status
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(state.isPaused ? Color.dashOrange : Color.dashYellow)
                        .frame(width: 8, height: 8)

                    Text("DASHCAST")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.dashYellow)

                    Text("·")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.dashTextMuted)

                    Text(attributes.vehicleName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: state.isPaused ? "pause.fill" : "record.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(state.isPaused ? Color.dashOrange : Color.dashYellow)

                    Text(state.isPaused ? "PAUSED" : "LIVE TELEMETRY")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(state.isPaused ? Color.dashOrange : Color.dashYellow)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.dashSurface)
                .clipShape(Capsule())
            }

            // Main Telemetry Readout (Speed, G-Force, Smoothness)
            HStack(alignment: .center, spacing: 14) {
                // Speed Column
                VStack(alignment: .leading, spacing: 0) {
                    Text(state.speedFormatted)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(Color.dashYellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(attributes.speedUnit)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.dashTextMuted)
                }
                .frame(minWidth: 80, alignment: .leading)

                Divider()
                    .background(Color.dashBorder)
                    .frame(height: 38)

                // G-Force Column
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.with.needle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dashYellow)
                        Text("G-FORCE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.dashTextMuted)
                    }

                    Text(state.gForceFormatted)
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.dashTextPrimary)

                    // Visual G-Force Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.dashSurface)
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.dashYellow, Color.dashOrange, Color.dashRed],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(4, geo.size.width * CGFloat(state.gForceIntensity)), height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("Peak: \(state.peakGForceFormatted)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.dashTextMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .background(Color.dashBorder)
                    .frame(height: 38)

                // Smoothness Score Column
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(state.smoothnessScore)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(state.scoreColor)

                        Text("🏁")
                            .font(.system(size: 12))
                    }

                    Text("SCORE")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Color.dashTextMuted)

                    Text(state.scoreRatingLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(state.scoreColor)
                }
                .frame(minWidth: 70, alignment: .trailing)
            }
            .padding(.vertical, 4)

            Divider()
                .background(Color.dashBorder)

            // Bottom Metrics Bar: Distance, Duration, Top Speed
            HStack {
                bottomStat(title: "DISTANCE", value: state.distanceFormatted)
                Spacer()
                bottomStat(title: "TIME", value: state.elapsedDurationFormatted)
                Spacer()
                bottomStat(title: "TOP SPEED", value: "\(state.topSpeedFormatted) \(attributes.speedUnit)")
            }
        }
    }

    private func bottomStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.dashTextMuted)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.dashTextPrimary)
        }
    }

    // MARK: - Teaser Banner View (1:1 with "Your CarPlay Your Style" Asset)

    private var teaserBannerView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your CarPlay\nYour Style")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.white)
                    .lineSpacing(2)

                Link(destination: URL(string: "dashcast://widgets")!) {
                    Text("Add Widget")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "0072FF"), Color(hex: "00C6FF")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "0072FF").opacity(0.4), radius: 6, x: 0, y: 3)
                }
            }

            Spacer()

            // Cockpit dashboard illustration / teaser graphic
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "10141E"))
                    .frame(width: 140, height: 75)

                HStack(spacing: 8) {
                    // Mini Tachometer Widget Representation
                    ZStack {
                        Circle()
                            .stroke(Color.dashYellow.opacity(0.3), lineWidth: 3)
                            .frame(width: 38, height: 38)

                        Circle()
                            .trim(from: 0, to: 0.75)
                            .stroke(Color.dashYellow, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(135))
                            .frame(width: 38, height: 38)

                        Text("RPM")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundStyle(Color.dashYellow)
                    }

                    // Mini In-Dash Screen
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.dashSurface)
                        .frame(width: 60, height: 36)
                        .overlay(
                            VStack(spacing: 1) {
                                Image(systemName: "car.side.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: "00C6FF"))
                                Text("DashCast")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundStyle(Color.white)
                            }
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
