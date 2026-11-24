import SwiftUI
import CoreLocation

public struct OLEDNightVisionHUDView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var hudService = DriveNightHUDService.shared
    @StateObject private var locationService = DriveLocationService.shared

    @State private var showControls: Bool = true
    @State private var isPulsing: Bool = false
    @State private var showControlsHint: Bool = true

    public init() {}

    private var currentSpeed: Double {
        if appState.useMilesPerHour {
            return locationService.currentSpeedKmh * 0.621371
        } else {
            return locationService.currentSpeedKmh
        }
    }

    private var speedUnit: String {
        appState.useMilesPerHour ? "MPH" : "KM/H"
    }

    private var speedLimitDisplay: Double {
        if appState.useMilesPerHour {
            return hudService.speedLimitMph
        } else {
            return hudService.speedLimitKmh
        }
    }

    private var warningStatus: SpeedWarningStatus {
        hudService.warningStatus(currentSpeedKmh: locationService.currentSpeedKmh)
    }

    private var courseDegrees: Double {
        locationService.currentLocation?.course ?? -1.0
    }

    private var cardinalHeading: String {
        DriveNightHUDService.cardinalHeading(from: courseDegrees)
    }

    private var headingText: String {
        if courseDegrees >= 0.0 {
            return String(format: "%.0f° %@", courseDegrees, cardinalHeading)
        } else {
            return "--"
        }
    }

    public var body: some View {
        ZStack {
            // Pure OLED True Black Canvas (Zero glare)
            Color.black.ignoresSafeArea()

            // Main HUD Container (Mirrored if Windshield Mirror Mode is ON)
            VStack(spacing: 0) {
                // Top Control Bar
                if showControls {
                    topControlBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    // Minimal stealth top spacer
                    Spacer().frame(height: 24)
                }

                Spacer()

                // Centerpiece: Speedometer with Ambient Warning Aura
                centerGaugeWithAura

                Spacer()

                // Bottom Telemetry Ribbon
                bottomTelemetryRibbon

                if showControls && showControlsHint {
                    Text("Tap anywhere to toggle HUD controls for windshield projection")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .transition(.opacity)
                } else {
                    Spacer().frame(height: 16)
                }
            }
            .scaleEffect(x: hudService.isWindshieldMirrored ? -1.0 : 1.0, y: 1.0)
            .animation(.easeInOut(duration: 0.25), value: hudService.isWindshieldMirrored)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls.toggle()
            }
        }
        .onAppear {
            hudService.isHUDActive = true
            withAnimation(Animation.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            // Auto-hide controls hint after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation {
                    showControlsHint = false
                }
            }
        }
        .onDisappear {
            hudService.isHUDActive = false
        }
    }

    // MARK: - Top Control Bar

    private var topControlBar: some View {
        HStack(spacing: 12) {
            // Dismiss Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(10)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }

            Spacer()

            // Windshield Mirror Toggle Button
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                hudService.toggleWindshieldMirror()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 13, weight: .bold))
                    Text(hudService.isWindshieldMirrored ? "MIRRORED" : "WINDSHIELD")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(hudService.isWindshieldMirrored ? Color.black : hudService.selectedTheme.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(hudService.isWindshieldMirrored ? hudService.selectedTheme.accentColor : Color.white.opacity(0.12))
                .clipShape(Capsule())
            }

            // Theme Switcher Button
            Menu {
                ForEach(NightHUDTheme.allCases) { theme in
                    Button {
                        hudService.setTheme(theme)
                    } label: {
                        HStack {
                            Text(theme.displayName)
                            if hudService.selectedTheme == theme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(hudService.selectedTheme.accentColor)
                        .frame(width: 10, height: 10)
                    Text("THEME")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }

            // Speed Unit Switcher
            Button {
                appState.setSpeedUnit(milesPerHour: !appState.useMilesPerHour)
            } label: {
                Text(speedUnit)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(hudService.selectedTheme.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Center Gauge & Ambient Speed Limit Warning Aura

    private var centerGaugeWithAura: some View {
        ZStack {
            // Ambient Speed Limit Warning Glow Aura
            if hudService.isAmbientWarningAuraEnabled && warningStatus != .normal {
                // Pulsating Warning Bezel Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (warningStatus == .critical ? hudService.selectedTheme.auraCriticalColor : hudService.selectedTheme.auraCautionColor).opacity(isPulsing ? 0.45 : 0.18),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 80,
                            endRadius: 180
                        )
                    )
                    .frame(width: 360, height: 360)
                    .blur(radius: 20)

                // Warning Outer Halo Ring
                Circle()
                    .stroke(
                        (warningStatus == .critical ? hudService.selectedTheme.auraCriticalColor : hudService.selectedTheme.auraCautionColor).opacity(isPulsing ? 0.95 : 0.40),
                        lineWidth: warningStatus == .critical ? 6 : 3
                    )
                    .frame(width: 270, height: 270)
                    .shadow(
                        color: (warningStatus == .critical ? hudService.selectedTheme.auraCriticalColor : hudService.selectedTheme.auraCautionColor).opacity(0.85),
                        radius: isPulsing ? 25 : 12
                    )
            } else {
                // Minimal stealth circular bezel
                Circle()
                    .stroke(hudService.selectedTheme.accentColor.opacity(0.12), lineWidth: 2)
                    .frame(width: 260, height: 260)
            }

            // Speedometer Arc
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(
                    Color.white.opacity(0.08),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(90))

            // Active Speed Progress Arc
            Circle()
                .trim(from: 0.15, to: 0.15 + (speedProgress * 0.70))
                .stroke(
                    gaugeGradient,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(90))
                .shadow(color: hudService.selectedTheme.accentColor.opacity(0.6), radius: 8)
                .animation(.easeOut(duration: 0.2), value: currentSpeed)

            // Central Speed Readout & Limit Sign
            VStack(spacing: 4) {
                // Digital Speed
                Text(String(format: "%.0f", currentSpeed))
                    .font(.system(size: 86, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(hudService.selectedTheme.accentColor)
                    .shadow(color: hudService.selectedTheme.accentColor.opacity(0.4), radius: 10)

                // Unit Label
                Text(speedUnit)
                    .font(.system(size: 15, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .tracking(2.0)

                // Speed Limit Badge / Status
                speedLimitBadge
                    .padding(.top, 6)
            }
        }
        .frame(height: 320)
    }

    private var speedProgress: Double {
        let maxGaugeSpeed = appState.useMilesPerHour ? 140.0 : 220.0
        return min(max(currentSpeed / maxGaugeSpeed, 0.0), 1.0)
    }

    private var gaugeGradient: LinearGradient {
        if warningStatus == .critical {
            return LinearGradient(
                colors: [hudService.selectedTheme.accentColor, hudService.selectedTheme.auraCriticalColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if warningStatus == .caution {
            return LinearGradient(
                colors: [hudService.selectedTheme.accentColor, hudService.selectedTheme.auraCautionColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [hudService.selectedTheme.secondaryColor, hudService.selectedTheme.accentColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Speed Limit Sign Badge

    private var speedLimitBadge: some View {
        HStack(spacing: 8) {
            // Speed Limit decrement
            if showControls {
                Button {
                    let delta = appState.useMilesPerHour ? -5.0 * 1.60934 : -5.0
                    hudService.adjustSpeedLimit(deltaKmh: delta)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }

            // Circular Speed Limit Pill
            HStack(spacing: 4) {
                Text("LIMIT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(warningStatus != .normal ? Color.black : Color.white.opacity(0.85))

                Text(String(format: "%.0f", speedLimitDisplay))
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(warningStatus != .normal ? Color.black : hudService.selectedTheme.accentColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                warningStatus == .critical
                ? hudService.selectedTheme.auraCriticalColor
                : (warningStatus == .caution ? hudService.selectedTheme.auraCautionColor : Color.white.opacity(0.12))
            )
            .clipShape(Capsule())

            // Speed Limit increment
            if showControls {
                Button {
                    let delta = appState.useMilesPerHour ? 5.0 * 1.60934 : 5.0
                    hudService.adjustSpeedLimit(deltaKmh: delta)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }
        }
    }

    // MARK: - Bottom Telemetry Ribbon

    private var bottomTelemetryRibbon: some View {
        HStack(spacing: 20) {
            telemetryTile(
                title: "HEADING",
                value: headingText,
                icon: "location.north.circle.fill"
            )

            telemetryTile(
                title: "DISTANCE",
                value: formatDistance(locationService.distanceMeters),
                icon: "road.lanes"
            )

            telemetryTile(
                title: "TIME",
                value: formatDuration(locationService.elapsedTime),
                icon: "timer"
            )

            telemetryTile(
                title: "TOP SPEED",
                value: String(format: "%.0f %@", appState.useMilesPerHour ? locationService.topSpeedKmh * 0.621371 : locationService.topSpeedKmh, speedUnit),
                icon: "gauge.with.dots.needle.bottom.50percent"
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func telemetryTile(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(Color.white.opacity(0.45))

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Formatting Helpers

    private func formatDistance(_ meters: Double) -> String {
        if appState.useMilesPerHour {
            let miles = meters * 0.000621371
            return String(format: "%.1f mi", miles)
        } else {
            let km = meters / 1000.0
            return String(format: "%.1f km", km)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hrs > 0 {
            return String(format: "%02d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}
