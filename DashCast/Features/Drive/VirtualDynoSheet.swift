import SwiftUI

/// Virtual Dyno Studio modal sheet for tracking 0-60 mph, 1/4-mile sprints, and G-force curves.
public struct VirtualDynoSheet: View {
    @ObservedObject public var engine: VirtualDynoEngine = .shared
    public var useMilesPerHour: Bool = true
    @Environment(\.dismiss) private var dismiss

    public init(engine: VirtualDynoEngine = .shared, useMilesPerHour: Bool = true) {
        self.engine = engine
        self.useMilesPerHour = useMilesPerHour
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.lg) {
                    // Christmas Tree Launch HUD
                    stageDisplayCard

                    // Milestones Breakdown Grid
                    milestonesGrid

                    // Personal Bests Showcase
                    personalBestsSection

                    // Run History
                    historySection
                }
                .padding(.horizontal, DSSpacing.screenGutter)
                .padding(.vertical, DSSpacing.md)
            }
            .background(Color.dcBackground.ignoresSafeArea())
            .navigationTitle("Virtual Dyno Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color.dcTextPrimary)
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            engine.clearHistory()
                        } label: {
                            Label("Clear Run History", systemImage: "trash")
                        }

                        Toggle("Auto-Arm on Stop", isOn: $engine.isAutoArmEnabled)

                        Button {
                            engine.reset()
                        } label: {
                            Label("Reset Stopwatch", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17))
                            .foregroundColor(Color.dcTextPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Stage Card

    private var stageDisplayCard: some View {
        VStack(spacing: DSSpacing.md) {
            // Drag Strip Christmas Tree Lights
            HStack(spacing: DSSpacing.lg) {
                // Pre-Stage Amber
                treeLight(
                    label: "STAGE",
                    color: Color.dcWarning,
                    isActive: engine.state == .staged || engine.state == .sprinting
                )

                // Armed / Sprinting Green
                treeLight(
                    label: "LAUNCH",
                    color: Color.dcAccent,
                    isActive: engine.state == .sprinting
                )

                // Finish Blue
                treeLight(
                    label: "FINISH",
                    color: Color.dcPro,
                    isActive: engine.state == .completed
                )
            }
            .padding(.top, DSSpacing.xs)

            // Huge Timer Readout
            VStack(spacing: 2) {
                Text(formattedElapsedTime)
                    .font(.system(size: 56, weight: .black, design: .monospaced))
                    .foregroundColor(Color.dcTextPrimary)

                Text(engine.state.localizedDescription)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(statusColor)
                    .textCase(.uppercase)
            }

            // G-Force and Speed Telemetry Bar
            HStack(spacing: DSSpacing.md) {
                telemetryPill(
                    title: "SPEED",
                    value: String(format: "%.0f %@", currentSpeed, speedUnitLabel)
                )

                telemetryPill(
                    title: "PEAK G",
                    value: String(format: "+%.2f G", peakLongitudinalG)
                )

                telemetryPill(
                    title: "DISTANCE",
                    value: String(format: "%.0f m", currentDistance)
                )
            }

            // Action Buttons
            HStack(spacing: DSSpacing.md) {
                if engine.state == .staged {
                    Button(action: {
                        engine.disarmManually()
                    }) {
                        Text("Disarm")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.dcTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DSSpacing.sm)
                            .background(Color.dcSurfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                    }
                } else if engine.state == .idle {
                    Button(action: {
                        engine.armManually()
                    }) {
                        Text("Arm for Launch")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.dcOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DSSpacing.sm)
                            .background(Color.dcAccent)
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                    }
                } else {
                    Button(action: {
                        engine.reset()
                    }) {
                        Text("Reset Dyno")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.dcTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DSSpacing.sm)
                            .background(Color.dcSurfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                    }
                }
            }
        }
        .padding(DSSpacing.lg)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous)
                .stroke(Color.dcStroke, lineWidth: 1)
        )
    }

    private func treeLight(label: String, color: Color, isActive: Bool) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isActive ? color : Color.dcSurfaceRaised)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(isActive ? color.opacity(0.8) : Color.clear, lineWidth: 2)
                        .scaleEffect(isActive ? 1.25 : 1.0)
                        .opacity(isActive ? 0.6 : 0.0)
                )

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isActive ? color : Color.dcTextTertiary)
        }
    }

    private func telemetryPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.dcTextTertiary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Color.dcTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xs)
        .background(Color.dcSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
    }

    // MARK: - Milestones Breakdown Grid

    private var milestonesGrid: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("SPLIT MILESTONES")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.dcTextTertiary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DSSpacing.md) {
                milestoneCard(
                    title: "0 - 30 MPH",
                    time: split0To30,
                    icon: "speedometer"
                )

                milestoneCard(
                    title: "0 - 60 MPH",
                    time: split0To60,
                    icon: "bolt.fill",
                    highlight: true
                )

                milestoneCard(
                    title: "0 - 100 KM/H",
                    time: split0To100Kmh,
                    icon: "flag.checkered"
                )

                milestoneCard(
                    title: "1/4 MILE",
                    time: splitQuarterMile,
                    subtext: trapSpeedQuarterMile,
                    icon: "gauge.with.needle"
                )
            }
        }
    }

    private func milestoneCard(
        title: String,
        time: Double?,
        subtext: String? = nil,
        icon: String,
        highlight: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(highlight ? Color.dcAccent : Color.dcTextSecondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(highlight ? Color.dcAccent : Color.dcTextTertiary)
            }

            if let t = time {
                Text(String(format: "%.2f s", t))
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color.dcTextPrimary)
            } else {
                Text("--")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.dcTextTertiary)
            }

            if let sub = subtext {
                Text(sub)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.dcTextSecondary)
            }
        }
        .padding(DSSpacing.md)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .stroke(highlight ? Color.dcAccent.opacity(0.4) : Color.dcStroke, lineWidth: 1)
        )
    }

    // MARK: - Personal Bests Section

    private var personalBestsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("PERSONAL BEST RECORDS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.dcTextTertiary)

            HStack(spacing: DSSpacing.md) {
                // PB 0-60
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dcPro)
                        Text("Best 0-60 MPH")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.dcPro)
                    }

                    if let pb = engine.personalBest0To60?.time0To60 {
                        Text(String(format: "%.2f s", pb))
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(Color.dcTextPrimary)
                    } else {
                        Text("No runs yet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dcTextTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DSSpacing.md)
                .background(Color.dcSurface)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.lg)
                        .stroke(Color.dcPro.opacity(0.3), lineWidth: 1)
                )

                // PB 1/4 Mile
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "medal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dcAccent)
                        Text("Best 1/4 Mile")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.dcAccent)
                    }

                    if let pb = engine.personalBestQuarterMile?.timeQuarterMile {
                        Text(String(format: "%.2f s", pb))
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(Color.dcTextPrimary)
                    } else {
                        Text("No runs yet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dcTextTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DSSpacing.md)
                .background(Color.dcSurface)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.lg)
                        .stroke(Color.dcAccent.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Run History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("SPRINT LOG HISTORY (\(engine.sprintHistory.count))")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.dcTextTertiary)

            if engine.sprintHistory.isEmpty {
                VStack(spacing: DSSpacing.xs) {
                    Text("No sprint records captured yet.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dcTextSecondary)
                    Text("Stop the car completely to stage the drag timer, then floor the accelerator!")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dcTextTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(DSSpacing.xl)
                .background(Color.dcSurface)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg))
            } else {
                ForEach(engine.sprintHistory) { record in
                    sprintRow(record: record)
                }
            }
        }
    }

    private func sprintRow(record: SprintRecord) -> some View {
        HStack(spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.dcTextTertiary)

                HStack(spacing: DSSpacing.md) {
                    if let t60 = record.time0To60 {
                        Text(String(format: "0-60: %.2fs", t60))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.dcTextPrimary)
                    }

                    if let tQ = record.timeQuarterMile {
                        Text(String(format: "1/4m: %.2fs", tQ))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.dcTextSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "+%.2f G", record.peakLongitudinalG))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.dcAccent)
                Text("Peak Accel")
                    .font(.system(size: 10))
                    .foregroundColor(Color.dcTextTertiary)
            }
        }
        .padding(DSSpacing.md)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(Color.dcStroke, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var formattedElapsedTime: String {
        if let telemetry = engine.activeTelemetry, engine.state == .sprinting {
            return String(format: "%.2f", telemetry.currentElapsedTime)
        } else if let record = engine.lastRecord, let t = record.time0To60 {
            return String(format: "%.2f", t)
        } else {
            return "0.00"
        }
    }

    private var statusColor: Color {
        switch engine.state {
        case .idle: return Color.dcTextSecondary
        case .staged: return Color.dcWarning
        case .sprinting: return Color.dcAccent
        case .completed: return Color.dcPro
        case .aborted: return Color.dcDanger
        }
    }

    private var currentSpeed: Double {
        if let telemetry = engine.activeTelemetry {
            return useMilesPerHour ? telemetry.currentSpeedMph : telemetry.currentSpeedKmh
        }
        return 0.0
    }

    private var speedUnitLabel: String {
        useMilesPerHour ? "mph" : "km/h"
    }

    private var peakLongitudinalG: Double {
        if let telemetry = engine.activeTelemetry {
            return telemetry.peakLongitudinalG
        } else if let record = engine.lastRecord {
            return record.peakLongitudinalG
        }
        return 0.0
    }

    private var currentDistance: Double {
        engine.activeTelemetry?.currentDistanceMeters ?? 0.0
    }

    private var split0To30: Double? {
        engine.activeTelemetry?.time0To30 ?? engine.lastRecord?.time0To30
    }

    private var split0To60: Double? {
        engine.activeTelemetry?.time0To60 ?? engine.lastRecord?.time0To60
    }

    private var split0To100Kmh: Double? {
        engine.activeTelemetry?.time0To100Kmh ?? engine.lastRecord?.time0To100Kmh
    }

    private var splitQuarterMile: Double? {
        engine.activeTelemetry?.timeQuarterMile ?? engine.lastRecord?.timeQuarterMile
    }

    private var trapSpeedQuarterMile: String? {
        if let s = engine.activeTelemetry?.speedQuarterMileMph ?? engine.lastRecord?.speedQuarterMileMph {
            return String(format: "Trap: %.1f mph", s)
        }
        return nil
    }
}
