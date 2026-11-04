import SwiftUI

public struct LiveActivityPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var previewSpeed: Double = 68.0
    @State private var previewGForce: Double = 0.24
    @State private var previewPeakG: Double = 0.48
    @State private var previewScore: Double = 98.0
    @State private var previewDistanceKm: Double = 4.8
    @State private var previewMinutes: Double = 12.0
    @State private var previewPaused: Bool = false
    @State private var isTeaserMode: Bool = false
    @State private var selectedIslandMode: IslandMode = .expanded

    public enum IslandMode: String, CaseIterable, Identifiable {
        case expanded = "Expanded"
        case compact = "Compact"
        case minimal = "Minimal"

        public var id: String { rawValue }
    }

    public init() {}

    private var speedUnit: String {
        appState.useMilesPerHour ? "MPH" : "KM/H"
    }

    private var attributes: DashCastTelemetryAttributes {
        DashCastTelemetryAttributes(
            vehicleName: "Cyberpunk GT",
            speedUnit: speedUnit,
            useMilesPerHour: appState.useMilesPerHour
        )
    }

    private var contentState: DashCastTelemetryAttributes.ContentState {
        let mins = Int(previewMinutes)
        let secs = 30
        let timeStr = String(format: "%02d:%02d", mins, secs)
        let distStr = appState.useMilesPerHour ?
            String(format: "%.2f mi", previewDistanceKm * 0.621371) :
            String(format: "%.2f km", previewDistanceKm)

        return DashCastTelemetryAttributes.ContentState(
            currentSpeed: previewSpeed,
            currentSpeedKmh: appState.useMilesPerHour ? previewSpeed / 0.621371 : previewSpeed,
            topSpeed: max(previewSpeed, 118.0),
            distanceFormatted: distStr,
            distanceMeters: previewDistanceKm * 1000.0,
            elapsedTime: previewMinutes * 60.0 + 30.0,
            elapsedDurationFormatted: timeStr,
            currentGForce: previewGForce,
            peakGForce: previewPeakG,
            smoothnessScore: Int(previewScore),
            isPaused: previewPaused,
            isParked: previewSpeed < 1.0,
            teaserMode: isTeaserMode
        )
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Section 1: Dynamic Island Simulation
                        dynamicIslandSection

                        // Section 2: Lock Screen Widget Card Simulation
                        lockScreenSection

                        // Section 3: Interactive Simulation Controls
                        simulationControlsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Live Activity Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.dashTextMuted)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if DriveLiveActivityManager.shared.isLiveActivityActive {
                            DriveLiveActivityManager.shared.endLiveActivity(dismissImmediately: true)
                        } else {
                            DriveLiveActivityManager.shared.startLiveActivity(
                                vehicleName: "Cyberpunk GT",
                                speedUnit: speedUnit,
                                useMilesPerHour: appState.useMilesPerHour,
                                initialSpeed: previewSpeed,
                                teaserMode: isTeaserMode
                            )
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: DriveLiveActivityManager.shared.isLiveActivityActive ? "stop.circle.fill" : "play.circle.fill")
                            Text(DriveLiveActivityManager.shared.isLiveActivityActive ? "Stop Live" : "Launch Live")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DriveLiveActivityManager.shared.isLiveActivityActive ? Color.dashRed : Color.dashYellow)
                    }
                }
            }
        }
    }

    // MARK: - Dynamic Island Section

    private var dynamicIslandSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DYNAMIC ISLAND")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.dashYellow)

                Spacer()

                Picker("Mode", selection: $selectedIslandMode) {
                    ForEach(IslandMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }

            ZStack {
                // iPhone Dynamic Island Black Pill Bezel
                switch selectedIslandMode {
                case .expanded:
                    VStack(spacing: 8) {
                        HStack(alignment: .top) {
                            DynamicIslandExpandedLeadingView(state: contentState, attributes: attributes)
                            Spacer()
                            DynamicIslandExpandedCenterView(attributes: attributes, state: contentState)
                            Spacer()
                            DynamicIslandExpandedTrailingView(state: contentState)
                        }
                        DynamicIslandExpandedBottomView(state: contentState, attributes: attributes)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 38, style: .continuous)
                            .stroke(Color.dashBorder, lineWidth: 1)
                    )

                case .compact:
                    HStack {
                        DynamicIslandCompactLeadingView(state: contentState)
                        Spacer()
                        DynamicIslandCompactTrailingView(state: contentState)
                    }
                    .padding(.horizontal, 12)
                    .frame(width: 210, height: 38)
                    .background(Color.black)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.dashBorder, lineWidth: 1))

                case .minimal:
                    DynamicIslandMinimalView(state: contentState)
                        .frame(width: 44, height: 44)
                        .background(Color.black)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.dashBorder, lineWidth: 1))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - Lock Screen Section

    private var lockScreenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LOCK SCREEN LIVE ACTIVITY")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.dashYellow)

                Spacer()

                Button {
                    isTeaserMode.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(isTeaserMode ? "Show Telemetry" : "Show Teaser")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.dashYellow)
                }
            }

            // Lock Screen Widget Card
            DashCastLockScreenLiveActivityView(state: contentState, attributes: attributes)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.dashBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }

    // MARK: - Simulation Controls Section

    private var simulationControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LIVE TELEMETRY CALIBRATION")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color.dashTextMuted)

            VStack(spacing: 16) {
                // Speed Slider
                VStack(spacing: 6) {
                    HStack {
                        Text("Speed")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)
                        Spacer()
                        Text(String(format: "%.0f %@", previewSpeed, speedUnit))
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.dashYellow)
                    }
                    Slider(value: $previewSpeed, in: 0...180, step: 1)
                        .tint(Color.dashYellow)
                }

                Divider().background(Color.dashBorder)

                // G-Force Slider
                VStack(spacing: 6) {
                    HStack {
                        Text("Lateral / Dynamic G-Force")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)
                        Spacer()
                        Text(String(format: "%.2f G", previewGForce))
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.dashOrange)
                    }
                    Slider(value: $previewGForce, in: 0.0...1.0, step: 0.02)
                        .tint(Color.dashOrange)
                        .onChange(of: previewGForce) { newVal in
                            if newVal > previewPeakG { previewPeakG = newVal }
                        }
                }

                Divider().background(Color.dashBorder)

                // Smoothness Score Slider
                VStack(spacing: 6) {
                    HStack {
                        Text("Smoothness Score")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)
                        Spacer()
                        Text(String(format: "%.0f / 100", previewScore))
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(contentState.scoreColor)
                    }
                    Slider(value: $previewScore, in: 20...100, step: 1)
                        .tint(contentState.scoreColor)
                }

                Divider().background(Color.dashBorder)

                // Paused Toggle
                Toggle(isOn: $previewPaused) {
                    Text("Trip Paused")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)
                }
                .tint(Color.dashYellow)
            }
            .padding(16)
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
