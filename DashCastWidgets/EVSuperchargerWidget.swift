import SwiftUI
import WidgetKit

struct EVSuperchargerEntry: TimelineEntry {
    let date: Date
    let payload: WidgetSharedPayload
}

struct EVSuperchargerProvider: TimelineProvider {
    func placeholder(in context: Context) -> EVSuperchargerEntry {
        EVSuperchargerEntry(date: Date(), payload: WidgetSharedPayload(evSession: .placeholder))
    }

    func getSnapshot(in context: Context, completion: @escaping (EVSuperchargerEntry) -> Void) {
        let payload = WidgetSharedStore.shared.load()
        completion(EVSuperchargerEntry(date: Date(), payload: payload.evSession != nil ? payload : WidgetSharedPayload(evSession: .placeholder)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EVSuperchargerEntry>) -> Void) {
        let payload = WidgetSharedStore.shared.load()
        let entry = EVSuperchargerEntry(date: Date(), payload: payload.evSession != nil ? payload : WidgetSharedPayload(evSession: .placeholder))
        // Refresh every 5 minutes during charging
        let nextUpdate = Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

/// EV Supercharger Session Monitor & Road Trip Rest Stop Countdown Widget.
/// Home Screen + Lock Screen + CarPlay companion with quick-switch to parked video streaming.
struct EVSuperchargerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DashCastEVSuperchargerWidget", provider: EVSuperchargerProvider()) { entry in
            EVSuperchargerWidgetView(entry: entry)
                .containerBackground(WidgetPalette.backdrop, for: .widget)
                .widgetURL(DashCastLinks.cast)
        }
        .configurationDisplayName("Supercharger & Rest Stop")
        .description("Track fast charging progress, rest stop countdowns, and quick-switch to parked video.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct EVSuperchargerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: EVSuperchargerEntry

    private var session: SharedEVChargingSnapshot {
        entry.payload.evSession ?? .placeholder
    }

    private var presetColor: Color {
        switch session.stationPresetRaw {
        case "teslaSupercharger": return Color(red: 0.91, green: 0.13, blue: 0.15)
        case "electrifyAmerica": return Color(red: 0.0, green: 0.69, blue: 0.25)
        case "evgo": return Color(red: 0.0, green: 0.34, blue: 0.72)
        default: return Color(red: 1.0, green: 0.72, blue: 0.25)
        }
    }

    private var stationIcon: String {
        switch session.stationPresetRaw {
        case "teslaSupercharger": return "bolt.car.fill"
        case "electrifyAmerica": return "bolt.batteryblock.fill"
        case "evgo": return "powerplug.fill"
        default: return "cup.and.saucer.fill"
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Small Layout

    private var smallView: some View {
        GlanceReader { ctx in
            VStack(alignment: .leading, spacing: 4) {
                // Header badge
                HStack(spacing: 5) {
                    Image(systemName: stationIcon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ctx.isFullColor ? presetColor : .primary)
                    Text(session.stationName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(ctx.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Battery / Countdown circular progress
                HStack {
                    Spacer(minLength: 0)
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 7)

                        let progress = session.isRestArea ? 0.65 : CGFloat(session.currentBattery) / 100.0
                        Circle()
                            .trim(from: 0, to: min(1.0, max(0.05, progress)))
                            .stroke(ctx.isFullColor ? presetColor : .primary, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            if session.isRestArea {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(presetColor)
                                Text("REST")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundStyle(ctx.primary)
                            } else {
                                Text("\(session.currentBattery)%")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundStyle(ctx.primary)
                                if session.powerKw > 0 {
                                    Text("\(Int(session.powerKw))kW")
                                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                                        .foregroundStyle(ctx.secondary)
                                }
                            }
                        }
                    }
                    .frame(width: 66, height: 66)
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                // Footer: Target or Quick-Stream action
                HStack {
                    if session.isRestArea {
                        Text("Break: \(session.restStopDurationMinutes)m")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(ctx.secondary)
                    } else {
                        Text("Target: \(session.targetBattery)%")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(ctx.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.902, blue: 0.0))
                }
            }
        }
    }

    // MARK: - Medium Layout

    private var mediumView: some View {
        GlanceReader { ctx in
            HStack(spacing: 16) {
                // Left Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 9)

                    let progress = session.isRestArea ? 0.65 : CGFloat(session.currentBattery) / 100.0
                    Circle()
                        .trim(from: 0, to: min(1.0, max(0.05, progress)))
                        .stroke(ctx.isFullColor ? presetColor : .primary, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 1) {
                        Image(systemName: stationIcon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ctx.isFullColor ? presetColor : .primary)
                        if session.isRestArea {
                            Text("REST")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(ctx.primary)
                        } else {
                            Text("\(session.currentBattery)%")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundStyle(ctx.primary)
                        }
                    }
                }
                .frame(width: 94, height: 94)

                // Right Info Panel
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(session.stationName)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(ctx.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if session.powerKw > 0 {
                            Text("\(Int(session.powerKw)) kW")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(presetColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(presetColor.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }

                    if session.isRestArea {
                        Text("Road trip rest break · \(session.restStopDurationMinutes) min countdown")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(ctx.secondary)
                            .lineLimit(1)
                    } else {
                        // Progress bar from current to target
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Charging to \(session.targetBattery)%")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(ctx.secondary)
                                Spacer()
                                if let targetTime = session.targetCompletionTime {
                                    Text(targetTime, style: .timer)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(presetColor)
                                }
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.15))
                                    Capsule()
                                        .fill(presetColor)
                                        .frame(width: geo.size.width * CGFloat(min(1.0, max(0.05, Double(session.currentBattery) / 100.0))))
                                }
                            }
                            .frame(height: 6)
                        }
                    }

                    Spacer(minLength: 0)

                    // Quick-Switch to Parked Video Streaming
                    HStack(spacing: 6) {
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.902, blue: 0.0))
                        Text("Stream Video While Parked ↗")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.902, blue: 0.0))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Lock Screen Accessories

    private var accessoryCircularView: some View {
        Gauge(value: Double(session.currentBattery), in: 0...100) {
            Image(systemName: stationIcon)
        } currentValueLabel: {
            Text("\(session.currentBattery)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: stationIcon).widgetAccentable()
                Text(session.stationName)
                    .font(.headline)
                    .lineLimit(1)
            }
            if session.isRestArea {
                Text("Rest Break · \(session.restStopDurationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Battery: \(session.currentBattery)% → \(session.targetBattery)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
