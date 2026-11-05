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
            // Small layout doubles as the CarPlay widget: a single big target.
            GlanceReader { ctx in
                VStack(alignment: .leading, spacing: 2) {
                    ZStack {
                        Circle()
                            .fill(ctx.isFullColor ? WidgetPalette.signal : Color.primary.opacity(0.2))
                        Image(systemName: "dot.radiowaves.right")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(ctx.isFullColor ? WidgetPalette.ink : Color.primary)
                            .widgetAccentable()
                    }
                    .frame(width: 56, height: 56)
                    Spacer(minLength: 0)
                    Text("Cast")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(ctx.primary)
                    Text("Video to your car")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(ctx.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }
}
