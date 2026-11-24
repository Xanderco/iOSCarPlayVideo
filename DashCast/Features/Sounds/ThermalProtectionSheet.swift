import SwiftUI

/// Modal sheet providing comprehensive controls, telemetry, and educational diagnostics
/// for Cockpit Thermal Protection, Low-Power Screen Dimming, and Frame Rate Throttling.
public struct ThermalProtectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var thermalService = CockpitThermalService.shared
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header Status & Aura Card
                        headerStatusCard

                        // Low-Power OLED Screen Dimmer Action
                        screenDimmerActionCard

                        // Eco Mode & Throttling Controls
                        throttlingControlsCard

                        // Simulation / Debug Testing Card
                        simulationCard

                        // Educational Guide Card
                        educationalGuideCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Cockpit Thermals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dcAccent)
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerStatusCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DEVICE THERMAL STATUS")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(Color.dcTextTertiary)

                    HStack(spacing: 8) {
                        Text(thermalService.localizedStateTitle)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(thermalService.statusColor)

                        Circle()
                            .fill(thermalService.statusColor)
                            .frame(width: 10, height: 10)
                    }

                    Text(thermalService.localizedStatusSummary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.dcTextSecondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(thermalService.statusColor.opacity(0.14))
                        .frame(width: 56, height: 56)

                    Image(systemName: thermalService.statusIconName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(thermalService.statusColor)
                }
            }

            Divider()
                .overlay(Color.dcSeparator)

            // Telemetry Grid
            HStack(spacing: 12) {
                telemetryMetricTile(
                    title: "RENDER CAP",
                    value: "\(thermalService.targetFrameRate) FPS",
                    subtitle: thermalService.targetFrameRate < 60 ? "Throttled" : "Full Rate",
                    color: thermalService.targetFrameRate < 60 ? .dcWarning : .dcSuccess
                )

                telemetryMetricTile(
                    title: "OLED DIMMER",
                    value: thermalService.isScreenDimmed ? "ACTIVE" : "STANDBY",
                    subtitle: thermalService.autoDimOnSerious ? "Auto-Arm" : "Manual",
                    color: thermalService.isScreenDimmed ? .dcWarning : .dcTextSecondary
                )

                telemetryMetricTile(
                    title: "VIDEO CODEC",
                    value: thermalService.isPlaybackPausedByThermal ? "PAUSED" : "ACTIVE",
                    subtitle: thermalService.isPlaybackPausedByThermal ? "Thermal Gate" : "Hardware VPU",
                    color: thermalService.isPlaybackPausedByThermal ? .dcDanger : .dcSuccess
                )
            }
        }
        .padding(18)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(thermalService.isThrottlingActive ? thermalService.statusColor.opacity(0.6) : Color.dcStroke, lineWidth: 1)
        )
    }

    private func telemetryMetricTile(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.dcTextTertiary)

            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(color)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.dcTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.dcSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var screenDimmerActionCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OLED Pure Black Dimmer")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.dcTextPrimary)

                    Text("Turns phone screen pure black to stop backlight heat on hot car mounts while CarPlay feed stays alive.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextSecondary)
                }
                Spacer()
            }

            Button {
                thermalService.toggleScreenDimming()
                if thermalService.isScreenDimmed {
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: thermalService.isScreenDimmed ? "sun.max.fill" : "moon.stars.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(thermalService.isScreenDimmed ? "Restore Display Brightness" : "Activate OLED Canvas Dimmer")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(thermalService.isScreenDimmed ? Color.dcSurfaceRaised : Color.black)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.dcAccent.opacity(0.8), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.dcStroke, lineWidth: 1)
        )
    }

    private var throttlingControlsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("AUTOMATIC SAFEGUARDS")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(Color.dcTextTertiary)
                Spacer()
            }

            Toggle(isOn: $thermalService.isEcoModeEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Eco Mode (30 FPS Cap)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dcTextPrimary)
                    Text("Caps local render loops to 30 FPS. Recommended for road trips in direct sunlight.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextSecondary)
                }
            }
            .tint(Color.dcAccent)

            Divider().overlay(Color.dcSeparator)

            Toggle(isOn: $thermalService.autoDimOnSerious) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-Dim on High Heat")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dcTextPrimary)
                    Text("Engages OLED black screen when iOS reports serious thermal limits.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextSecondary)
                }
            }
            .tint(Color.dcAccent)

            Divider().overlay(Color.dcSeparator)

            Toggle(isOn: $thermalService.audioAlertOnCritical) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Critical Heat Acoustic Chime")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dcTextPrimary)
                    Text("Emits an audible cockpit alert before device reaches emergency shutdown.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextSecondary)
                }
            }
            .tint(Color.dcAccent)
        }
        .padding(16)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.dcStroke, lineWidth: 1)
        )
    }

    private var simulationCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("THERMAL SIMULATION (DEBUG / PARKED)")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(Color.dcTextTertiary)
                Spacer()

                if thermalService.simulatedThermalState != nil {
                    Button("Reset") {
                        thermalService.simulateThermalState(nil)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.dcWarning)
                }
            }

            HStack(spacing: 8) {
                simButton("Nominal", state: .nominal, color: .dcSuccess)
                simButton("Fair", state: .fair, color: .dcInfo)
                simButton("Serious", state: .serious, color: .dcWarning)
                simButton("Critical", state: .critical, color: .dcDanger)
            }
        }
        .padding(16)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.dcStroke, lineWidth: 1)
        )
    }

    private func simButton(_ title: String, state: ProcessInfo.ThermalState, color: Color) -> some View {
        let isSelected = (thermalService.simulatedThermalState == state)
        return Button {
            if isSelected {
                thermalService.simulateThermalState(nil)
            } else {
                thermalService.simulateThermalState(state)
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color.dcSurfaceRaised)
                .foregroundStyle(isSelected ? Color.black : Color.dcTextPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var educationalGuideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.trianglebadge.exclamationmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.dcWarning)

                Text("Windshield Solar Heat & Battery Health")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.dcTextPrimary)
            }

            Text("Smartphones placed in windshield phone mounts face extreme temperatures (exceeding 120°F / 49°C) under direct solar radiation. Concurrent 4K video decoding, GPS tracking, and MagSafe wireless charging compound hardware heat.")
                .font(.system(size: 12))
                .foregroundStyle(Color.dcTextSecondary)

            Text("DashCast's Cockpit Thermal Protection actively monitors iOS kernel thermal notifications. It dynamically reduces render frame rates to 30 FPS and dims the local OLED panel to pure black, shedding over 60% of device display heat while maintaining full external CarPlay streaming.")
                .font(.system(size: 12))
                .foregroundStyle(Color.dcTextSecondary)
        }
        .padding(16)
        .background(Color.dcSurfaceRaised.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.dcStroke, lineWidth: 1)
        )
    }
}
