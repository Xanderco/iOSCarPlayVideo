import AppIntents
import SwiftUI
import WidgetKit

enum TripUnitOption: String, AppEnum {
    case app, kilometres, miles

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Units"
    static var caseDisplayRepresentations: [TripUnitOption: DisplayRepresentation] = [
        .app: "Same as app",
        .kilometres: "Kilometres",
        .miles: "Miles"
    ]
}

struct TripStatsIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Last Trip"
    static var description = IntentDescription("Distance, score and date of your latest drive.")

    @Parameter(title: "Units", default: .app)
    var units: TripUnitOption
}

struct TripProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SharedEntry { .preview }

    func snapshot(for configuration: TripStatsIntent, in context: Context) async -> SharedEntry {
        context.isPreview ? .preview : entry(configuration)
    }

    func timeline(for configuration: TripStatsIntent, in context: Context) async -> Timeline<SharedEntry> {
        // Refresh hourly so the relative date ("2 h ago") stays honest.
        Timeline(entries: [entry(configuration)], policy: .after(Date().addingTimeInterval(3600)))
    }

    private func entry(_ configuration: TripStatsIntent) -> SharedEntry {
        let forced: Bool?
        switch configuration.units {
        case .app: forced = nil
        case .kilometres: forced = false
        case .miles: forced = true
        }
        return SharedEntry(date: Date(), payload: WidgetSharedStore.shared.load(), forceMiles: forced)
    }
}

struct TripStatsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DashCastTripStatsWidget", intent: TripStatsIntent.self, provider: TripProvider()) { entry in
            TripStatsView(entry: entry)
                .containerBackground(WidgetPalette.backdrop, for: .widget)
                .widgetURL(DashCastLinks.drive)
        }
        .configurationDisplayName("Last Trip")
        .description("Distance, driving score and when you drove.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ScoreRing: View {
    let score: Int
    var body: some View {
        let tint = score >= 80 ? WidgetPalette.signal : WidgetPalette.amber
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(score, 100))) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
        }
    }
}

struct TripStatsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SharedEntry

    private var miles: Bool { entry.forceMiles ?? entry.payload.usesMiles }

    private func distance(_ trip: SharedTripSnapshot) -> String {
        let value = miles ? trip.distanceMiles : trip.distanceKm
        return String(format: value < 10 ? "%.1f" : "%.0f", value)
    }

    var body: some View {
        if let trip = entry.payload.lastTrip {
            if family == .systemMedium { medium(trip) } else { small(trip) }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "road.lanes")
                    .font(.title2)
                    .foregroundStyle(WidgetPalette.signal)
                Text("No trips yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Start a drive in DashCast")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func header(_ trip: SharedTripSnapshot) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.checkered")
            Text(trip.date, style: .relative)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.6))
        .lineLimit(1)
    }

    private func small(_ trip: SharedTripSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header(trip)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(distance(trip))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(miles ? "mi" : "km")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetPalette.signal)
            }
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                Text("Score \(trip.score)")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(trip.score >= 80 ? WidgetPalette.signal : WidgetPalette.amber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func medium(_ trip: SharedTripSnapshot) -> some View {
        HStack(spacing: 16) {
            ScoreRing(score: trip.score).frame(width: 74, height: 74)
            VStack(alignment: .leading, spacing: 6) {
                header(trip)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(distance(trip))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(miles ? "mi" : "km")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WidgetPalette.signal)
                }
                Label(Duration.seconds(trip.durationSeconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)),
                      systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text(trip.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
