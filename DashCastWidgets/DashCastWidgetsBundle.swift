import SwiftUI
import WidgetKit

@main
struct DashCastWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CarWidget()
        TripStatsWidget()
        QuickCastWidget()
    }
}

// MARK: - Shared timeline

struct SharedEntry: TimelineEntry {
    let date: Date
    let payload: WidgetSharedPayload
    var showPlate: Bool = true
    var forceMiles: Bool? = nil

    static let preview = SharedEntry(
        date: Date(),
        payload: WidgetSharedPayload(car: .placeholder, lastTrip: .placeholder))
}

enum WidgetPalette {
    static let ink = Color(red: 0.05, green: 0.07, blue: 0.11)
    static let deep = Color(red: 0.08, green: 0.13, blue: 0.22)
    static let signal = Color(red: 0.25, green: 0.85, blue: 0.75)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.25)

    static var backdrop: LinearGradient {
        LinearGradient(colors: [deep, ink], startPoint: .topTrailing, endPoint: .bottomLeading)
    }

    /// Accent colour guaranteed to be readable on the dark backdrop (also on a car display).
    static func color(hex: String?) -> Color {
        let safe = WidgetColorMath.readableAccentHex(hex)
        guard let c = WidgetColorMath.components(hex: safe) else { return signal }
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}
}

/// CarPlay (iOS 26) shows `.systemSmall` widgets on the car display. There is no CarPlay-specific
/// environment value, so small layouts are written to work in every rendering context:
/// - `widgetRenderingMode`: in `.accented`/`.vibrant` the system tints content, so meaning never
///   depends on colour alone and key glyphs are marked `widgetAccentable()`.
/// - `showsWidgetContainerBackground`: when the system removes our backdrop we drop decorative fills.
/// - Large, heavy, rounded type with high-contrast white on the dark backdrop for glanceability.
/// Do NOT add `.disfavoredLocations([.carPlay], for: [.systemSmall])` — that would hide these from CarPlay.
struct GlanceContext {
    let renderingMode: WidgetRenderingMode
    let showsBackground: Bool

    var isFullColor: Bool { renderingMode == .fullColor }
    /// Primary text: pure white in full colour; system-styled otherwise.
    var primary: Color { isFullColor ? .white : .primary }
    var secondary: Color { isFullColor ? .white.opacity(0.78) : .secondary }
}

struct GlanceReader<Content: View>: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    @ViewBuilder let content: (GlanceContext) -> Content

    var body: some View {
        content(GlanceContext(renderingMode: renderingMode, showsBackground: showsBackground))
    }
}
