import SwiftUI

/// Interactive settings, calibration, and waveform test console for `CabinHapticsEngine`.
public struct CabinHapticsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var engine = CabinHapticsEngine.shared

    public init() {}

    private var displaySpeedLimit: Double {
        appState.useMilesPerHour
            ? (engine.speedWarningLimitKmh * 0.621371).rounded()
            : engine.speedWarningLimitKmh.rounded()
    }

    private var speedUnitLabel: String {
        appState.useMilesPerHour ? "MPH" : "KM/H"
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.lg) {
                    statusCard
                    safetyControlsCard
                    waveformsSection
                    if !engine.triggerHistory.isEmpty {
                        recentActivitySection
                    }
                }
                .padding(.horizontal, DSSpacing.screenGutter)
                .padding(.vertical, DSSpacing.md)
            }
            .background(Color.dcBackground.ignoresSafeArea())
            .navigationTitle("Cabin Haptics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.dcAccent)
                }

                if !engine.triggerHistory.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            engine.resetSessionState()
                        }
                        .foregroundStyle(Color.dcTextSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack(spacing: DSSpacing.md) {
                ZStack {
                    Circle()
                        .fill(engine.isHapticsEnabled ? Color.dcAccentSoft : Color.dcSurfaceRaised)
                        .frame(width: 48, height: 48)
                    Image(systemName: "waveform.path")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(engine.isHapticsEnabled ? Color.dcAccent : Color.dcTextTertiary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(engine.isHapticsEnabled ? "Cabin Tactile Engine Active" : "Cabin Haptics Paused")
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcTextPrimary)

                    Text(engine.supportsCoreHaptics ? "CoreHaptics waveform synthesis ready" : "Tactile generator fallback mode")
                        .font(DSTypography.footnote)
                        .foregroundStyle(Color.dcTextSecondary)
                }

                Spacer()
            }

            Divider().background(Color.dcSeparator)

            HStack(spacing: DSSpacing.sm) {
                statusPill(
                    title: engine.isVehicleMoving ? "Moving" : "Parked",
                    color: engine.isVehicleMoving ? Color.dcWarning : Color.dcSuccess
                )

                if engine.suppressNonCriticalWhileMoving && engine.isVehicleMoving {
                    statusPill(title: "Safety Alerts Only", color: Color.dcInfo)
                }

                if engine.isQuietModeEnabled {
                    statusPill(title: "Quiet Mode", color: Color.dcPro)
                }

                Spacer()
            }
        }
        .dsCard()
    }

    private func statusPill(title: LocalizedStringKey, color: Color) -> some View {
        Text(title)
            .font(DSTypography.badge)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Safety & Calibration Controls

    private var safetyControlsCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Motion & Safety Rules")
                .font(DSTypography.title3)
                .foregroundStyle(Color.dcTextPrimary)

            VStack(spacing: 0) {
                Toggle(isOn: $engine.isHapticsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Cabin Haptics")
                            .font(DSTypography.headline)
                            .foregroundStyle(Color.dcTextPrimary)
                        Text("Master switch for all tactile cues")
                            .font(DSTypography.footnote)
                            .foregroundStyle(Color.dcTextSecondary)
                    }
                }
                .tint(Color.dcAccent)
                .accessibilityIdentifier("CabinHaptics_MasterToggle")
                .padding(.vertical, DSSpacing.sm)

                Divider().background(Color.dcSeparator)

                Toggle(isOn: $engine.suppressNonCriticalWhileMoving) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suppress Non-Critical While Moving")
                            .font(DSTypography.headline)
                            .foregroundStyle(Color.dcTextPrimary)
                        Text("Silences buffering & UI taps above 8 km/h; keeps safety alerts active")
                            .font(DSTypography.footnote)
                            .foregroundStyle(Color.dcTextSecondary)
                    }
                }
                .tint(Color.dcAccent)
                .disabled(!engine.isHapticsEnabled)
                .padding(.vertical, DSSpacing.sm)

                Divider().background(Color.dcSeparator)

                Toggle(isOn: $engine.isQuietModeEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quiet Mode (Safety Only)")
                            .font(DSTypography.headline)
                            .foregroundStyle(Color.dcTextPrimary)
                        Text("Only speed warnings and harsh driving alerts fire")
                            .font(DSTypography.footnote)
                            .foregroundStyle(Color.dcTextSecondary)
                    }
                }
                .tint(Color.dcAccent)
                .disabled(!engine.isHapticsEnabled)
                .padding(.vertical, DSSpacing.sm)

                Divider().background(Color.dcSeparator)

                Toggle(isOn: $engine.isSpeedWarningEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Speed Warning Vibration")
                            .font(DSTypography.headline)
                            .foregroundStyle(Color.dcTextPrimary)
                        Text("Double warning thud when exceeding speed limit")
                            .font(DSTypography.footnote)
                            .foregroundStyle(Color.dcTextSecondary)
                    }
                }
                .tint(Color.dcAccent)
                .disabled(!engine.isHapticsEnabled)
                .padding(.vertical, DSSpacing.sm)

                if engine.isSpeedWarningEnabled {
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        HStack {
                            Text("Speed Threshold")
                                .font(DSTypography.subheadline)
                                .foregroundStyle(Color.dcTextSecondary)
                            Spacer()
                            Text("\(Int(displaySpeedLimit)) \(speedUnitLabel)")
                                .font(DSTypography.numeric)
                                .foregroundStyle(Color.dcAccent)
                        }
                        Slider(value: $engine.speedWarningLimitKmh, in: 60...180, step: 5)
                            .tint(Color.dcAccent)
                    }
                    .padding(.vertical, DSSpacing.xs)
                }

                Divider().background(Color.dcSeparator)

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    HStack {
                        Text("Vibration Intensity")
                            .font(DSTypography.subheadline)
                            .foregroundStyle(Color.dcTextSecondary)
                        Spacer()
                        Text("\(Int((engine.intensityScale * 100).rounded()))%")
                            .font(DSTypography.numeric)
                            .foregroundStyle(Color.dcAccent)
                    }
                    Slider(value: $engine.intensityScale, in: 0.3...1.0, step: 0.05)
                        .tint(Color.dcAccent)
                }
                .padding(.top, DSSpacing.sm)
            }
        }
        .dsCard()
    }

    // MARK: - Calibrated Waveforms

    private var waveformsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Calibrated Waveforms")
                .font(DSTypography.title3)
                .foregroundStyle(Color.dcTextPrimary)

            VStack(spacing: DSSpacing.sm) {
                ForEach(CabinHapticCue.allCases) { cue in
                    waveformRow(for: cue)
                }
            }
        }
    }

    private func waveformRow(for cue: CabinHapticCue) -> some View {
        HStack(spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(cue.displayName))
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcTextPrimary)

                    if cue.allowsWhileMoving {
                        Text("Moving Safe")
                            .font(DSTypography.badge)
                            .foregroundStyle(Color.dcSuccess)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.dcSuccess.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(LocalizedStringKey(cue.subtitle))
                    .font(DSTypography.footnote)
                    .foregroundStyle(Color.dcTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(cue.waveform.patternFamily) · \(String(format: "%.2fs", cue.waveform.totalDuration))")
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dcTextTertiary)
            }

            Spacer()

            Button {
                _ = engine.preview(cue)
            } label: {
                Text("Test")
                    .font(DSTypography.badge)
                    .foregroundStyle(Color.dcOnAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(engine.isHapticsEnabled ? Color.dcAccent : Color.dcSurfaceRaised)
                    .clipShape(Capsule())
            }
            .disabled(!engine.isHapticsEnabled)
            .accessibilityIdentifier("CabinHaptics_Test_\(cue.rawValue)")
        }
        .dsCard(radius: DSRadius.md, padding: DSSpacing.md)
    }

    // MARK: - Recent Trigger Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Recent Cue Activity")
                .font(DSTypography.title3)
                .foregroundStyle(Color.dcTextPrimary)

            VStack(spacing: DSSpacing.xs) {
                ForEach(engine.triggerHistory.prefix(8)) { record in
                    HStack {
                        Image(systemName: record.triggered ? "checkmark.circle.fill" : "slash.circle.fill")
                            .foregroundStyle(record.triggered ? Color.dcSuccess : Color.dcWarning)

                        Text(LocalizedStringKey(record.cue.displayName))
                            .font(DSTypography.subheadline)
                            .foregroundStyle(Color.dcTextPrimary)

                        Spacer()

                        if let reason = record.suppressionReason {
                            Text(LocalizedStringKey(reason.localizedLabel))
                                .font(DSTypography.caption)
                                .foregroundStyle(Color.dcWarning)
                        } else {
                            Text("Fired")
                                .font(DSTypography.caption)
                                .foregroundStyle(Color.dcSuccess)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .dsCard(radius: DSRadius.md, padding: DSSpacing.md)
        }
    }
}
