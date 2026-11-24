import SwiftUI

/// Glanceable drag-strip performance gauge view for in-cockpit HUD and CarPlay displays.
public struct VirtualDynoGaugeView: View {
    @ObservedObject public var engine: VirtualDynoEngine = .shared
    public var useMilesPerHour: Bool = true
    public var onTapDetails: (() -> Void)?

    public init(
        engine: VirtualDynoEngine = .shared,
        useMilesPerHour: Bool = true,
        onTapDetails: (() -> Void)? = nil
    ) {
        self.engine = engine
        self.useMilesPerHour = useMilesPerHour
        self.onTapDetails = onTapDetails
    }

    public var body: some View {
        Button(action: {
            onTapDetails?()
        }) {
            HStack(spacing: DSSpacing.md) {
                // Drag Strip Tree Indicator
                treeStageIndicator

                // Time readout
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DSSpacing.xs) {
                        Text(statusTitle)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(statusColor)
                            .textCase(.uppercase)

                        if engine.state == .sprinting {
                            Circle()
                                .fill(Color.dcLive)
                                .frame(width: 6, height: 6)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: DSSpacing.xs) {
                        Text(formattedTime)
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color.dcTextPrimary)

                        Text("0-60")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.dcTextTertiary)
                    }
                }

                Spacer()

                // Peak G & PB Badge
                VStack(alignment: .trailing, spacing: 2) {
                    if let pb = engine.personalBest0To60?.time0To60 {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color.dcPro)
                            Text(String(format: "%.2fs", pb))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.dcPro)
                        }
                    } else {
                        Text("VIRTUAL DYNO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.dcTextTertiary)
                    }

                    if let telemetry = engine.activeTelemetry, engine.state == .sprinting {
                        Text(String(format: "+%.2f G", telemetry.peakLongitudinalG))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.dcAccent)
                    } else if let last = engine.lastRecord {
                        Text(String(format: "+%.2f G", last.peakLongitudinalG))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.dcTextSecondary)
                    } else {
                        Text("Auto-Arm: ON")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.dcTextTertiary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.dcTextTertiary)
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .background(Color.dcSurface)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(borderHighlightColor, lineWidth: borderHighlightWidth)
            )
        }
        .buttonStyle(.plain)
    }

    private var treeStageIndicator: some View {
        VStack(spacing: 3) {
            // Pre-stage / Staged Amber Light
            Circle()
                .fill(engine.state == .staged || engine.state == .sprinting ? Color.dcWarning : Color.dcSurfaceRaised)
                .frame(width: 8, height: 8)

            // Green Launch Light
            Circle()
                .fill(engine.state == .sprinting ? Color.dcAccent : Color.dcSurfaceRaised)
                .frame(width: 8, height: 8)

            // Finished White/Blue Light
            Circle()
                .fill(engine.state == .completed ? Color.dcPro : Color.dcSurfaceRaised)
                .frame(width: 8, height: 8)
        }
        .padding(4)
        .background(Color.dcBackground)
        .clipShape(Capsule())
    }

    private var statusTitle: String {
        switch engine.state {
        case .idle: return "Standby"
        case .staged: return "Staged & Ready"
        case .sprinting: return "Sprinting"
        case .completed: return "Run Finished"
        case .aborted: return "Run Aborted"
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

    private var formattedTime: String {
        if let telemetry = engine.activeTelemetry, engine.state == .sprinting {
            return String(format: "%.2f", telemetry.currentElapsedTime)
        } else if let record = engine.lastRecord, let t = record.time0To60 {
            return String(format: "%.2f", t)
        } else {
            return "0.00"
        }
    }

    private var borderHighlightColor: Color {
        switch engine.state {
        case .staged: return Color.dcWarning.opacity(0.8)
        case .sprinting: return Color.dcAccent
        case .completed: return Color.dcPro.opacity(0.8)
        default: return Color.dcStroke
        }
    }

    private var borderHighlightWidth: CGFloat {
        (engine.state == .staged || engine.state == .sprinting || engine.state == .completed) ? 1.5 : 1.0
    }
}
