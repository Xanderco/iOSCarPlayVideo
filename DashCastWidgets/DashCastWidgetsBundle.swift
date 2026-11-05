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

    static func color(hex: String?) -> Color {
        guard var h = hex?.trimmingCharacters(in: .whitespaces), !h.isEmpty else { return signal }
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return signal }
        let c = Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                      blue: Double(v & 0xFF) / 255)
        // White is the app default text colour; use the brand accent instead on widgets.
        return v == 0xFFFFFF ? signal : c
    }
}
