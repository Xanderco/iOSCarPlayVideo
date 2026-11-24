import WidgetKit
import SwiftUI
import ActivityKit

@main
struct DashCastCastWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarCastLiveActivityWidget()
        EVChargingLiveActivityWidget()
    }
}

private let castYellow = Color(red: 1.0, green: 0.902, blue: 0.0)

// MARK: - Car Cast Live Activity

struct CarCastLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CarCastActivityAttributes.self) { context in
            CarCastLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(castYellow)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: icon(for: context.state))
                        .font(.title2)
                        .foregroundStyle(context.state.isPausedForMotion ? Color.orange : castYellow)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 70)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } compactLeading: {
                Image(systemName: icon(for: context.state))
                    .foregroundStyle(context.state.isPausedForMotion ? Color.orange : castYellow)
            } compactTrailing: {
                Text(context.state.mode)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: icon(for: context.state))
                    .foregroundStyle(castYellow)
            }
        }
    }
}

private func icon(for state: CarCastActivityAttributes.ContentState) -> String {
    if state.isPausedForMotion { return "pause.circle.fill" }
    return state.mode == "Mirroring" ? "rectangle.on.rectangle" : "airplayvideo"
}

struct CarCastLockScreenView: View {
    let state: CarCastActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon(for: state))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(state.isPausedForMotion ? Color.orange : castYellow)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("DashCast · \(state.mode)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(castYellow)
                Text(state.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(state.detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Text(state.startedAt, style: .timer)
                .font(.system(.subheadline, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 70)
        }
        .padding(16)
    }
}

// MARK: - EV Charging & Supercharger Live Activity

struct EVChargingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EVChargingActivityAttributes.self) { context in
            EVChargingLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.90))
                .activitySystemActionForegroundColor(stationColor(for: context.state))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: stationGlyph(for: context.state))
                            .font(.title2)
                            .foregroundStyle(stationColor(for: context.state))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.stationName)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                            if context.state.powerKw > 0 {
                                Text("\(Int(context.state.powerKw)) kW")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(context.state.estimatedCompletionTime, style: .timer)
                            .font(.system(.body, design: .rounded).monospacedDigit().weight(.bold))
                            .foregroundStyle(stationColor(for: context.state))
                            .multilineTextAlignment(.trailing)
                        Text(context.state.isRestArea ? "Break" : "Target \(context.state.targetBattery)%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if context.state.isRestArea {
                        Text("Rest Stop Countdown")
                            .font(.subheadline.weight(.semibold))
                    } else {
                        VStack(spacing: 3) {
                            HStack {
                                Text("\(context.state.currentBattery)%")
                                    .font(.headline.weight(.heavy).monospacedDigit())
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(context.state.targetBattery)%")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(context.state.currentBattery), total: 100.0)
                                .tint(stationColor(for: context.state))
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Link(destination: URL(string: "dashcast://cast")!) {
                            HStack(spacing: 5) {
                                Image(systemName: "play.tv.fill")
                                    .font(.caption.weight(.bold))
                                Text("Watch Video While Parked")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(castYellow)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        Spacer()
                        Text(context.state.statusText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: stationGlyph(for: context.state))
                    .foregroundStyle(stationColor(for: context.state))
            } compactTrailing: {
                if context.state.isRestArea {
                    Text(context.state.estimatedCompletionTime, style: .timer)
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(stationColor(for: context.state))
                        .frame(maxWidth: 48)
                } else {
                    Text("\(context.state.currentBattery)%")
                        .font(.caption2.weight(.heavy).monospacedDigit())
                        .foregroundStyle(stationColor(for: context.state))
                }
            } minimal: {
                Image(systemName: stationGlyph(for: context.state))
                    .foregroundStyle(stationColor(for: context.state))
            }
        }
    }
}

private func stationColor(for state: EVChargingActivityAttributes.ContentState) -> Color {
    switch state.stationPresetRaw {
    case "teslaSupercharger": return Color(red: 0.91, green: 0.13, blue: 0.15)
    case "electrifyAmerica": return Color(red: 0.0, green: 0.69, blue: 0.25)
    case "evgo": return Color(red: 0.0, green: 0.34, blue: 0.72)
    default: return Color(red: 1.0, green: 0.72, blue: 0.25)
    }
}

private func stationGlyph(for state: EVChargingActivityAttributes.ContentState) -> String {
    switch state.stationPresetRaw {
    case "teslaSupercharger": return "bolt.car.fill"
    case "electrifyAmerica": return "bolt.batteryblock.fill"
    case "evgo": return "powerplug.fill"
    default: return "cup.and.saucer.fill"
    }
}

struct EVChargingLockScreenView: View {
    let state: EVChargingActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: stationGlyph(for: state))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(stationColor(for: state))
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(state.stationName)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.white)
                        if state.powerKw > 0 {
                            Text("\(Int(state.powerKw)) kW")
                                .font(.caption2.monospaced().weight(.bold))
                                .foregroundStyle(stationColor(for: state))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(stationColor(for: state).opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    if state.isRestArea {
                        Text("Rest break in progress")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("Charging \(state.currentBattery)% → \(state.targetBattery)%")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(state.estimatedCompletionTime, style: .timer)
                        .font(.system(.headline, design: .rounded).monospacedDigit().weight(.bold))
                        .foregroundStyle(stationColor(for: state))
                    Text(state.isRestArea ? "Remaining" : "Target Est.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            // Quick deep-link switch to parked video streaming
            HStack {
                Link(destination: URL(string: "dashcast://cast")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.tv.fill")
                            .font(.caption.weight(.bold))
                        Text("Stream Video to Car While Parked")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.902, blue: 0.0))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                Spacer()
                Text(state.statusText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(14)
    }
}
