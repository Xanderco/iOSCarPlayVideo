import Foundation
import SwiftUI

public enum WidgetTemplateCategory: String, CaseIterable, Identifiable {
    case plate
    case coupleDays
    case dateTime
    case countdown
    case vinylRecord
    case dailyQuote
    case carBrands

    public var id: String { rawValue }

    public var titleKey: LocalizedStringKey {
        switch self {
        case .plate: return "Plate"
        case .coupleDays: return "Couple Days"
        case .dateTime: return "Date & Time"
        case .countdown: return "Countdown"
        case .vinylRecord: return "Vinyl Record"
        case .dailyQuote: return "Daily Quote"
        case .carBrands: return "Car Brands"
        }
    }

    public var sectionHeaderKey: LocalizedStringKey {
        switch self {
        case .carBrands: return "100+ Car Brands"
        default: return titleKey
        }
    }

    public var navigationTitleKey: LocalizedStringKey {
        titleKey
    }
}

public struct WidgetTemplatePreset: Identifiable, Equatable {
    public let id: String
    public let category: WidgetTemplateCategory
    public let title: String
    public let subtitle: String
    public let templateConfig: WidgetConfigModel
    public let previewBadge: String

    public init(
        id: String,
        category: WidgetTemplateCategory,
        title: String,
        subtitle: String,
        templateConfig: WidgetConfigModel,
        previewBadge: String
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.templateConfig = templateConfig
        self.previewBadge = previewBadge
    }

    /// Returns a fresh configuration with a new UUID so selecting a preset creates a new widget.
    public func makeFreshConfig() -> WidgetConfigModel {
        var copy = templateConfig
        copy.id = UUID()
        return copy
    }
}

public enum WidgetTemplateCatalog {
    public static let defaultStarterWidgets: [WidgetConfigModel] = [
        WidgetConfigModel(
            carBrand: "Porsche",
            carModelName: "911 GT3 RS",
            carImageName: "car_porsche_911",
            driverGreeting: "Welcome, Driver",
            showWatermark: true,
            stickerId: "turbo"
        ),
        WidgetConfigModel(
            carBrand: "Toyota",
            carModelName: "RAV4 GR Sport",
            carImageName: "car_toyota_rav4",
            driverGreeting: "Hello, Michael",
            showWatermark: true,
            stickerId: "paw"
        ),
        WidgetConfigModel(
            carBrand: "Chevrolet",
            carModelName: "Corvette Stingray",
            carImageName: "car_chevrolet_corvette",
            driverGreeting: "Track Ready",
            showWatermark: true,
            stickerId: "route66"
        )
    ]

    public static func presets(for category: WidgetTemplateCategory) -> [WidgetTemplatePreset] {
        switch category {
        case .plate:
            return [
                WidgetTemplatePreset(
                    id: "plate_custom_car",
                    category: .plate,
                    title: "Custom Plate & Car",
                    subtitle: "ABC-1234",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Porsche",
                        carModelName: "911 GT3 RS",
                        carImageName: "car_porsche_911",
                        driverGreeting: "Welcome, Driver",
                        showWatermark: true,
                        plateText: "ABC-1234",
                        textColorHex: "#FFFFFF",
                        fontName: "Mono"
                    ),
                    previewBadge: "ABC-1234"
                ),
                WidgetTemplatePreset(
                    id: "plate_clean",
                    category: .plate,
                    title: "Clean Plate",
                    subtitle: "Minimal silver frame",
                    templateConfig: WidgetConfigModel(
                        carBrand: "BMW",
                        carModelName: "M4 Competition",
                        carImageName: "car_bmw_m4",
                        driverGreeting: "Clean Build",
                        showWatermark: false,
                        plateText: "ABC-1234",
                        textColorHex: "#FFFFFF",
                        fontName: "BEBAS"
                    ),
                    previewBadge: "ABC-1234"
                ),
                WidgetTemplatePreset(
                    id: "plate_california",
                    category: .plate,
                    title: "California Style",
                    subtitle: "Classic blue & red script",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Ford",
                        carModelName: "Mustang Dark Horse",
                        carImageName: "car_ford_mustang",
                        driverGreeting: "Pacific Coast",
                        showWatermark: true,
                        stickerId: "route66",
                        plateText: "ACX-789",
                        textColorHex: "#00D4FF",
                        fontName: "Serif"
                    ),
                    previewBadge: "ACX-789"
                ),
                WidgetTemplatePreset(
                    id: "plate_track_yellow",
                    category: .plate,
                    title: "Track Spec Plate",
                    subtitle: "High-contrast night tag",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Chevrolet",
                        carModelName: "Corvette Stingray",
                        carImageName: "car_chevrolet_corvette",
                        driverGreeting: "Pit Lane Ready",
                        showWatermark: true,
                        stickerId: "racing_flag",
                        plateText: "APEX-01",
                        textColorHex: "#FFE600",
                        fontName: "BEBAS"
                    ),
                    previewBadge: "APEX-01"
                )
            ]

        case .coupleDays:
            return [
                WidgetTemplatePreset(
                    id: "couple_sunset",
                    category: .coupleDays,
                    title: "Together with babe",
                    subtitle: "488 days",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Porsche",
                        carModelName: "911 GT3 RS",
                        carImageName: "car_porsche_911",
                        driverGreeting: "Together 488 days",
                        showWatermark: false,
                        stickerId: "heart",
                        countdownTitle: "488",
                        plateText: nil,
                        textColorHex: "#FF9500",
                        fontName: "Serif"
                    ),
                    previewBadge: "488 days"
                ),
                WidgetTemplatePreset(
                    id: "couple_anniversary",
                    category: .coupleDays,
                    title: "Milestone Days",
                    subtitle: "1.206 Days",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Mercedes-Benz",
                        carModelName: "AMG GT 63",
                        carImageName: "car_mercedes_amg",
                        driverGreeting: "1,206 Days Together",
                        showWatermark: false,
                        stickerId: "heart",
                        countdownTitle: "1206",
                        plateText: nil,
                        textColorHex: "#FF3B30",
                        fontName: "Classic"
                    ),
                    previewBadge: "1,206"
                ),
                WidgetTemplatePreset(
                    id: "couple_roadtrip",
                    category: .coupleDays,
                    title: "Co-Pilot Mode",
                    subtitle: "Weekend getaway",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Jeep",
                        carModelName: "Wrangler Rubicon",
                        carImageName: "car_jeep_wrangler",
                        driverGreeting: "Our Road Trip",
                        showWatermark: true,
                        stickerId: "heart",
                        countdownTitle: "365",
                        plateText: "LOVE-02",
                        textColorHex: "#FFE600",
                        fontName: "Default"
                    ),
                    previewBadge: "365 days"
                )
            ]

        case .dateTime:
            return [
                WidgetTemplatePreset(
                    id: "datetime_golden_gate",
                    category: .dateTime,
                    title: "Golden Gate Clock",
                    subtitle: "Serif cockpit timepiece",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Toyota",
                        carModelName: "GR Supra",
                        carImageName: "car_toyota_supra",
                        driverGreeting: "Sunday Cruise",
                        showWatermark: true,
                        plateText: nil,
                        textColorHex: "#00D4FF",
                        fontName: "Serif"
                    ),
                    previewBadge: "11:21 AM"
                ),
                WidgetTemplatePreset(
                    id: "datetime_paris",
                    category: .dateTime,
                    title: "Paris Midnight",
                    subtitle: "Rounded minimal clock",
                    templateConfig: WidgetConfigModel(
                        carBrand: "BMW",
                        carModelName: "M4 Competition",
                        carImageName: "car_bmw_m4",
                        driverGreeting: "PARIS · SUNDAY",
                        showWatermark: true,
                        plateText: nil,
                        textColorHex: "#FFE600",
                        fontName: "Default"
                    ),
                    previewBadge: "11:21"
                ),
                WidgetTemplatePreset(
                    id: "datetime_telemetry",
                    category: .dateTime,
                    title: "Cockpit Chrono",
                    subtitle: "Monospace instrument display",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Porsche",
                        carModelName: "911 GT3 RS",
                        carImageName: "car_porsche_911",
                        driverGreeting: "Chrono Mode",
                        showWatermark: true,
                        stickerId: "turbo",
                        plateText: "CHRONO",
                        textColorHex: "#34C759",
                        fontName: "Mono"
                    ),
                    previewBadge: "24H"
                )
            ]

        case .countdown:
            return [
                WidgetTemplatePreset(
                    id: "countdown_winter",
                    category: .countdown,
                    title: "Winter ❄️",
                    subtitle: "In 2 months, 13 days",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Jeep",
                        carModelName: "Wrangler Rubicon",
                        carImageName: "car_jeep_wrangler",
                        driverGreeting: "Winter Road Trip",
                        showWatermark: true,
                        countdownTargetDate: Calendar.current.date(byAdding: .day, value: 74, to: Date()),
                        countdownTitle: "74",
                        plateText: "SNOW-26",
                        textColorHex: "#00D4FF",
                        fontName: "Default"
                    ),
                    previewBadge: "74 DAYS"
                ),
                WidgetTemplatePreset(
                    id: "countdown_graduation",
                    category: .countdown,
                    title: "Graduation 🎉",
                    subtitle: "147 DAYS",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Toyota",
                        carModelName: "RAV4 GR Sport",
                        carImageName: "car_toyota_rav4",
                        driverGreeting: "Graduation Day",
                        showWatermark: false,
                        countdownTargetDate: Calendar.current.date(byAdding: .day, value: 147, to: Date()),
                        countdownTitle: "147",
                        plateText: nil,
                        textColorHex: "#FFE600",
                        fontName: "BEBAS"
                    ),
                    previewBadge: "147 DAYS"
                ),
                WidgetTemplatePreset(
                    id: "countdown_trackday",
                    category: .countdown,
                    title: "Track Day 🏁",
                    subtitle: "10 DAYS LEFT",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Chevrolet",
                        carModelName: "Corvette Stingray",
                        carImageName: "car_chevrolet_corvette",
                        driverGreeting: "Track Day Ready",
                        showWatermark: true,
                        stickerId: "racing_flag",
                        countdownTargetDate: Calendar.current.date(byAdding: .day, value: 10, to: Date()),
                        countdownTitle: "10",
                        plateText: "TRACK-10",
                        textColorHex: "#FF3B30",
                        fontName: "BEBAS"
                    ),
                    previewBadge: "10 DAYS"
                )
            ]

        case .vinylRecord:
            return [
                WidgetTemplatePreset(
                    id: "vinyl_sunday",
                    category: .vinylRecord,
                    title: "Vinyl Sunday",
                    subtitle: "CASSETTE CLUB",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Ford",
                        carModelName: "Mustang Dark Horse",
                        carImageName: "car_ford_mustang",
                        driverGreeting: "Vinyl Sunday",
                        showWatermark: false,
                        stickerId: "flame",
                        plateText: nil,
                        textColorHex: "#FF9500",
                        fontName: "Classic"
                    ),
                    previewBadge: "LP · 33"
                ),
                WidgetTemplatePreset(
                    id: "vinyl_midnight",
                    category: .vinylRecord,
                    title: "Midnight Crossing",
                    subtitle: "THE ANALOG FOUR",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Toyota",
                        carModelName: "GR Supra",
                        carImageName: "car_toyota_supra",
                        driverGreeting: "Midnight Crossing",
                        showWatermark: true,
                        stickerId: "turbo",
                        plateText: "HI-FI",
                        textColorHex: "#FFE600",
                        fontName: "Mono"
                    ),
                    previewBadge: "ANALOG"
                ),
                WidgetTemplatePreset(
                    id: "vinyl_synthwave",
                    category: .vinylRecord,
                    title: "Night Drive LP",
                    subtitle: "PURE STEREO",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Porsche",
                        carModelName: "911 GT3 RS",
                        carImageName: "car_porsche_911",
                        driverGreeting: "Night Drive LP",
                        showWatermark: true,
                        plateText: "STEREO",
                        textColorHex: "#00D4FF",
                        fontName: "BEBAS"
                    ),
                    previewBadge: "STEREO"
                )
            ]

        case .dailyQuote:
            return [
                WidgetTemplatePreset(
                    id: "quote_light",
                    category: .dailyQuote,
                    title: "Daily Refresh",
                    subtitle: "No one is keeping score at this light.",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Mercedes-Benz",
                        carModelName: "AMG GT 63",
                        carImageName: "car_mercedes_amg",
                        driverGreeting: "Enjoy the drive",
                        showWatermark: false,
                        plateText: nil,
                        textColorHex: "#00D4FF",
                        fontName: "Serif"
                    ),
                    previewBadge: "Quote"
                ),
                WidgetTemplatePreset(
                    id: "quote_quiet",
                    category: .dailyQuote,
                    title: "Daily Reminder",
                    subtitle: "Quiet is a place you can drive to.",
                    templateConfig: WidgetConfigModel(
                        carBrand: "BMW",
                        carModelName: "M4 Competition",
                        carImageName: "car_bmw_m4",
                        driverGreeting: "Quiet road ahead",
                        showWatermark: true,
                        plateText: nil,
                        textColorHex: "#34C759",
                        fontName: "Default"
                    ),
                    previewBadge: "Zen"
                ),
                WidgetTemplatePreset(
                    id: "quote_focus",
                    category: .dailyQuote,
                    title: "Scenic Route",
                    subtitle: "Take the long way home tonight.",
                    templateConfig: WidgetConfigModel(
                        carBrand: "Toyota",
                        carModelName: "RAV4 GR Sport",
                        carImageName: "car_toyota_rav4",
                        driverGreeting: "Long way home",
                        showWatermark: true,
                        stickerId: "route66",
                        plateText: "SCENIC",
                        textColorHex: "#FFE600",
                        fontName: "Classic"
                    ),
                    previewBadge: "Scenic"
                )
            ]

        case .carBrands:
            return []
        }
    }

    /// Builds a fresh `WidgetConfigModel` pre-populated for a selected vehicle brand.
    public static func presetConfig(
        for brand: VehicleBrand,
        catalog: VehicleCatalogService = .shared
    ) -> WidgetConfigModel {
        let matchedVehicle = catalog.vehicles(for: brand.id).first
        return WidgetConfigModel(
            carBrand: brand.name,
            carModelName: matchedVehicle?.name ?? brand.name,
            carImageName: matchedVehicle?.imageName ?? "car_porsche_911",
            driverGreeting: "Welcome, Driver",
            showWatermark: true,
            plateText: "\(brand.name.prefix(3).uppercased())-01",
            textColorHex: "#FFFFFF",
            fontName: "Default"
        )
    }

    // MARK: - Saved Widget Operations

    /// Updates an existing widget by ID in-place, or inserts a new widget at index 0 (making it active).
    public static func upsert(_ widget: WidgetConfigModel, in widgets: [WidgetConfigModel]) -> [WidgetConfigModel] {
        var next = widgets
        if let existingIndex = next.firstIndex(where: { $0.id == widget.id }) {
            next[existingIndex] = widget
        } else {
            next.insert(widget, at: 0)
        }
        return next
    }

    /// Moves the widget with the given ID to index 0 so it becomes the active widget across the app & WidgetKit.
    public static func activate(_ widgetID: UUID, in widgets: [WidgetConfigModel]) -> [WidgetConfigModel] {
        guard let index = widgets.firstIndex(where: { $0.id == widgetID }), index != 0 else {
            return widgets
        }
        var next = widgets
        let chosen = next.remove(at: index)
        next.insert(chosen, at: 0)
        return next
    }

    /// Deletes the widget with the given ID from the saved list.
    public static func delete(_ widgetID: UUID, from widgets: [WidgetConfigModel]) -> [WidgetConfigModel] {
        widgets.filter { $0.id != widgetID }
    }
}
