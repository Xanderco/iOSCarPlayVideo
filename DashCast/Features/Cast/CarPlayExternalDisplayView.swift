import SwiftUI
import AVKit

public struct CarPlayExternalDisplayView: View {
    @ObservedObject var playerService = VideoPlayerService.shared
    @ObservedObject var locationService = DriveLocationService.shared
    @ObservedObject var appState = AppState.shared

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
                // Video is active: Render video full-screen on the car display
                ZStack(alignment: .bottom) {
                    CustomVideoPlayerRepresentable(player: playerService.isVideoLayerAttached ? playerService.player : nil)
                        .ignoresSafeArea()

                    // Minimal CarPlay status watermark
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(Color.dashGreen).frame(width: 8, height: 8)
                            Text("DashCast · Parked Playback")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())

                        Spacer()

                        Text(playerService.currentChannel?.name ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                    }
                    .padding()
                }
            } else if locationService.isTracking {
                // Driving: Render Speedometer and GPS Map
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
                .padding()
            } else {
                // Parked Idle: Render CarWidget Dashboard with real vehicle
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

                                // Was a hardcoded "72°F" weather badge; show the real clock instead.
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

                            // Real Transparent Car Image
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

                    // Right Widget: Countdown & Ready Status
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
                .padding()
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
