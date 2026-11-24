import SwiftUI
import AVKit

public struct CarPlayExternalDisplayView: View {
    @ObservedObject var playerService = VideoPlayerService.shared
    @ObservedObject var locationService = DriveLocationService.shared
    @ObservedObject var appState = AppState.shared
    @ObservedObject var splitManager = PassengerSplitScreenManager.shared

    @State private var showingControls: Bool = true
    @State private var controlsTimer: Timer?

    public init() {}

    private var activeWidget: WidgetConfigModel {
        PersistenceController.shared.loadWidgets().first ?? WidgetConfigModel(
            carBrand: "Porsche",
            carModelName: "911 GT3 RS",
            carImageName: "car_porsche_911",
            driverGreeting: "Welcome, Driver"
        )
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if playerService.currentChannel != nil {
                // Video is active: Render Passenger Video (Split or Full)
                passengerVideoLayout
            } else if locationService.isTracking {
                // Driving: Render Speedometer and GPS Map
                drivingTelemetryLayout
            } else {
                // Parked Idle: Render CarWidget Dashboard with real vehicle
                parkedDashboardLayout
            }

            // Top Status Bar Overlay (Clock, Gear, Status, Connectivity)
            headUnitStatusBarOverlay
        }
        .onTapGesture {
            handleDisplayTouch()
        }
    }

    // MARK: - Passenger Video Layout

    private var passengerVideoLayout: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Video Player Area
                ZStack(alignment: .bottom) {
                    CustomVideoPlayerRepresentable(player: playerService.isVideoLayerAttached ? playerService.player : nil)
                        .ignoresSafeArea()

                    // Tap/Touch Overlay for Head-Unit Controls
                    if showingControls {
                        VStack {
                            // Top Passenger Safety Notice Banner
                            if !splitManager.isSafetyBannerDismissed {
                                passengerSafetyNoticeBanner
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            Spacer()

                            // Bottom Mini-Controls HUD (Pause/Play, Mode Cycle, Channel Info)
                            passengerBottomHUD
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 44) // clearance below status bar
                        .padding(.bottom, 12)
                    }
                }
                .frame(maxWidth: splitManager.currentMode == .splitSidebar ? geometry.size.width * 0.68 : (splitManager.currentMode == .fullVideo ? geometry.size.width : 0))
                .clipped()

                // Telemetry Sidebar (Split Screen)
                if splitManager.currentMode == .splitSidebar || splitManager.currentMode == .fullTelemetry {
                    telemetrySidebar
                        .frame(width: splitManager.currentMode == .fullTelemetry ? geometry.size.width : geometry.size.width * 0.32)
                        .background(Color(red: 0.06, green: 0.07, blue: 0.09))
                        .transition(.move(edge: .trailing))
                }
            }
        }
    }

    // MARK: - Telemetry Sidebar (Passenger Split Screen)

    private var telemetrySidebar: some View {
        VStack(spacing: 12) {
            // Speedometer Gauge
            NeonGaugeView(
                value: appState.useMilesPerHour ? locationService.currentSpeedKmh * 0.621371 : locationService.currentSpeedKmh,
                maxValue: appState.useMilesPerHour ? 140 : 220,
                title: "SPEED",
                unit: appState.useMilesPerHour ? "MPH" : "KM/H",
                accentColor: .dashYellow
            )
            .scaleEffect(0.85)
            .frame(height: 145)

            // Mini Route Polyline Map
            SpeedGradientRouteView(points: locationService.tripPoints)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dashBorder, lineWidth: 1)
                )
                .frame(maxHeight: .infinity)

            // Split Mode Quick-Toggle Button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    splitManager.cycleMode()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: splitManager.currentMode.icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(splitManager.currentMode == .splitSidebar ? "EXPAND VIDEO" : "SIDEBAR")
                        .font(.system(size: 10, weight: .heavy))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.dashYellow)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 10)
        .padding(.top, 44) // status bar clearance
        .padding(.bottom, 8)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.dashBorder.opacity(0.8)),
            alignment: .leading
        )
    }

    // MARK: - Passenger Safety Notice Banner

    private var passengerSafetyNoticeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.dashYellow)

            Text("PASSENGER VIEW ONLY Â· Do not distract the driver while moving.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    splitManager.dismissSafetyBanner()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.85))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.dashYellow.opacity(0.4), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.5), radius: 6, y: 2)
    }

    // MARK: - Bottom HUD Overlay

    private var passengerBottomHUD: some View {
        HStack(spacing: 12) {
            // Play / Pause Button
            Button {
                playerService.togglePlayPause()
                rescheduleControlsTimer()
            } label: {
                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(width: 32, height: 32)
                    .background(Color.dashYellow)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Channel Title & Parked/Passenger Status
            VStack(alignment: .leading, spacing: 2) {
                Text(playerService.currentChannel?.name ?? "Passenger Stream")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                Text(CarCastShared.isVehicleMoving() ? "Moving Â· Passenger Mode" : "Parked Â· CarPlay Stream")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.dashYellow)
            }

            Spacer()

            // Mode Cycle Button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    splitManager.cycleMode()
                }
                rescheduleControlsTimer()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: splitManager.currentMode.icon)
                        .font(.system(size: 12))
                    Text(splitManager.currentMode.rawValue)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Head-Unit Status Bar Overlay

    private var headUnitStatusBarOverlay: some View {
        VStack {
            HStack(spacing: 14) {
                // Live Clock
                TimelineView(.everyMinute) { context in
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.dashYellow)
                        Text(context.date, style: .time)
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }

                // Gear / Transmission indicator
                Text(CarCastShared.isVehicleMoving() ? "D" : "P")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(CarCastShared.isVehicleMoving() ? Color.dashGreen : Color.dashYellow)
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())

                Spacer()

                // DashCast Logo & CarPlay Status Indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(playerService.isPlaying ? Color.dashGreen : Color.dashYellow)
                        .frame(width: 7, height: 7)
                    Text("DashCast CarPlay")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.9))
                }

                Spacer()

                // Connectivity Indicators
                HStack(spacing: 8) {
                    Image(systemName: "cellularbars")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Image(systemName: "wifi")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Image(systemName: "battery.100")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dashGreen)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.85), Color.black.opacity(0.4), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Spacer()
        }
        .allowsHitTesting(false) // Let touches pass through to video controls
    }

    // MARK: - Driving Layout

    private var drivingTelemetryLayout: some View {
        HStack(spacing: 20) {
            NeonGaugeView(
                value: appState.useMilesPerHour ? locationService.currentSpeedKmh * 0.621371 : locationService.currentSpeedKmh,
                maxValue: appState.useMilesPerHour ? 140 : 220,
                title: "SPEED",
                unit: appState.useMilesPerHour ? "MPH" : "KM/H",
                accentColor: .dashCyan
            )
            .frame(width: 180)

            SpeedGradientRouteView(points: locationService.tripPoints)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.top, 36)
        .padding()
    }

    // MARK: - Parked Idle Layout

    private var parkedDashboardLayout: some View {
        HStack(spacing: 16) {
            // Left Widget: Real Vehicle & Driver Greeting
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [Color.dashSurfaceHighlight, Color.dashSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 8) {
                    HStack {
                        Text(activeWidget.carBrand.uppercased())
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.dashTextMuted)
                            .tracking(2)

                        Spacer()

                        TimelineView(.everyMinute) { context in
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(Color.dashGold)
                                Text(context.date, style: .time)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    realCarImageView(name: activeWidget.carImageName)
                        .frame(height: 100)

                    Spacer()

                    HStack {
                        Text(activeWidget.driverGreeting)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(activeWidget.carModelName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dashYellow)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }

            // Right Widget: Ready Status
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient.dashAccentGradient)

                VStack(spacing: 8) {
                    Text("DashCast")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.9))
                        .tracking(1)

                    Text("READY")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Select video on iPhone to cast")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(width: 240)
        }
        .padding(.top, 36)
        .padding()
    }

    // MARK: - Touch Interaction Handling

    private func handleDisplayTouch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showingControls.toggle()
        }
        if showingControls {
            rescheduleControlsTimer()
        }
    }

    private func rescheduleControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingControls = false
                }
            }
        }
    }

    @ViewBuilder
    private func realCarImageView(name: String) -> some View {
        if let uiImage = loadCarUIImage(name: name) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .shadow(color: Color.black.opacity(0.6), radius: 8, y: 4)
        } else {
            Image(systemName: "car.side.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.dashYellow)
        }
    }

    private func loadCarUIImage(name: String) -> UIImage? {
        if let img = UIImage(named: name) { return img }
        if let path = Bundle.main.path(forResource: name, ofType: "png") {
            return UIImage(contentsOfFile: path)
        }
        return nil
    }
}
