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

    public init(
        id: UUID = UUID(),
        carBrand: String = "Toyota",
        carModelName: String = "Supra",
        carImageName: String = "car_toyota_supra",
        driverGreeting: String = "Welcome, Driver",
        showWatermark: Bool = true,
        stickerId: String? = nil,
        customPhotoData: Data? = nil,
        trimmedVideoURL: URL? = nil,
        countdownTargetDate: Date? = nil,
        countdownTitle: String? = nil
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
    }
}
