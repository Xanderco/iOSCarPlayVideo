import Foundation
import SwiftUI

public struct VehicleBrand: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let iconSystemName: String
    public let country: String

    public init(id: String, name: String, iconSystemName: String = "car.fill", country: String = "Global") {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.country = country
    }
}

public struct VehicleModel: Identifiable, Hashable {
    public let id: String
    public let brandId: String
    public let name: String
    public let year: String
    public let colorName: String
    public let carAccentColor: Color

    public init(id: String, brandId: String, name: String, year: String = "2024", colorName: String = "Racing Red", carAccentColor: Color = .dashRed) {
        self.id = id
        self.brandId = brandId
        self.name = name
        self.year = year
        self.colorName = colorName
        self.carAccentColor = carAccentColor
    }
}

public struct VehicleSticker: Identifiable {
    public let id: String
    public let title: String
    public let icon: String

    public init(id: String, title: String, icon: String) {
        self.id = id
        self.title = title
        self.icon = icon
    }
}

public final class VehicleCatalogService {
    public static let shared = VehicleCatalogService()

    public let brands: [VehicleBrand] = [
        VehicleBrand(id: "toyota", name: "Toyota", country: "Japan"),
        VehicleBrand(id: "chevrolet", name: "Chevrolet", country: "USA"),
        VehicleBrand(id: "ford", name: "Ford", country: "USA"),
        VehicleBrand(id: "bmw", name: "BMW", country: "Germany"),
        VehicleBrand(id: "mercedes", name: "Mercedes-Benz", country: "Germany"),
        VehicleBrand(id: "porsche", name: "Porsche", country: "Germany"),
        VehicleBrand(id: "audi", name: "Audi", country: "Germany"),
        VehicleBrand(id: "tesla", name: "Tesla", country: "USA"),
        VehicleBrand(id: "jeep", name: "Jeep", country: "USA"),
        VehicleBrand(id: "nissan", name: "Nissan", country: "Japan"),
        VehicleBrand(id: "honda", name: "Honda", country: "Japan"),
        VehicleBrand(id: "ferrari", name: "Ferrari", country: "Italy"),
        VehicleBrand(id: "lamborghini", name: "Lamborghini", country: "Italy"),
        VehicleBrand(id: "dodge", name: "Dodge", country: "USA"),
        VehicleBrand(id: "alfa_romeo", name: "Alfa Romeo", country: "Italy")
    ]

    public let vehicles: [VehicleModel] = [
        VehicleModel(id: "toyota_supra", brandId: "toyota", name: "GR Supra", year: "2024", colorName: "Velocity Orange", carAccentColor: .dashOrange),
        VehicleModel(id: "toyota_rav4", brandId: "toyota", name: "RAV4 Prime", year: "2024", colorName: "Blueprint Blue", carAccentColor: .dashCyan),
        VehicleModel(id: "toyota_camry", brandId: "toyota", name: "Camry TRD", year: "2024", colorName: "Supersonic Red", carAccentColor: .dashRed),
        VehicleModel(id: "chevrolet_corvette", brandId: "chevrolet", name: "Corvette Z06", year: "2024", colorName: "Torch Red", carAccentColor: .dashRed),
        VehicleModel(id: "chevrolet_equinox", brandId: "chevrolet", name: "Equinox RS", year: "2024", colorName: "Sunlit Gold", carAccentColor: .dashGold),
        VehicleModel(id: "ford_mustang", brandId: "ford", name: "Mustang Dark Horse", year: "2024", colorName: "Grabber Blue", carAccentColor: .dashBlue),
        VehicleModel(id: "ford_gt", brandId: "ford", name: "Ford GT", year: "2023", colorName: "Liquid Carbon", carAccentColor: .dashCyan),
        VehicleModel(id: "porsche_911", brandId: "porsche", name: "911 GT3 RS", year: "2024", colorName: "Lizard Green", carAccentColor: .dashGreen),
        VehicleModel(id: "porsche_taycan", brandId: "porsche", name: "Taycan Turbo S", year: "2024", colorName: "Frozen Blue", carAccentColor: .dashCyan),
        VehicleModel(id: "jeep_wrangler", brandId: "jeep", name: "Wrangler Rubicon 392", year: "2024", colorName: "Firecracker Red", carAccentColor: .dashRed),
        VehicleModel(id: "bmw_m4", brandId: "bmw", name: "M4 Competition", year: "2024", colorName: "Isle of Man Green", carAccentColor: .dashGreen),
        VehicleModel(id: "mercedes_amg_gt", brandId: "mercedes", name: "AMG GT 63", year: "2024", colorName: "Magno Grey", carAccentColor: .dashGold)
    ]

    public let stickers: [VehicleSticker] = [
        VehicleSticker(id: "route66", title: "Route 66", icon: "signpost.right.and.left.fill"),
        VehicleSticker(id: "racing_flag", title: "Checkered Flag", icon: "flag.checkered"),
        VehicleSticker(id: "heart", title: "Love Car", icon: "heart.fill"),
        VehicleSticker(id: "turbo", title: "Twin Turbo", icon: "bolt.fill"),
        VehicleSticker(id: "paw", title: "Pet Co-Pilot", icon: "pawprint.fill"),
        VehicleSticker(id: "flame", title: "Nitro Flame", icon: "flame.fill")
    ]

    public func vehicles(for brandId: String) -> [VehicleModel] {
        vehicles.filter { $0.brandId == brandId }
    }
}
