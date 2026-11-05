import SwiftUI
import WidgetKit

struct QuickCastEntry: TimelineEntry {
    let date: Date
}

struct QuickCastProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickCastEntry { QuickCastEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (QuickCastEntry) -> Void) {
        completion(QuickCastEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCastEntry>) -> Void) {
        completion(Timeline(entries: [QuickCastEntry(date: Date())], policy: .never))
    }
}

/// One tap to open DashCast's Cast tab (dashcast://cast). Home Screen + Lock Screen.
struct QuickCastWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DashCastQuickCastWidget", provider: QuickCastProvider()) { _ in
            QuickCastView()
                .containerBackground(for: .widget) {
                    QuickCastBackground()
                }
                .widgetURL(DashCastLinks.cast)
        }
        .configurationDisplayName("Quick Cast")
        .description("Jump straight to casting to your car.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct QuickCastBackground: View {
    @Environment(\.widgetFamily) private var family
    var body: some View {
        if family == .systemSmall {
            WidgetPalette.backdrop
        } else {
            AccessoryWidgetBackground()
        }
    }
}

struct QuickCastView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "dot.radiowaves.right")
                .font(.system(size: 22, weight: .semibold))
                .widgetAccentable()
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.right").widgetAccentable()
                VStack(alignment: .leading, spacing: 0) {
                    Text("DashCast").font(.headline)
                    Text("Tap to cast").font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Label("Cast to car", systemImage: "dot.radiowaves.right")
        default:
            VStack(alignment: .leading) {
                ZStack {
                    Circle().fill(WidgetPalette.signal)
                    Image(systemName: "dot.radiowaves.right")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(WidgetPalette.ink)
                }
                .frame(width: 48, height: 48)
                Spacer(minLength: 0)
                Text("Cast")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                Text("Send video to your car")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
