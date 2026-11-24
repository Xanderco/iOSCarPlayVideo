import SwiftUI

/// Modal sheet providing intuitive controls and visual telemetry for the Cabin Acoustic DSP
/// and Speed-Compensated Road Noise Speech Enhancer.
public struct AcousticDSPSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dspService = CabinAcousticDSPService.shared
    @State private var isSimulatingSpeed: Bool = false
    @State private var simulationSpeedSlider: Double = 65.0

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Master Toggle & Summary Header Card
                        masterHeaderCard

                        // Vehicle Speed & Cabin Noise Telemetry Card
                        speedTelemetryCard

                        // Cabin Profile Selector
                        cabinProfilesSection

                        // Live 5-Band EQ Spectrum Visualizer
                        eqSpectrumVisualizerSection

                        // Acoustic Tuning & Intensity Controls
                        acousticTuningSection

                        // Educational Highway Noise Guide Card
                        educationalGuideCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Cabin Acoustic DSP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.dcAccent)
                }
            }
        }
    }

    // MARK: - Master Header Card

    private var masterHeaderCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(dspService.isEnabled ? Color.dcAccent.opacity(0.15) : Color.white.opacity(0.05))
                    .frame(width: 50, height: 50)
                Image(systemName: dspService.isEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(dspService.isEnabled ? Color.dcAccent : Color.white.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Dynamic Speech Enhancer")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Text(dspService.isEnabled ? "Counteracting cabin road & wind noise" : "Audio DSP bypassed")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Toggle("", isOn: $dspService.isEnabled)
                .labelsHidden()
                .tint(Color.dcAccent)
        }
        .padding(16)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Speed Telemetry Card

    private var speedTelemetryCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Acoustic Telemetry", systemImage: "speedometer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button {
                    isSimulatingSpeed.toggle()
                    if isSimulatingSpeed {
                        dspService.simulatedSpeedMph = simulationSpeedSlider
                    } else {
                        dspService.simulatedSpeedMph = nil
                    }
                } label: {
                    Text(isSimulatingSpeed ? "Live GPS" : "Simulate Speed")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isSimulatingSpeed ? Color.dcAccent.opacity(0.2) : Color.white.opacity(0.08))
                        .foregroundStyle(isSimulatingSpeed ? Color.dcAccent : .white.opacity(0.7))
                        .clipShape(Capsule())
                }
            }

            // 3-Metric Metric Row
            HStack(spacing: 12) {
                metricCell(
                    title: "Vehicle Speed",
                    value: String(format: "%.0f mph", dspService.effectiveSpeedMph),
                    icon: "car.circle.fill",
                    color: Color.dcAccent
                )

                metricCell(
                    title: "Cabin Noise",
                    value: String(format: "%.0f dBA", dspService.estimatedAmbientNoiseDBA()),
                    icon: "waveform.circle.fill",
                    color: noiseLevelColor(dspService.estimatedAmbientNoiseDBA())
                )

                metricCell(
                    title: "Vocal Lift",
                    value: String(format: "+%.1f dB", dspService.speedOffset(for: .vocalClarity, atSpeedMph: dspService.effectiveSpeedMph)),
                    icon: "arrow.up.circle.fill",
                    color: Color.dcAccent
                )
            }

            if isSimulatingSpeed {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Simulator Velocity:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(String(format: "%.0f mph", simulationSpeedSlider))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.dcAccent)
                    }
                    Slider(value: $simulationSpeedSlider, in: 0...90, step: 1) {
                        Text("Speed")
                    }
                    .tint(Color.dcAccent)
                    .onChange(of: simulationSpeedSlider) { _, newVal in
                        dspService.simulatedSpeedMph = newVal
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metricCell(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func noiseLevelColor(_ dba: Double) -> Color {
        if dba < 58 { return Color.green }
        if dba < 68 { return Color.dcAccent }
        return Color.orange
    }

    // MARK: - Cabin Profiles Section

    private var cabinProfilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cabin Acoustic Profile")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 8) {
                ForEach(CabinAcousticDSPService.CabinProfile.allCases) { profile in
                    let isSelected = dspService.selectedProfile == profile
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            dspService.selectedProfile = profile
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: profile.iconName)
                                .font(.system(size: 16, weight: .semibold))
                            Text(profile.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.dcAccent.opacity(0.2) : Color.dcSurface)
                        .foregroundStyle(isSelected ? Color.dcAccent : Color.white.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? Color.dcAccent : Color.white.opacity(0.08), lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Live 5-Band EQ Visualizer

    private var eqSpectrumVisualizerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Live 5-Band Equalizer Spectrum", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                if dspService.selectedProfile == .custom {
                    Button("Reset") {
                        dspService.resetToProfileDefaults()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dcAccent)
                }
            }

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(CabinAcousticDSPService.EQBand.allCases) { band in
                    eqBandColumn(band: band)
                }
            }
            .frame(height: 180)
            .padding(.vertical, 8)
        }
        .padding(16)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func eqBandColumn(band: CabinAcousticDSPService.EQBand) -> some View {
        let gain = dspService.computedGain(for: band)
        let normalized = max(0.05, min(1.0, (gain + 12.0) / 24.0))
        let barHeight: CGFloat = CGFloat(max(10.0, 110.0 * normalized))
        let gainColor: Color = gain > 0 ? Color.dcAccent : (gain < 0 ? Color.orange : Color.white.opacity(0.6))

        return VStack(spacing: 6) {
            Text(String(format: "%+.1f", gain))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(gainColor)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(maxWidth: .infinity)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.dcAccent)
                    .frame(height: barHeight)
            }
            .frame(height: 110)

            Text(band.label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)

            Text(band.roleDescription)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Acoustic Tuning Section

    private var acousticTuningSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed-Compensated Auto-EQ")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Scale dialogue lift and rumble cut with vehicle speed")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Toggle("", isOn: $dspService.speedCompensationEnabled)
                    .labelsHidden()
                    .tint(Color.dcAccent)
            }

            Divider().background(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speech Enhancer Intensity")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(String(format: "%.0f%%", dspService.speechEnhancerIntensity * 100))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.dcAccent)
                }

                Slider(value: $dspService.speechEnhancerIntensity, in: 0.1...1.0, step: 0.05)
                    .tint(Color.dcAccent)
            }
        }
        .padding(16)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Educational Guide Card

    private var educationalGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dcAccent)
                Text("How Cabin Road Noise Compensation Works")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Above 45 mph, tire roar and wind turbulence generate masking frequencies between 50 Hz and 400 Hz that overpower video dialogue. DashCast's parametric DSP dynamically cuts low-frequency cabin rumble while boosting the 2.5 kHz speech formant zone in real time, keeping podcasts and dialogue crisp without cranking master volume.")
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
