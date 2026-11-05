import Foundation
import UIKit
import WidgetKit

/// App-side bridge: mirrors the user's widget config and latest trip into the app group
/// and asks WidgetKit to refresh Home/Lock Screen widgets.
enum WidgetSharedPublisher {
    static func snapshot(from config: WidgetConfigModel) -> SharedCarSnapshot {
        let greeting = config.driverGreeting.trimmingCharacters(in: .whitespacesAndNewlines)
        return SharedCarSnapshot(
            name: greeting.isEmpty ? config.carModelName : greeting,
            brand: config.carBrand,
            model: config.carModelName,
            plate: config.plateText,
            photoData: config.customPhotoData.flatMap { thumbnail(from: $0) },
            accentHex: config.textColorHex)
    }

    static func snapshot(from trip: TripModel) -> SharedTripSnapshot {
        SharedTripSnapshot(distanceMeters: trip.distanceMeters, score: trip.drivingScore,
                           date: trip.endTime ?? trip.startTime, durationSeconds: trip.durationSeconds)
    }

    static func publishWidgets(_ widgets: [WidgetConfigModel], store: WidgetSharedStore = .shared) {
        let car = widgets.first.map(snapshot(from:))
        store.update { $0.car = car }
        reload()
    }

    static func publishTrips(_ trips: [TripModel], store: WidgetSharedStore = .shared) {
        let latest = trips.max { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) }
        let miles = UserDefaults.standard.bool(forKey: "useMilesPerHour")
        store.update {
            $0.lastTrip = latest.map(snapshot(from:))
            $0.usesMiles = miles
        }
        reload()
    }

    static func publishDoodle(_ doodle: SharedDoodle?, store: WidgetSharedStore = .shared) {
        store.update { $0.doodle = doodle }
        reload()
    }

    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Widgets have a tight memory budget; keep shared photos ~320px JPEG.
    static func thumbnail(from data: Data, maxSide: CGFloat = 320) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.75)
    }
}
