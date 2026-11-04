import SwiftUI
import CoreLocation

/// 1080x1920 High-Resolution Instagram Story / TikTok Graphic View for Drive Telemetry.
public struct DriveSummaryStoryCardView: View {
    public let data: DriveSummaryCardData

    public init(data: DriveSummaryCardData) {
        self.data = data
    }

    public var body: some View {
        ZStack {
            // OLED True Deep Black Canvas
            Color(hex: "#0C0D10")
                .ignoresSafeArea()

            // Atmospheric Glows
            atmosphericGlows

            // Structural Hex Grid Overlay
            hexagonalGridOverlay

            // Main Content Stack
            VStack(spacing: 36) {
                // 1. Top Header Watermark
                headerSection
                    .padding(.top, 64)

                // 2. Vehicle Showcase Banner
                vehicleShowcaseSection

                // 3. Score & Badge Centerpiece
                scoreCenterpieceSection

                // 4. 2x2 Telemetry Metrics Grid
                telemetryMetricsGrid

                // 5. G-Force & Smoothness Breakdown
                gForceDynamicsSection

                // 6. Vector Route Polyline Canvas
                routeCanvasSection

                Spacer(minLength: 10)

                // 7. Footer Watermark & Branding
                footerSection
                    .padding(.bottom, 50)
            }
            .padding(.horizontal, 60)
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Atmospheric Glows

    private var atmosphericGlows: some View {
        ZStack {
            // Top ambient badge glow
            Circle()
                .fill(data.vehicleAccentColor.opacity(0.12))
                .frame(width: 700, height: 700)
                .blur(radius: 120)
                .offset(y: -400)

            // Center score glow
            Circle()
                .fill(Color(hex: data.badgeTier.accentHex).opacity(0.15))
                .frame(width: 600, height: 600)
                .blur(radius: 100)
                .offset(y: -50)

            // Bottom route glow
            Circle()
                .fill(Color.dashGold.opacity(0.08))
                .frame(width: 650, height: 650)
                .blur(radius: 110)
                .offset(y: 500)
        }
    }

    private var hexagonalGridOverlay: some View {
        Canvas { context, size in
            let step: CGFloat = 80
            var path = Path()
            for x in stride(from: 0, through: size.width, by: step) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: step) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(Color(hex: "#1F232E").opacity(0.25)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 1. Header Section

    private var headerSection: some View {
        HStack(alignment: .center) {
            // Brand Logo & In-Car Telemetry Pill
            HStack(spacing: 14) {
                Image(systemName: "car.side.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.dashYellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("DASHCAST")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                        .tracking(2.5)

                    Text("IN-CAR TELEMETRY // 9:16 STORY")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.dashYellow)
                        .tracking(1.2)
                }
            }

            Spacer()

            // Date & Verified Tag
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.dashGreen)
                        .frame(width: 10, height: 10)
                    Text("VERIFIED DRIVE")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.dashGreen)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(hex: "#171920"))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.dashGreen.opacity(0.4), lineWidth: 1))

                Text(data.formattedDate)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#8E92A0"))
            }
        }
    }

    // MARK: - 2. Vehicle Showcase Banner

    private var vehicleShowcaseSection: some View {
        HStack(spacing: 24) {
            // Vehicle Avatar / Image
            ZStack {
                Circle()
                    .fill(Color(hex: "#171920"))
                    .frame(width: 110, height: 110)
                    .overlay(Circle().stroke(data.vehicleAccentColor.opacity(0.6), lineWidth: 2))

                Image(systemName: "car.front.waves.up.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(data.vehicleAccentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(data.vehicleBrand)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.dashYellow)
                    .tracking(2.0)

                Text(data.vehicleName)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }

            Spacer()

            // CarPlay Badge
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .bold))
                Text("CarPlay")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "#222530"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(Color(hex: "#171920").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: "#2D3240"), lineWidth: 1.5))
    }

    // MARK: - 3. Score & Badge Centerpiece

    private var scoreCenterpieceSection: some View {
        VStack(spacing: 20) {
            // Circular Score Dial
            ZStack {
                // Background Track Ring
                Circle()
                    .stroke(Color(hex: "#222530"), lineWidth: 16)
                    .frame(width: 260, height: 260)

                // Colored Score Progress Arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(data.drivingScore) / 100.0)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(hex: data.badgeTier.accentHex).opacity(0.7),
                                Color(hex: data.badgeTier.accentHex)
                            ]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 260, height: 260)
                    .shadow(color: Color(hex: data.badgeTier.accentHex).opacity(0.5), radius: 16)

                // Inner Dial Display
                VStack(spacing: 4) {
                    Text("\(data.drivingScore)")
                        .font(.system(size: 92, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                        .shadow(color: Color(hex: data.badgeTier.accentHex).opacity(0.4), radius: 10)

                    Text("DRIVE SMOOTHNESS")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: data.badgeTier.accentHex))
                        .tracking(2.0)
                }
            }

            // Smoothness Badge Pill
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(hex: data.badgeTier.accentHex))

                    Text(data.badgeTier.title)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                        .tracking(1.5)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#222530"), Color(hex: "#171920")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(hex: data.badgeTier.accentHex), lineWidth: 2)
                        .shadow(color: Color(hex: data.badgeTier.accentHex).opacity(0.6), radius: 8)
                )

                Text(data.badgeTier.badgeSubtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "#A0A5B5"))
            }
        }
    }

    // MARK: - 4. 2x2 Telemetry Metrics Grid

    private var telemetryMetricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 20) {
            metricCard(
                icon: "speedometer",
                title: "TOP SPEED",
                value: data.formattedTopSpeed,
                accentColor: Color.dashYellow
            )

            metricCard(
                icon: "gauge.with.dots.needle.bottom.50percent",
                title: "AVG SPEED",
                value: data.formattedAverageSpeed,
                accentColor: Color.dashGold
            )

            metricCard(
                icon: "road.lanes",
                title: "DISTANCE",
                value: data.formattedDistance,
                accentColor: Color.dashGreen
            )

            metricCard(
                icon: "timer",
                title: "DURATION",
                value: data.formattedDuration,
                accentColor: Color(hex: "#3B82F6")
            )
        }
    }

    private func metricCard(icon: String, title: String, value: String, accentColor: Color) -> some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 58, height: 58)

                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#8E92A0"))
                    .tracking(1.2)

                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color(hex: "#171920"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#2D3240"), lineWidth: 1.5))
    }

    // MARK: - 5. G-Force Dynamics Section

    private var gForceDynamicsSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("G-FORCE DYNAMICS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.dashYellow)
                    .tracking(1.5)

                Spacer()

                HStack(spacing: 8) {
                    Text("PEAK:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#8E92A0"))
                    Text(data.formattedPeakG)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                }
            }

            HStack(spacing: 16) {
                gForcePill(label: "LATERAL G", value: data.formattedLateralG, icon: "arrow.left.and.right")
                gForcePill(label: "LONGITUDINAL G", value: data.formattedLongitudinalG, icon: "arrow.up.and.down")
                harshEventsPill(
                    braking: data.harshBrakingCount,
                    accel: data.harshAccelerationCount,
                    turn: data.harshCorneringCount
                )
            }
        }
        .padding(20)
        .background(Color(hex: "#171920").opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#2D3240"), lineWidth: 1.5))
    }

    private func gForcePill(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.dashYellow)

            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)

            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#8E92A0"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(hex: "#222530"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func harshEventsPill(braking: Int, accel: Int, turn: Int) -> some View {
        let total = braking + accel + turn
        return VStack(spacing: 4) {
            Image(systemName: total == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(total == 0 ? Color.dashGreen : Color.dashGold)

            Text("\(total)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(total == 0 ? Color.dashGreen : Color.white)

            Text("HARSH EVENTS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#8E92A0"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(hex: "#222530"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 6. Vector Route Polyline Canvas

    private var routeCanvasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.dashYellow)
                        .frame(width: 8, height: 8)
                    Text("ROUTE GRADIENT MAPPING")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .tracking(1.2)
                }

                Spacer()

                // Speed scale key
                HStack(spacing: 12) {
                    speedLegendItem(label: "SLOW", color: Color.dashGreen)
                    speedLegendItem(label: "CRUISE", color: Color.dashYellow)
                    speedLegendItem(label: "FAST", color: Color.dashRed)
                }
            }

            // Route Canvas Box
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#14161C"))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#2D3240"), lineWidth: 1.5))

                VectorRouteCanvas(coordinates: data.routeCoordinates)
                    .padding(24)
            }
            .frame(height: 220)
        }
    }

    private func speedLegendItem(label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#8E92A0"))
        }
    }

    // MARK: - 7. Footer Section

    private var footerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("#DashCastDriver")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.dashYellow)

                Spacer()

                Text("dashcast.app // $19.99 Lifetime")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#8E92A0"))
            }

            Rectangle()
                .fill(Color(hex: "#2D3240"))
                .frame(height: 1)

            HStack {
                Text("APPLE CARPLAY TELEMETRY ENGINE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#626778"))
                    .tracking(1.5)

                Spacer()

                Text("ZERO SUBSCRIPTIONS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.dashYellow.opacity(0.8))
                    .tracking(1.5)
            }
        }
    }
}

// MARK: - Vector Route Canvas Renderer

public struct VectorRouteCanvas: View {
    public let coordinates: [DriveSummaryCardData.RouteCoordinate]

    public init(coordinates: [DriveSummaryCardData.RouteCoordinate]) {
        self.coordinates = coordinates
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if coordinates.count >= 2 {
                renderNormalizedRoute(size: size)
            } else {
                renderStylizedFallbackRoute(size: size)
            }
        }
    }

    private func renderNormalizedRoute(size: CGSize) -> some View {
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return AnyView(renderStylizedFallbackRoute(size: size))
        }

        let latSpan = max(maxLat - minLat, 0.0001)
        let lonSpan = max(maxLon - minLon, 0.0001)
        let padding: CGFloat = 20
        let drawWidth = size.width - (padding * 2)
        let drawHeight = size.height - (padding * 2)

        let points: [(point: CGPoint, speed: Double)] = coordinates.map { coord in
            let normalizedX = CGFloat((coord.longitude - minLon) / lonSpan)
            let normalizedY = CGFloat(1.0 - (coord.latitude - minLat) / latSpan) // invert Y for screen coords
            let x = padding + (normalizedX * drawWidth)
            let y = padding + (normalizedY * drawHeight)
            return (CGPoint(x: x, y: y), coord.speedKmh)
        }

        return AnyView(
            ZStack {
                // Render gradient segments
                Canvas { context, _ in
                    for i in 0..<(points.count - 1) {
                        var segment = Path()
                        segment.move(to: points[i].point)
                        segment.addLine(to: points[i + 1].point)

                        let speed = points[i].speed
                        let color = colorForSpeed(speed)
                        context.stroke(segment, with: .color(color), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    }
                }

                // Start Marker
                if let start = points.first?.point {
                    Circle()
                        .fill(Color.dashGreen)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(color: Color.dashGreen, radius: 6)
                        .position(start)
                }

                // End Marker
                if let end = points.last?.point {
                    Circle()
                        .fill(Color.dashYellow)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(color: Color.dashYellow, radius: 8)
                        .position(end)
                }
            }
        )
    }

    private func renderStylizedFallbackRoute(size: CGSize) -> some View {
        // Aesthetic racetrack loop when GPS breadcrumbs are empty or simulated
        Canvas { context, canvasSize in
            var path = Path()
            let w = canvasSize.width
            let h = canvasSize.height

            path.move(to: CGPoint(x: w * 0.15, y: h * 0.5))
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.2),
                control1: CGPoint(x: w * 0.2, y: h * 0.15),
                control2: CGPoint(x: w * 0.4, y: h * 0.1)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.85, y: h * 0.5),
                control1: CGPoint(x: w * 0.65, y: h * 0.3),
                control2: CGPoint(x: w * 0.8, y: h * 0.25)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.8),
                control1: CGPoint(x: w * 0.85, y: h * 0.85),
                control2: CGPoint(x: w * 0.65, y: h * 0.85)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.15, y: h * 0.5),
                control1: CGPoint(x: w * 0.35, y: h * 0.75),
                control2: CGPoint(x: w * 0.1, y: h * 0.7)
            )

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [Color.dashGreen, Color.dashYellow, Color.dashRed, Color.dashGold]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: w, y: h)
                ),
                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func colorForSpeed(_ speedKmh: Double) -> Color {
        if speedKmh < 45 {
            return Color.dashGreen
        } else if speedKmh < 90 {
            return Color.dashYellow
        } else {
            return Color.dashRed
        }
    }
}
