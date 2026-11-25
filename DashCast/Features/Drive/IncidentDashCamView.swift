import SwiftUI
import UIKit
import AVFoundation

public struct IncidentDashCamView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var engine = IncidentDashCamEngine.shared

    @State private var isSimulatingIncident = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        windshieldPreviewCard
                        bufferControlCard
                        thresholdConfigCard
                        archivedClipsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Incident DashCam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.dcTextPrimary)
                }
            }
            .onAppear {
                engine.refreshHardwareAndPermissionState()
            }
        }
    }

    // MARK: - Windshield Preview & Telemetry Overlay

    private var windshieldPreviewCard: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if engine.isArmed && engine.isCameraAvailable && engine.cameraPermissionStatus == .authorized {
                    DashCamCameraPreview(session: engine.captureSession)
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color.dcSurface, Color.dcBackground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        VStack(spacing: 10) {
                            Image(systemName: engine.isArmed ? "video.badge.checkmark" : "video.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(engine.isArmed ? Color.dcAccent : Color.dcTextSecondary)
                            Text(engine.isArmed ? "Windshield Telemetry Loop Active" : "Windshield Incident Camera Standby")
                                .font(DSTypography.headline)
                                .foregroundStyle(Color.dcTextPrimary)
                            Text(previewSubtitle)
                                .font(DSTypography.footnote)
                                .foregroundStyle(Color.dcTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(engine.isArmed ? Color.dcAccent.opacity(0.6) : Color.dcStroke, lineWidth: 1)
            )

            // Top-left status pill + top-right 60s rolling indicator
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(engine.isArmed ? Color.dcLive : Color.dcTextTertiary)
                            .frame(width: 8, height: 8)
                        Text(engine.isArmed ? "REC • 60s LOOP" : "STANDBY")
                            .font(DSTypography.badge)
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.72))
                    .clipShape(Capsule())

                    Spacer()

                    Text(String(format: "%.2f G", engine.currentDecelerationG))
                        .font(DSTypography.numeric)
                        .foregroundStyle(
                            engine.currentDecelerationG > engine.decelerationThresholdG
                            ? Color.dcDanger
                            : Color.dcAccent
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.72))
                        .clipShape(Capsule())
                }
                .padding(12)

                Spacer()

                // Embedded Windshield Watermark Bar
                HStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.dcAccent)
                    Text(engine.latestTelemetryWatermark)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(10)
            }
            .frame(height: 200)
        }
    }

    private var previewSubtitle: LocalizedStringKey {
        if !engine.isCameraAvailable {
            return "Telemetry ring buffer running in sensor mode; real camera activates on device."
        }
        if engine.cameraPermissionStatus != .authorized {
            return "Grant camera access to capture rolling 10s HD video segments alongside G-force telemetry."
        }
        return "60-second circular buffer overwrites old segments automatically unless a >0.6G impact triggers."
    }

    // MARK: - Buffer Controls

    private var bufferControlCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rolling 60s Incident Loop")
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcTextPrimary)
                    Text("Buffered: \(Int(engine.bufferedSeconds.rounded()))s / 60s")
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dcTextSecondary)
                }

                Spacer()

                Button {
                    if engine.isArmed {
                        engine.disarm()
                    } else {
                        Task {
                            if engine.isCameraAvailable && engine.cameraPermissionStatus == .notDetermined {
                                _ = await engine.requestCameraAccess()
                            }
                            engine.arm(useMilesPerHour: appState.useMilesPerHour)
                        }
                    }
                } label: {
                    Text(engine.isArmed ? "Disarm" : "Arm Loop")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(engine.isArmed ? Color.white : Color.dcOnAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(engine.isArmed ? Color.dcDanger : Color.dcAccent)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("DashCam_ArmToggle")
            }

            ProgressView(value: min(engine.bufferedSeconds, 60.0), total: 60.0)
                .tint(engine.isArmed ? Color.dcAccent : Color.dcTextTertiary)

            HStack(spacing: 10) {
                Button {
                    guard !isSimulatingIncident else { return }
                    isSimulatingIncident = true
                    Task {
                        _ = await engine.triggerIncidentArchive(
                            reason: .manualEmergency,
                            useMilesPerHour: appState.useMilesPerHour
                        )
                        isSimulatingIncident = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down.fill")
                        Text("Save Last 60s")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dcTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.dcSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .accessibilityIdentifier("DashCam_SaveNowButton")

                Button {
                    guard !isSimulatingIncident else { return }
                    isSimulatingIncident = true
                    Task {
                        _ = await engine.simulateGShockTest(useMilesPerHour: appState.useMilesPerHour)
                        isSimulatingIncident = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Test >0.6G Trigger")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dcWarning)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.dcSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .accessibilityIdentifier("DashCam_SimulateShockButton")
            }
        }
        .padding(14)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dcStroke, lineWidth: 1)
        )
    }

    // MARK: - Deceleration Threshold Configuration

    private var thresholdConfigCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("G-Shock Deceleration Threshold")
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dcTextPrimary)
                Spacer()
                Text(String(format: "%.2f G", engine.decelerationThresholdG))
                    .font(DSTypography.numeric)
                    .foregroundStyle(Color.dcAccent)
            }

            Slider(
                value: Binding(
                    get: { engine.decelerationThresholdG },
                    set: { engine.setDecelerationThresholdG($0) }
                ),
                in: IncidentTriggerPolicy.minThresholdG...IncidentTriggerPolicy.maxThresholdG,
                step: 0.05
            )
            .tint(Color.dcAccent)

            Text("Hard braking or impact above this threshold automatically locks and watermarks the rolling 60-second clip on this iPhone.")
                .font(DSTypography.footnote)
                .foregroundStyle(Color.dcTextSecondary)
        }
        .padding(14)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dcStroke, lineWidth: 1)
        )
    }

    // MARK: - Archived Incident Clips

    private var archivedClipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Saved Incident Clips")
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dcTextPrimary)
                Spacer()
                Text(verbatim: "\(engine.archivedClips.count)")
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dcTextSecondary)
            }

            if engine.archivedClips.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "shield.checkmark")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.dcTextTertiary)
                    Text("No incident clips archived yet")
                        .font(DSTypography.subheadline)
                        .foregroundStyle(Color.dcTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.dcSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(engine.archivedClips) { clip in
                    incidentClipRow(clip)
                }
            }
        }
    }

    private func incidentClipRow(_ clip: IncidentClipRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(LocalizedStringKey(clip.triggerReason.displayTitle))
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dcTextPrimary)
                Spacer()
                Text(String(format: "%.2f G", clip.peakDecelerationG))
                    .font(DSTypography.badge)
                    .foregroundStyle(Color.dcDanger)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.dcDanger.opacity(0.15))
                    .clipShape(Capsule())
            }

            Text(clip.watermarkText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.dcTextSecondary)

            HStack(spacing: 12) {
                Text("\(Int(clip.durationSeconds.rounded()))s clip")
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dcTextTertiary)

                Spacer()

                Button {
                    engine.toggleLock(clipID: clip.id)
                } label: {
                    Label(clip.isLocked ? "Locked" : "Lock", systemImage: clip.isLocked ? "lock.fill" : "lock.open")
                        .font(DSTypography.caption)
                        .foregroundStyle(clip.isLocked ? Color.dcAccent : Color.dcTextSecondary)
                }

                Button(role: .destructive) {
                    engine.deleteClip(clipID: clip.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dcDanger)
                }
            }
        }
        .padding(12)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(clip.isLocked ? Color.dcAccent.opacity(0.5) : Color.dcStroke, lineWidth: 1)
        )
    }
}

// MARK: - Camera Preview Representable

private struct DashCamCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = layer as? AVCaptureVideoPreviewLayer else {
                return AVCaptureVideoPreviewLayer()
            }
            return layer
        }
    }
}
