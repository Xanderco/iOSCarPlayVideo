import SwiftUI
import AVKit

/// Pure speed gauge conversion and bounds helpers for `CarPlayExternalDisplayView`.
public enum CarPlayExternalDisplayFormatter {
    nonisolated public static let kmhToMphFactor: Double = 0.621371
    nonisolated public static let gaugeTitleString: String = "SPEED"

    nonisolated public static func speedValue(speedKmh: Double, useMilesPerHour: Bool) -> Double {
        guard speedKmh.isFinite, speedKmh > 0 else { return 0 }
        return useMilesPerHour ? speedKmh * kmhToMphFactor : speedKmh
    }

    nonisolated public static func maxSpeedValue(useMilesPerHour: Bool) -> Double {
        useMilesPerHour ? 140 : 220
    }

    nonisolated public static func speedUnit(useMilesPerHour: Bool) -> String {
        useMilesPerHour ? "MPH" : "KM/H"
    }
}

/// Localized copy keys for `CarPlayExternalDisplayView`.
public enum CarPlayExternalDisplayCopy {
    nonisolated public static let parkedPlaybackString = "DashCast · Parked Playback"
    nonisolated public static let speedTitleString = "SPEED"
    nonisolated public static let mphUnitString = "MPH"
    nonisolated public static let kmhUnitString = "KM/H"
    nonisolated public static let readyBadgeString = "READY"
    nonisolated public static let selectVideoPromptString = "Select video on iPhone to cast"
    nonisolated public static let defaultDriverGreetingString = "Welcome, Driver"
    nonisolated public static let brandTitleString = "DashCast"

    nonisolated public static let allLocalizationKeys: [String] = [
        parkedPlaybackString,
        speedTitleString,
        mphUnitString,
        kmhUnitString,
        readyBadgeString,
        selectVideoPromptString,
        defaultDriverGreetingString,
        brandTitleString
    ]

    @MainActor
    public static var parkedPlaybackKey: LocalizedStringKey {
        LocalizedStringKey(parkedPlaybackString)
    }

    @MainActor
    public static var readyBadgeKey: LocalizedStringKey {
        LocalizedStringKey(readyBadgeString)
    }

    @MainActor
    public static var selectVideoPromptKey: LocalizedStringKey {
        LocalizedStringKey(selectVideoPromptString)
    }

    @MainActor
    public static var defaultDriverGreetingKey: LocalizedStringKey {
        LocalizedStringKey(defaultDriverGreetingString)
    }

    @MainActor
    public static var brandTitleKey: LocalizedStringKey {
        LocalizedStringKey(brandTitleString)
    }
}

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
            driverGreeting: CarPlayExternalDisplayCopy.defaultDriverGreetingString
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
                            Text(CarPlayExternalDisplayCopy.parkedPlaybackKey)
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
                        value: CarPlayExternalDisplayFormatter.speedValue(
                            speedKmh: locationService.currentSpeedKmh,
                            useMilesPerHour: appState.useMilesPerHour
                        ),
                        maxValue: CarPlayExternalDisplayFormatter.maxSpeedValue(
                            useMilesPerHour: appState.useMilesPerHour
                        ),
                        title: CarPlayExternalDisplayFormatter.gaugeTitleString,
                        unit: CarPlayExternalDisplayFormatter.speedUnit(
                            useMilesPerHour: appState.useMilesPerHour
                        ),
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
                                if activeWidget.driverGreeting == CarPlayExternalDisplayCopy.defaultDriverGreetingString {
                                    Text(CarPlayExternalDisplayCopy.defaultDriverGreetingKey)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text(activeWidget.driverGreeting)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
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
                            Text(CarPlayExternalDisplayCopy.brandTitleKey)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.9))
                                .tracking(1)

                            Text(CarPlayExternalDisplayCopy.readyBadgeKey)
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            Text(CarPlayExternalDisplayCopy.selectVideoPromptKey)
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
