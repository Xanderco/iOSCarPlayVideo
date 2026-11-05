import SwiftUI
import UIKit
import WidgetKit

struct DoodleProvider: TimelineProvider {
    func placeholder(in context: Context) -> SharedEntry { .preview }
    func getSnapshot(in context: Context, completion: @escaping (SharedEntry) -> Void) {
        completion(SharedEntry(date: Date(), payload: WidgetSharedStore.shared.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SharedEntry>) -> Void) {
        // The app reloads timelines when the user saves a new photo/doodle.
        completion(Timeline(entries: [SharedEntry(date: Date(), payload: WidgetSharedStore.shared.load())], policy: .never))
    }
}

/// "Photo / Doodle": a picture or a sketch the user made in DashCast. Small only, CarPlay-eligible.
struct DoodleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DashCastDoodleWidget", provider: DoodleProvider()) { entry in
            DoodleWidgetView(doodle: entry.payload.doodle)
                .containerBackground(for: .widget) {
                    DoodleBackground(doodle: entry.payload.doodle)
                }
        }
        .configurationDisplayName("Photo / Doodle")
        .description("A photo or a doodle you drew in DashCast.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

private struct DoodleBackground: View {
    let doodle: SharedDoodle?
    var body: some View {
        if let doodle, doodle.kind == .photo, let image = UIImage(data: doodle.imageData) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            // Doodles sit on a soft "paper" card so dark strokes stay visible.
            LinearGradient(colors: [Color(red: 0.97, green: 0.96, blue: 0.92), Color(red: 0.90, green: 0.93, blue: 0.95)],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

struct DoodleWidgetView: View {
    let doodle: SharedDoodle?

    var body: some View {
        GlanceReader { ctx in
            ZStack(alignment: .bottomLeading) {
                if let doodle {
                    if doodle.kind == .doodle, let image = UIImage(data: doodle.imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    if let caption = doodle.caption?.trimmingCharacters(in: .whitespacesAndNewlines), !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.black.opacity(0.55)))
                            .padding(10)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "scribble.variable")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(ctx.isFullColor ? WidgetPalette.deep : ctx.primary)
                            .widgetAccentable()
                        Spacer(minLength: 0)
                        Text("Draw or pick a photo")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(ctx.isFullColor ? WidgetPalette.ink : ctx.primary)
                        Text("Open DashCast to set up")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(ctx.isFullColor ? WidgetPalette.ink.opacity(0.6) : ctx.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
        }
    }
}
