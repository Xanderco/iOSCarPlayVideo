import Foundation
import SwiftUI
import UIKit
import CoreGraphics

/// Off-screen high-resolution 1080x1920 graphic card rendering engine for social media export.
@MainActor
public final class DriveSummaryCardRendererService: ObservableObject {
    public static let shared = DriveSummaryCardRendererService()

    @Published public private(set) var isRendering: Bool = false
    @Published public private(set) var lastRenderDurationMs: Double = 0

    // In-memory LRU cache for rendered card bitmaps
    private let cache = NSCache<NSString, UIImage>()

    public enum ImageFormat: String {
        case png
        case jpeg
    }

    public enum RenderError: LocalizedError {
        case bitmapGenerationFailed
        case dataConversionFailed
        case invalidTripData

        public var errorDescription: String? {
            switch self {
            case .bitmapGenerationFailed:
                return "Failed to rasterize 1080x1920 card off-screen."
            case .dataConversionFailed:
                return "Failed to convert rendered bitmap to compressed image data."
            case .invalidTripData:
                return "The provided trip contains insufficient telemetry data to render."
            }
        }
    }

    public init() {
        cache.countLimit = 20
    }

    public func clearCache() {
        cache.removeAllObjects()
    }

    /// Renders a high-resolution 1080x1920 UIImage for a given TripModel off-screen.
    public func renderStoryCard(
        from trip: TripModel,
        preferences: UserPreferences = UserPreferences(),
        vehicle: VehicleModel? = nil,
        metrics: SmoothnessMetrics? = nil,
        forceRefresh: Bool = false
    ) async -> UIImage {
        let cacheKey = NSString(string: "\(trip.id.uuidString)-1080x1920")
        if !forceRefresh, let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        isRendering = true
        let startTimestamp = CFAbsoluteTimeGetCurrent()

        let cardData = DriveSummaryCardData(
            trip: trip,
            preferences: preferences,
            vehicle: vehicle,
            metrics: metrics
        )

        let image = await renderOffscreen(data: cardData)

        cache.setObject(image, forKey: cacheKey)
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTimestamp) * 1000.0
        self.lastRenderDurationMs = elapsed
        self.isRendering = false

        return image
    }

    /// Converts the rendered 1080x1920 card directly into PNG or JPEG binary Data for saving or network upload.
    public func renderCardData(
        from trip: TripModel,
        preferences: UserPreferences = UserPreferences(),
        vehicle: VehicleModel? = nil,
        format: ImageFormat = .png,
        compressionQuality: CGFloat = 0.92
    ) async throws -> Data {
        let image = await renderStoryCard(from: trip, preferences: preferences, vehicle: vehicle)

        switch format {
        case .png:
            guard let data = image.pngData() else {
                throw RenderError.dataConversionFailed
            }
            return data
        case .jpeg:
            guard let data = image.jpegData(compressionQuality: compressionQuality) else {
                throw RenderError.dataConversionFailed
            }
            return data
        }
    }

    /// Internal off-screen rasterization using SwiftUI ImageRenderer with CoreGraphics fallback.
    public func renderOffscreen(data: DriveSummaryCardData) async -> UIImage {
        let targetSize = CGSize(width: data.targetWidth, height: data.targetHeight)

        // 1. Primary path: SwiftUI ImageRenderer (iOS 16+)
        let cardView = DriveSummaryStoryCardView(data: data)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(targetSize)

        if let image = renderer.uiImage {
            return image
        }

        // 2. Headless / CoreGraphics Fallback (guarantees non-nil 1080x1920 bitmap in any execution context)
        return renderCoreGraphicsFallback(data: data, targetSize: targetSize)
    }

    /// Deterministic CoreGraphics renderer for headless test runners and background contexts.
    public func renderCoreGraphicsFallback(data: DriveSummaryCardData, targetSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            let bounds = CGRect(origin: .zero, size: targetSize)

            // 1. OLED Black Background (#0C0D10)
            cg.setFillColor(red: 12/255.0, green: 13/255.0, blue: 16/255.0, alpha: 1.0)
            cg.fill(bounds)

            // 2. Ambient Yellow & Tier Glows
            let colors = [
                UIColor(Color.dashYellow).withAlphaComponent(0.12).cgColor,
                UIColor.clear.cgColor
            ] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
                cg.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: targetSize.width / 2, y: targetSize.height * 0.35),
                    startRadius: 50,
                    endCenter: CGPoint(x: targetSize.width / 2, y: targetSize.height * 0.35),
                    endRadius: 400,
                    options: []
                )
            }

            // 3. Grid Lines Overlay
            cg.setStrokeColor(red: 31/255.0, green: 35/255.0, blue: 46/255.0, alpha: 0.3)
            cg.setLineWidth(1.0)
            for x in stride(from: CGFloat(0), through: targetSize.width, by: 80) {
                cg.move(to: CGPoint(x: x, y: 0))
                cg.addLine(to: CGPoint(x: x, y: targetSize.height))
            }
            for y in stride(from: CGFloat(0), through: targetSize.height, by: 80) {
                cg.move(to: CGPoint(x: 0, y: y))
                cg.addLine(to: CGPoint(x: targetSize.width, y: y))
            }
            cg.strokePath()

            // 4. Header Text
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .black),
                .foregroundColor: UIColor.white
            ]
            let subAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold),
                .foregroundColor: UIColor(Color.dashYellow)
            ]
            let tagAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor(red: 142/255.0, green: 146/255.0, blue: 160/255.0, alpha: 1.0)
            ]

            "DASHCAST".draw(at: CGPoint(x: 60, y: 64), withAttributes: titleAttributes)
            "IN-CAR TELEMETRY // 9:16 STORY".draw(at: CGPoint(x: 60, y: 104), withAttributes: subAttributes)
            data.formattedDate.draw(at: CGPoint(x: targetSize.width - 280, y: 70), withAttributes: tagAttributes)

            // 5. Vehicle Showcase Banner Box
            let vehicleBox = CGRect(x: 60, y: 160, width: targetSize.width - 120, height: 110)
            cg.setFillColor(red: 23/255.0, green: 25/255.0, blue: 32/255.0, alpha: 0.9)
            cg.fill(vehicleBox)
            cg.setStrokeColor(red: 45/255.0, green: 50/255.0, blue: 64/255.0, alpha: 1.0)
            cg.setLineWidth(2.0)
            cg.stroke(vehicleBox)

            let brandAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor(Color.dashYellow)
            ]
            let modelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            data.vehicleBrand.draw(at: CGPoint(x: 90, y: 180), withAttributes: brandAttributes)
            data.vehicleName.draw(at: CGPoint(x: 90, y: 210), withAttributes: modelAttributes)

            // 6. Score Ring Centerpiece
            let center = CGPoint(x: targetSize.width / 2, y: 520)
            let radius: CGFloat = 130

            // Background ring
            cg.setStrokeColor(red: 34/255.0, green: 37/255.0, blue: 48/255.0, alpha: 1.0)
            cg.setLineWidth(16.0)
            cg.addArc(center: center, radius: radius, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: false)
            cg.strokePath()

            // Progress arc
            let scoreProgress = CGFloat(data.drivingScore) / 100.0
            cg.setStrokeColor(UIColor(Color.dashYellow).cgColor)
            cg.setLineWidth(16.0)
            cg.setLineCap(.round)
            cg.addArc(
                center: center,
                radius: radius,
                startAngle: -CGFloat.pi / 2,
                endAngle: -CGFloat.pi / 2 + (CGFloat.pi * 2 * scoreProgress),
                clockwise: false
            )
            cg.strokePath()

            // Score Digits
            let scoreAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 96, weight: .black),
                .foregroundColor: UIColor.white
            ]
            let scoreString = "\(data.drivingScore)" as NSString
            let scoreSize = scoreString.size(withAttributes: scoreAttributes)
            scoreString.draw(at: CGPoint(x: center.x - (scoreSize.width / 2), y: center.y - 70), withAttributes: scoreAttributes)

            // Badge Title
            let badgeAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .black),
                .foregroundColor: UIColor(Color.dashYellow)
            ]
            let badgeString = data.badgeTier.title as NSString
            let badgeSize = badgeString.size(withAttributes: badgeAttributes)
            badgeString.draw(at: CGPoint(x: center.x - (badgeSize.width / 2), y: center.y + 170), withAttributes: badgeAttributes)

            // 7. Telemetry Matrix Grid (4 Boxes)
            let gridY: CGFloat = 780
            let colW: CGFloat = (targetSize.width - 150) / 2
            let rowH: CGFloat = 120

            drawStatBox(cg: cg, rect: CGRect(x: 60, y: gridY, width: colW, height: rowH), title: "TOP SPEED", value: data.formattedTopSpeed)
            drawStatBox(cg: cg, rect: CGRect(x: 90 + colW, y: gridY, width: colW, height: rowH), title: "AVG SPEED", value: data.formattedAverageSpeed)
            drawStatBox(cg: cg, rect: CGRect(x: 60, y: gridY + rowH + 20, width: colW, height: rowH), title: "DISTANCE", value: data.formattedDistance)
            drawStatBox(cg: cg, rect: CGRect(x: 90 + colW, y: gridY + rowH + 20, width: colW, height: rowH), title: "DURATION", value: data.formattedDuration)

            // 8. G-Force Dynamics Box
            let gBox = CGRect(x: 60, y: 1080, width: targetSize.width - 120, height: 110)
            cg.setFillColor(red: 23/255.0, green: 25/255.0, blue: 32/255.0, alpha: 0.9)
            cg.fill(gBox)
            cg.setStrokeColor(red: 45/255.0, green: 50/255.0, blue: 64/255.0, alpha: 1.0)
            cg.stroke(gBox)

            "G-FORCE DYNAMICS".draw(at: CGPoint(x: 80, y: 1100), withAttributes: subAttributes)
            "PEAK COMBINED: \(data.formattedPeakG)".draw(at: CGPoint(x: 80, y: 1130), withAttributes: titleAttributes)
            "LATERAL: \(data.formattedLateralG)  •  LONGITUDINAL: \(data.formattedLongitudinalG)".draw(at: CGPoint(x: 80, y: 1165), withAttributes: tagAttributes)

            // 9. Route Polyline Gradient Box
            let routeBox = CGRect(x: 60, y: 1240, width: targetSize.width - 120, height: 260)
            cg.setFillColor(red: 20/255.0, green: 22/255.0, blue: 28/255.0, alpha: 1.0)
            cg.fill(routeBox)
            cg.setStrokeColor(red: 45/255.0, green: 50/255.0, blue: 64/255.0, alpha: 1.0)
            cg.stroke(routeBox)

            "ROUTE GRADIENT MAPPING".draw(at: CGPoint(x: 80, y: 1260), withAttributes: subAttributes)
            drawRoutePolyline(cg: cg, box: routeBox.insetBy(dx: 40, dy: 40), coordinates: data.routeCoordinates)

            // 10. Footer Watermark
            let footerY = targetSize.height - 110
            "#DashCastDriver  •  dashcast.app".draw(at: CGPoint(x: 60, y: footerY), withAttributes: brandAttributes)
            "APPLE CARPLAY TELEMETRY • $19.99 LIFETIME PASS • ZERO SUBSCRIPTIONS".draw(
                at: CGPoint(x: 60, y: footerY + 30),
                withAttributes: tagAttributes
            )
        }
    }

    private func drawStatBox(cg: CGContext, rect: CGRect, title: String, value: String) {
        cg.setFillColor(red: 23/255.0, green: 25/255.0, blue: 32/255.0, alpha: 1.0)
        cg.fill(rect)
        cg.setStrokeColor(red: 45/255.0, green: 50/255.0, blue: 64/255.0, alpha: 1.0)
        cg.setLineWidth(1.5)
        cg.stroke(rect)

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor(red: 142/255.0, green: 146/255.0, blue: 160/255.0, alpha: 1.0)
        ]
        let valAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .heavy),
            .foregroundColor: UIColor.white
        ]

        title.draw(at: CGPoint(x: rect.minX + 16, y: rect.minY + 18), withAttributes: titleAttr)
        value.draw(at: CGPoint(x: rect.minX + 16, y: rect.minY + 48), withAttributes: valAttr)
    }

    private func drawRoutePolyline(cg: CGContext, box: CGRect, coordinates: [DriveSummaryCardData.RouteCoordinate]) {
        if coordinates.count >= 2 {
            let lats = coordinates.map { $0.latitude }
            let lons = coordinates.map { $0.longitude }
            guard let minLat = lats.min(), let maxLat = lats.max(),
                  let minLon = lons.min(), let maxLon = lons.max() else { return }

            let latSpan = max(maxLat - minLat, 0.0001)
            let lonSpan = max(maxLon - minLon, 0.0001)

            cg.setLineWidth(5.0)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)

            for i in 0..<(coordinates.count - 1) {
                let p1 = coordinates[i]
                let p2 = coordinates[i + 1]

                let x1 = box.minX + CGFloat((p1.longitude - minLon) / lonSpan) * box.width
                let y1 = box.minY + CGFloat(1.0 - (p1.latitude - minLat) / latSpan) * box.height
                let x2 = box.minX + CGFloat((p2.longitude - minLon) / lonSpan) * box.width
                let y2 = box.minY + CGFloat(1.0 - (p2.latitude - minLat) / latSpan) * box.height

                let speed = p1.speedKmh
                let color: UIColor = speed < 45 ? UIColor(Color.dashGreen) : (speed < 90 ? UIColor(Color.dashYellow) : UIColor(Color.dashRed))
                cg.setStrokeColor(color.cgColor)

                cg.move(to: CGPoint(x: x1, y: y1))
                cg.addLine(to: CGPoint(x: x2, y: y2))
                cg.strokePath()
            }
        } else {
            // Draw racetrack test loop
            cg.setStrokeColor(UIColor(Color.dashYellow).cgColor)
            cg.setLineWidth(4.0)
            cg.addEllipse(in: box.insetBy(dx: 40, dy: 20))
            cg.strokePath()
        }
    }
}
