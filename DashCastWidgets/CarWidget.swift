import AppIntents
import SwiftUI
import UIKit
import WidgetKit

struct CarWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "My Car"
    static var description = IntentDescription("Your car, its name and licence plate.")

    @Parameter(title: "Show licence plate", default: true)
    var showPlate: Bool
}

struct CarProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SharedEntry { .preview }

    func snapshot(for configuration: CarWidgetIntent, in context: Context) async -> SharedEntry {
        entry(configuration)
    }

    func timeline(for configuration: CarWidgetIntent, in context: Context) async -> Timeline<SharedEntry> {
        // The app pushes reloads whenever the car changes; no polling needed.
        Timeline(entries: [entry(configuration)], policy: .never)
    }

    private func entry(_ configuration: CarWidgetIntent) -> SharedEntry {
        SharedEntry(date: Date(), payload: WidgetSharedStore.shared.load(), showPlate: configuration.showPlate)
    }
}

struct CarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DashCastCarWidget", intent: CarWidgetIntent.self, provider: CarProvider()) { entry in
            CarWidgetView(entry: entry)
                .containerBackground(WidgetPalette.backdrop, for: .widget)
                .widgetURL(DashCastLinks.widgets)
        }
        .configurationDisplayName("My Car")
        .description("Your car photo, name and plate.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PlateBadge: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .kerning(1.2)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(WidgetPalette.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(WidgetPalette.ink.opacity(0.6), lineWidth: 1))
    }
}

struct CarArtwork: View {
    let car: SharedCarSnapshot
    var body: some View {
        if let data = car.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle().fill(WidgetPalette.color(hex: car.accentHex).opacity(0.18))
                Image(systemName: "car.side.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(WidgetPalette.color(hex: car.accentHex))
            }
        }
    }
}

struct CarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SharedEntry

    private var car: SharedCarSnapshot { entry.payload.car ?? .placeholder }
    private var plate: String? {
        guard entry.showPlate, let p = car.plate?.trimmingCharacters(in: .whitespaces), !p.isEmpty else { return nil }
        return p
    }

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            CarArtwork(car: car)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Spacer(minLength: 0)
            Text(car.name)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("\(car.brand) \(car.model)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
            if let plate { PlateBadge(text: plate) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            CarArtwork(car: car)
                .frame(width: 120)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(car.brand.uppercased())
                    .font(.caption2.weight(.semibold))
                    .kerning(1.5)
                    .foregroundStyle(WidgetPalette.color(hex: car.accentHex))
                Text(car.model)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(car.name)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let plate { PlateBadge(text: plate) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
