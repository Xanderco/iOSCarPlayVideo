import SwiftUI

/// In-car bottom sheet for calibrating audio/video lip-sync offset.
/// Designed for quick, legible interaction with large 48pt touch targets and high-contrast OLED styling.
public struct AudioSyncCalibrationSheet: View {
    @ObservedObject var syncService = AudioSyncOffsetService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pulseTriggered: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Current Offset Readout Card
                        VStack(spacing: 8) {
                            Text("A/V LATENCY COMPENSATION")
                                .font(ThemeFonts.hudCaption(size: 11))
                                .foregroundStyle(Color.dashTextMuted)
                                .tracking(1.5)

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(syncService.formattedOffset)
                                    .font(ThemeFonts.monospaceDigits(size: 44))
                                    .fontWeight(.bold)
                                    .foregroundStyle(syncService.isOffsetActive ? Color.dashYellow : Color.dashTextPrimary)

                                if syncService.isOffsetActive {
                                    Text("DELAY")
                                        .font(ThemeFonts.hudCaption(size: 11))
                                        .foregroundStyle(Color.dashYellow)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.dashYellow.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }

                            Text(syncService.selectedPreset.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.dashTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.dashSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(syncService.isOffsetActive ? Color.dashYellow.opacity(0.3) : Color.dashBorder, lineWidth: 1)
                        )

                        // Quick Presets
                        VStack(alignment: .leading, spacing: 10) {
                            Text("AUDIO CONNECTION PRESETS")
                                .font(ThemeFonts.hudCaption(size: 11))
                                .foregroundStyle(Color.dashTextMuted)
                                .tracking(1.2)
                                .padding(.horizontal, 4)

                            VStack(spacing: 8) {
                                ForEach(AudioSyncPreset.allCases) { preset in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            syncService.applyPreset(preset)
                                        }
                                    } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: preset.iconName)
                                                .font(.system(size: 18))
                                                .frame(width: 28)
                                                .foregroundStyle(syncService.selectedPreset == preset ? Color.dashYellow : Color.dashTextSecondary)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(preset.title)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(Color.dashTextPrimary)
                                                Text(preset.subtitle)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.dashTextSecondary)
                                            }

                                            Spacer()

                                            if syncService.selectedPreset == preset {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(Color.dashYellow)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(syncService.selectedPreset == preset ? Color.dashYellow.opacity(0.1) : Color.dashSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(syncService.selectedPreset == preset ? Color.dashYellow.opacity(0.4) : Color.dashBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Fine Adjustment Slider & Steppers
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("FINE-TUNE OFFSET")
                                    .font(ThemeFonts.hudCaption(size: 11))
                                    .foregroundStyle(Color.dashTextMuted)
                                    .tracking(1.2)
                                Spacer()
                                Text("-1500ms to +1500ms")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.dashTextSecondary)
                            }
                            .padding(.horizontal, 4)

                            VStack(spacing: 14) {
                                Slider(
                                    value: $syncService.offsetMilliseconds,
                                    in: AudioSyncOffsetService.minOffsetMs...AudioSyncOffsetService.maxOffsetMs,
                                    step: AudioSyncOffsetService.stepMs
                                )
                                .tint(Color.dashYellow)

                                HStack(spacing: 12) {
                                    Button {
                                        syncService.adjustOffset(by: -50)
                                    } label: {
                                        Label("-50ms", systemImage: "minus")
                                            .font(.system(size: 13, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color.dashSurfaceHighlight)
                                            .foregroundStyle(Color.dashTextPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }

                                    Button {
                                        syncService.adjustOffset(by: -10)
                                    } label: {
                                        Text("-10ms")
                                            .font(.system(size: 13, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color.dashSurfaceHighlight)
                                            .foregroundStyle(Color.dashTextPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }

                                    Button {
                                        syncService.adjustOffset(by: 10)
                                    } label: {
                                        Text("+10ms")
                                            .font(.system(size: 13, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color.dashSurfaceHighlight)
                                            .foregroundStyle(Color.dashTextPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }

                                    Button {
                                        syncService.adjustOffset(by: 50)
                                    } label: {
                                        Label("+50ms", systemImage: "plus")
                                            .font(.system(size: 13, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color.dashSurfaceHighlight)
                                            .foregroundStyle(Color.dashTextPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.dashSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.dashBorder, lineWidth: 1)
                            )
                        }

                        // Route Diagnostics & Calibration Pulse
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "speaker.wave.2.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.dashGreen)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Active Audio Route: \(syncService.detectedRouteName)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.dashTextPrimary)

                                    if syncService.detectedHardwareLatencyMs > 0 {
                                        Text(String(format: "Hardware Latency: ~%.0f ms", syncService.detectedHardwareLatencyMs))
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.dashTextSecondary)
                                    }
                                }
                                Spacer()

                                Toggle("", isOn: $syncService.autoRouteSyncEnabled)
                                    .labelsHidden()
                                    .tint(Color.dashYellow)
                            }
                            .padding(12)
                            .background(Color.dashSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            HStack(spacing: 12) {
                                Button {
                                    pulseTriggered = true
                                    syncService.playSyncPulse()
                                    Task {
                                        try? await Task.sleep(nanoseconds: 200_000_000)
                                        pulseTriggered = false
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: pulseTriggered ? "waveform.path" : "play.circle.fill")
                                        Text("Test Audio Pulse")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(pulseTriggered ? Color.white : Color.dashYellow)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                Button {
                                    syncService.reset()
                                } label: {
                                    Text("Reset to 0ms")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.dashTextSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.dashSurfaceHighlight)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("A/V Sync Offset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }
}
