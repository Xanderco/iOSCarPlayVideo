import SwiftUI

/// Cockpit DarkShield Management & Night-Vision Photopic Filter Configuration Sheet.
public struct DarkShieldVisionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var visionService = DarkShieldVisionService.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header Status Aura Card
                        statusHeaderCard

                        // Photopic Presets Selector
                        presetSelectorSection

                        // Glare Reduction & Dimming Controls
                        glareControlsSection

                        // Automated Protection Toggles
                        automatedTogglesSection

                        // Simulation & Testing Controls
                        simulationSection

                        // Educational Science Card
                        educationalCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("DarkShield™ Glare Guard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }

    // MARK: - Header Status Card

    private var statusHeaderCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color.dcSurfaceRaised, Color.dcSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(visionService.statusColor.opacity(0.20))
                            .frame(width: 50, height: 50)

                        Image(systemName: visionService.statusIconName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(visionService.statusColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(visionService.statusTitle)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.dcTextPrimary)

                            Spacer()

                            Text(visionService.isActive ? "ACTIVE" : "STANDBY")
                                .font(.system(size: 11, weight: .black))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(visionService.isActive ? visionService.statusColor.opacity(0.25) : Color.gray.opacity(0.25))
                                .foregroundStyle(visionService.isActive ? visionService.statusColor : Color.gray)
                                .clipShape(Capsule())
                        }

                        Text(visionService.statusSubtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.dcTextSecondary)
                    }
                }

                Divider().background(Color.dcStroke)

                // Live Photopic Swatch Preview
                HStack(spacing: 10) {
                    Text("Live Filter Response:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.dcTextSecondary)

                    Spacer()

                    HStack(spacing: 4) {
                        ForEach([0.2, 0.5, 0.8, 1.0], id: \.self) { sample in
                            let transformed = visionService.colorTransform(r: sample, g: sample, b: sample)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(red: transformed.r, green: transformed.g, blue: transformed.b))
                                .frame(width: 28, height: 16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
            .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(visionService.isActive ? visionService.statusColor.opacity(0.35) : Color.dcStroke, lineWidth: 1)
        )
    }

    // MARK: - Preset Selector Section

    private var presetSelectorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PHOTOPIC FILTER PRESETS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dcTextSecondary)
                .tracking(1.2)

            VStack(spacing: 8) {
                ForEach(DarkShieldFilterPreset.allCases, id: \.self) { preset in
                    presetRow(preset)
                }
            }
        }
    }

    private func presetRow(_ preset: DarkShieldFilterPreset) -> some View {
        let isSelected = visionService.selectedPreset == preset
        return Button {
            visionService.setPreset(preset)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(preset.accentColor.opacity(isSelected ? 0.25 : 0.12))
                        .frame(width: 38, height: 38)

                    Image(systemName: preset.systemIconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(preset.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.localizedTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.dcTextPrimary)

                    Text(preset.wavelengthDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(preset.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.dcSurfaceRaised : Color.dcSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? preset.accentColor.opacity(0.6) : Color.dcStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Glare Controls

    private var glareControlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GLARE REDUCTION INTENSITY")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dcTextSecondary)
                .tracking(1.2)

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.dcSurface)

                VStack(spacing: 12) {
                    HStack {
                        Text("Filter Strength")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.dcTextPrimary)
                        Spacer()
                        Text("\(Int(visionService.glareReductionLevel * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(visionService.statusColor)
                    }

                    Slider(
                        value: $visionService.glareReductionLevel,
                        in: 0.1...1.0,
                        step: 0.05
                    )
                    .tint(visionService.statusColor)

                    HStack {
                        Text("Soft Muted")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dcTextSecondary)
                        Spacer()
                        Text("Maximum Dark Adaptation")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dcTextSecondary)
                    }
                }
                .padding(14)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.dcStroke, lineWidth: 1)
            )
        }
    }

    // MARK: - Automated Toggles

    private var automatedTogglesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AUTOMATED OPTICAL GUARDS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dcTextSecondary)
                .tracking(1.2)

            VStack(spacing: 1) {
                toggleRow(
                    title: "Auto-Tunnel Night Transition",
                    subtitle: "Instantly engages photopic guard when GPS detects mountain tunnels or covered underpasses.",
                    icon: "tunnel",
                    color: Color.dashCyan,
                    isOn: $visionService.isAutoTunnelEnabled
                )

                Divider().background(Color.dcStroke)

                toggleRow(
                    title: "Windshield Reflection Suppressor",
                    subtitle: "Subtly darkens top 25% of display canvas to eliminate mirror reflections on slanted windshields.",
                    icon: "car.top.radiowaves.rear.left.and.rear.right",
                    color: Color.dashYellow,
                    isOn: $visionService.isWindshieldReflectionSuppressed
                )

                Divider().background(Color.dcStroke)

                toggleRow(
                    title: "Invert Harsh White Web Wrappers",
                    subtitle: "Automatically darkens blinding white webpage backgrounds in embedded casting browser.",
                    icon: "circle.lefthalf.filled.inverse",
                    color: Color.dcSuccess,
                    isOn: $visionService.isInvertWhiteBackgroundsEnabled
                )
            }
            .background(Color.dcSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.dcStroke, lineWidth: 1)
            )
        }
    }

    private func toggleRow(title: String, subtitle: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dcTextPrimary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dcTextSecondary)
                        .lineLimit(2)
                }
            }
        }
        .tint(Color.dashYellow)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Simulation

    private var simulationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OPTICAL SIMULATION (DEBUG / PARKED)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dcTextSecondary)
                .tracking(1.2)

            HStack(spacing: 10) {
                Button {
                    visionService.simulateTunnel(visionService.simulatedTunnelActive == true ? nil : true)
                } label: {
                    HStack {
                        Image(systemName: "tunnel")
                        Text(visionService.simulatedTunnelActive == true ? "Exit Tunnel" : "Enter Tunnel")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(visionService.simulatedTunnelActive == true ? Color.dashCyan : Color.dcSurface)
                    .foregroundStyle(visionService.simulatedTunnelActive == true ? Color.black : Color.dcTextPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.dcStroke, lineWidth: 1)
                    )
                }

                Button {
                    visionService.cycleNextPreset()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Cycle Preset")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.dcSurface)
                    .foregroundStyle(Color.dcTextPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.dcStroke, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Science Education

    private var educationalCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.dcSurface.opacity(0.6))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.dashGold)
                    Text("Night Driving & Human Dark Adaptation")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.dcTextPrimary)
                }

                Text("Blue light (400–490nm) from windshield-mounted displays causes severe Rayleigh scattering in glass and photochemically bleaches rhodopsin in the driver's eye, taking up to 30 minutes to regenerate. DarkShield™ Aviation Red (650nm) and Photopic Amber bypass rod receptors to ensure headlights, pedestrians, and road markings remain instantly visible in pitch darkness.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.dcTextSecondary)
                    .lineSpacing(3)
            }
            .padding(14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.dcStroke, lineWidth: 1)
        )
    }
}
