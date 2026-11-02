import Foundation

public struct WidgetConfigModel: Codable, Identifiable {
    public var id: UUID
    public var carBrand: String
    public var carModelName: String
    public var carImageName: String
    public var driverGreeting: String
    public var showWatermark: Bool
    public var stickerId: String?
    public var customPhotoData: Data?
    public var trimmedVideoURL: URL?
    public var countdownTargetDate: Date?
    public var countdownTitle: String?
    public var carScale: Double
    public var carVerticalOffset: Double
    public var carHorizontalOffset: Double

    public init(
        id: UUID = UUID(),
        carBrand: String = "Porsche",
        carModelName: String = "911 GT3 RS",
        carImageName: String = "car_porsche_911",
        driverGreeting: String = "Welcome, Driver",
        showWatermark: Bool = true,
        stickerId: String? = nil,
        customPhotoData: Data? = nil,
        trimmedVideoURL: URL? = nil,
        countdownTargetDate: Date? = nil,
        countdownTitle: String? = nil,
        carScale: Double = 1.0,
        carVerticalOffset: Double = 0.0,
        carHorizontalOffset: Double = 0.0
    ) {
        self.id = id
        self.carBrand = carBrand
        self.carModelName = carModelName
        self.carImageName = carImageName
        self.driverGreeting = driverGreeting
        self.showWatermark = showWatermark
        self.stickerId = stickerId
        self.customPhotoData = customPhotoData
        self.trimmedVideoURL = trimmedVideoURL
        self.countdownTargetDate = countdownTargetDate
        self.countdownTitle = countdownTitle
        self.carScale = carScale
        self.carVerticalOffset = carVerticalOffset
        self.carHorizontalOffset = carHorizontalOffset
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.carBrand = try container.decodeIfPresent(String.self, forKey: .carBrand) ?? "Porsche"
        self.carModelName = try container.decodeIfPresent(String.self, forKey: .carModelName) ?? "911 GT3 RS"
        self.carImageName = try container.decodeIfPresent(String.self, forKey: .carImageName) ?? "car_porsche_911"
        self.driverGreeting = try container.decodeIfPresent(String.self, forKey: .driverGreeting) ?? "Welcome, Driver"
        self.showWatermark = try container.decodeIfPresent(Bool.self, forKey: .showWatermark) ?? true
        self.stickerId = try container.decodeIfPresent(String.self, forKey: .stickerId)
        self.customPhotoData = try container.decodeIfPresent(Data.self, forKey: .customPhotoData)
        self.trimmedVideoURL = try container.decodeIfPresent(URL.self, forKey: .trimmedVideoURL)
        self.countdownTargetDate = try container.decodeIfPresent(Date.self, forKey: .countdownTargetDate)
        self.countdownTitle = try container.decodeIfPresent(String.self, forKey: .countdownTitle)
        self.carScale = try container.decodeIfPresent(Double.self, forKey: .carScale) ?? 1.0
        self.carVerticalOffset = try container.decodeIfPresent(Double.self, forKey: .carVerticalOffset) ?? 0.0
        self.carHorizontalOffset = try container.decodeIfPresent(Double.self, forKey: .carHorizontalOffset) ?? 0.0
    }
}
