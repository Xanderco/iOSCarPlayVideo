import SwiftUI

public enum SocialShareTemplateType: String, CaseIterable, Identifiable {
    case apexYellow = "Apex Yellow"
    case stealthTitanium = "Stealth Titanium"
    case trackTelemetry = "Track Telemetry"

    public var id: String { rawValue }

    public var accentColor: Color {
        switch self {
        case .apexYellow:
            return Color.dashYellow
        case .stealthTitanium:
            return Color.dashGold
        case .trackTelemetry:
            return Color(hex: "#00E5FF") // High-contrast telemetry cyan
        }
    }

    public var secondaryColor: Color {
        switch self {
        case .apexYellow:
            return Color.dashGold
        case .stealthTitanium:
            return Color.white.opacity(0.8)
        case .trackTelemetry:
            return Color.dashYellow
        }
    }

    public var surfaceBackground: Color {
        switch self {
        case .apexYellow:
            return Color(hex: "#0C0D10")
        case .stealthTitanium:
            return Color(hex: "#08090B")
        case .trackTelemetry:
            return Color(hex: "#0A0D14")
        }
    }
}

public struct DriverGradeInfo: Equatable {
    public let grade: String
    public let title: String
    public let color: Color
    public let glowColor: Color

    public static func from(score: Int) -> DriverGradeInfo {
        switch score {
        case 95...100:
            return DriverGradeInfo(
                grade: "S",
                title: "APEX LEGEND",
                color: Color(hex: "#FFE600"),
                glowColor: Color(hex: "#FFE600").opacity(0.6)
            )
        case 85...94:
            return DriverGradeInfo(
                grade: "A",
                title: "PRO CRUISER",
                color: Color(hex: "#FFB800"),
                glowColor: Color(hex: "#FFB800").opacity(0.5)
            )
        case 70...84:
            return DriverGradeInfo(
                grade: "B",
                title: "ROAD ROOKIE",
                color: Color(hex: "#34C759"),
                glowColor: Color(hex: "#34C759").opacity(0.4)
            )
        default:
            return DriverGradeInfo(
                grade: "C",
                title: "TRACK DEMON",
                color: Color(hex: "#FF3B30"),
                glowColor: Color(hex: "#FF3B30").opacity(0.4)
            )
        }
    }
}

public struct SocialShareCardData {
    public var trip: TripModel
    public var vehicleName: String
    public var vehicleImageName: String
    public var licensePlate: String
    public var peakGForce: Double
    public var template: SocialShareTemplateType

    public init(
        trip: TripModel,
        vehicleName: String = "Porsche 911 GT3 RS",
        vehicleImageName: String = "car_porsche_911",
        licensePlate: String = "DASH-CAST",
        peakGForce: Double = 0.84,
        template: SocialShareTemplateType = .apexYellow
    ) {
        self.trip = trip
        self.vehicleName = vehicleName
        self.vehicleImageName = vehicleImageName
        self.licensePlate = licensePlate
        self.peakGForce = peakGForce
        self.template = template
    }

    public var driverGrade: DriverGradeInfo {
        DriverGradeInfo.from(score: trip.drivingScore)
    }

    public var smoothnessPercentage: Int {
        max(10, min(100, trip.drivingScore))
    }
}
