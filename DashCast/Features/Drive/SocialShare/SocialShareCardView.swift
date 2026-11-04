import SwiftUI

public struct SocialShareCardView: View {
    public let data: SocialShareCardData

    public init(data: SocialShareCardData) {
        self.data = data
    }

    public var body: some View {
        ZStack {
            // Background Canvas (OLED True Deep Black with Template Gradient)
            backgroundLayer

            VStack(spacing: 16) {
                // 1. Top Header: Branding & Lifetime Pass Badge
                topHeaderSection

                // 2. Driver Grade Crest & Smoothness Score
                driverGradeSection

                // 3. Peak G-Force Telemetry Meter
                gForceTelemetrySection

                // 4. Vehicle Artwork & Stamped License Plate
                vehicleSection

                // 5. Trip Performance Grid & Route
                tripPerformanceSection

                Spacer(minLength: 4)

                // 6. Bottom Footer & Verification Watermark
                bottomFooterSection
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [data.template.accentColor.opacity(0.8), data.template.secondaryColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: data.template.accentColor.opacity(0.25), radius: 20, x: 0, y: 10)
    }

    // MARK: - Background Layer
    private var backgroundLayer: some View {
        ZStack {
            data.template.surfaceBackground.ignoresSafeArea()

            // Subtle carbon fiber HUD grid pattern
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 28
                    for x in stride(from: 0, to: geo.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for y in stride(from: 0, to: geo.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.025), lineWidth: 0.5)
            }

            // Radial neon accent glow behind grade
            RadialGradient(
                colors: [data.template.accentColor.opacity(0.18), Color.clear],
                center: .top,
                startRadius: 40,
                endRadius: 360
            )

            // Bottom subtle glow
            RadialGradient(
                colors: [data.template.secondaryColor.opacity(0.12), Color.clear],
                center: .bottom,
                startRadius: 60,
                endRadius: 400
            )
        }
    }

    // MARK: - 1. Top Header Section
    private var topHeaderSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                // DashCast Logo & Icon
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(data.template.accentColor)
                            .frame(width: 28, height: 28)
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.dashBackground)
                    }

                    Text("DASHCAST")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                        .tracking(1.5)
                }

                Spacer()

                // $19.99 Lifetime PRO Badge
                HStack(spacing: 5) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.black)
                    Text("LIFETIME PRO")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.black)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FFE600"), Color(hex: "#FFB800")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#FFE600").opacity(0.4), radius: 6, x: 0, y: 2)
            }

            // Date & Timestamp Subtitle
            HStack {
                Text(formattedDate(data.trip.startTime))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.dashTextMuted)
                Spacer()
                Text("APPLE CARPLAY TELEMETRY")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(data.template.accentColor.opacity(0.8))
                    .tracking(1)
            }
        }
    }

    // MARK: - 2. Driver Grade Crest & Score
    private var driverGradeSection: some View {
        let gradeInfo = data.driverGrade

        return HStack(spacing: 16) {
            // Embossed Grade Badge Hexagon / Circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#222530"), Color(hex: "#12141A")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [gradeInfo.color, gradeInfo.color.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: gradeInfo.glowColor, radius: 10, x: 0, y: 0)

                Text(gradeInfo.grade)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [gradeInfo.color, Color.white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            // Grade Title & Smoothness Score
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(gradeInfo.title)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(gradeInfo.color)
                        .tracking(1)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(gradeInfo.color)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(data.trip.drivingScore)")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white)
                    Text("/ 100")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.dashTextMuted)

                    Spacer()

                    Text("\(data.smoothnessPercentage)% Smoothness")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(data.template.accentColor)
                }

                // Mini Liquid Progress Line
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.dashSurfaceHighlight)
                            .frame(height: 5)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [data.template.accentColor, data.template.secondaryColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(data.trip.drivingScore) / 100.0, height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(14)
        .background(Color.dashSurface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    // MARK: - 3. Peak G-Force Telemetry Meter
    private var gForceTelemetrySection: some View {
        HStack(spacing: 12) {
            // Friction Circle Mini Display
            ZStack {
                Circle()
                    .stroke(Color.dashBorder, lineWidth: 1.5)
                    .frame(width: 58, height: 58)

                Circle()
                    .stroke(Color.dashBorder.opacity(0.5), lineWidth: 1)
                    .frame(width: 34, height: 34)

                // Crosshairs
                Rectangle()
                    .fill(Color.dashBorder.opacity(0.4))
                    .frame(width: 58, height: 1)
                Rectangle()
                    .fill(Color.dashBorder.opacity(0.4))
                    .frame(width: 1, height: 58)

                // Peak G dot indicator
                Circle()
                    .fill(data.template.accentColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: data.template.accentColor, radius: 4)
                    .offset(x: 14, y: -10)
            }
            .frame(width: 60, height: 60)

            // G-Force Reading
            VStack(alignment: .leading, spacing: 2) {
                Text("PEAK LATERAL G-FORCE")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color.dashTextMuted)
                    .tracking(1)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.2f", data.peakGForce))
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(data.template.accentColor)
                    Text("G")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(data.template.secondaryColor)
                }

                Text("Cornering Threshold Controlled")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.dashTextSecondary)
            }

            Spacer()

            // Event Mini Badges
            VStack(alignment: .trailing, spacing: 4) {
                eventBadge(label: "BRAKES", count: data.trip.harshBrakingCount, isZeroGood: true)
                eventBadge(label: "ACCEL", count: data.trip.harshAccelerationCount, isZeroGood: true)
                eventBadge(label: "TURNS", count: data.trip.harshCorneringCount, isZeroGood: true)
            }
        }
        .padding(14)
        .background(Color.dashSurface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    private func eventBadge(label: String, count: Int, isZeroGood: Bool) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.dashTextMuted)
            Text("\(count)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(count == 0 ? Color.dashGreen : Color.dashOrange)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.dashSurfaceHighlight)
        .clipShape(Capsule())
    }

    // MARK: - 4. Vehicle Artwork & License Plate
    private var vehicleSection: some View {
        VStack(spacing: 6) {
            // Vehicle Transparent Artwork
            ZStack {
                // Ground shadow reflection
                Ellipse()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 220, height: 26)
                    .offset(y: 38)
                    .blur(radius: 6)

                Image(data.vehicleImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 105)
                    .shadow(color: data.template.accentColor.opacity(0.25), radius: 12, x: 0, y: 4)
            }
            .frame(height: 110)

            // Vehicle Name & Stamped Metal Plate
            HStack(spacing: 8) {
                Text(data.vehicleName.uppercased())
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .tracking(1.2)

                // Stamped Metal License Plate
                Text(data.licensePlate)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#FFE600"))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color(hex: "#FFB800"), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - 5. Trip Performance Grid
    private var tripPerformanceSection: some View {
        HStack(spacing: 8) {
            metricCard(title: "DISTANCE", value: String(format: "%.1f km", data.trip.distanceKilometers), icon: "road.lanes")
            metricCard(title: "TIME", value: formatDuration(data.trip.durationSeconds), icon: "clock.fill")
            metricCard(title: "TOP SPEED", value: String(format: "%.0f km/h", data.trip.maxSpeedKmh), icon: "bolt.fill")
            metricCard(title: "AVG SPEED", value: String(format: "%.0f km/h", data.trip.averageSpeedKmh), icon: "gauge.medium")
        }
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(data.template.accentColor)

            Text(title)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Color.dashTextMuted)

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Color.dashSurface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    // MARK: - 6. Bottom Footer
    private var bottomFooterSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("GET DASHCAST")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(data.template.accentColor)

                Text("•")
                    .foregroundStyle(Color.dashTextMuted)

                Text("ZERO SUBSCRIPTIONS")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color.white)
            }

            Text("carplay.dashcast.app • In-Dash Video & Telemetry")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.dashTextMuted)
        }
        .padding(.top, 4)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy • h:mm a"
        return formatter.string(from: date).uppercased()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m \(secs)s"
        }
    }
}
