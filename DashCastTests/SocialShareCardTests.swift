import XCTest
import SwiftUI
@testable import DashCast

@MainActor
final class SocialShareCardTests: XCTestCase {

    func testDriverGradeBuckets() {
        // Test S Grade (Apex Legend)
        let sGrade = DriverGradeInfo.from(score: 98)
        XCTAssertEqual(sGrade.grade, "S")
        XCTAssertEqual(sGrade.title, "APEX LEGEND")
        XCTAssertEqual(sGrade.color, Color(hex: "#FFE600"))

        let sBoundary = DriverGradeInfo.from(score: 95)
        XCTAssertEqual(sBoundary.grade, "S")

        // Test A Grade (Pro Cruiser)
        let aGrade = DriverGradeInfo.from(score: 88)
        XCTAssertEqual(aGrade.grade, "A")
        XCTAssertEqual(aGrade.title, "PRO CRUISER")
        XCTAssertEqual(aGrade.color, Color(hex: "#FFB800"))

        // Test B Grade (Road Rookie)
        let bGrade = DriverGradeInfo.from(score: 75)
        XCTAssertEqual(bGrade.grade, "B")
        XCTAssertEqual(bGrade.title, "ROAD ROOKIE")
        XCTAssertEqual(bGrade.color, Color(hex: "#34C759"))

        // Test C Grade (Track Demon)
        let cGrade = DriverGradeInfo.from(score: 55)
        XCTAssertEqual(cGrade.grade, "C")
        XCTAssertEqual(cGrade.title, "TRACK DEMON")
        XCTAssertEqual(cGrade.color, Color(hex: "#FF3B30"))
    }

    func testSocialShareTemplates() {
        let templates = SocialShareTemplateType.allCases
        XCTAssertEqual(templates.count, 3)

        let apex = SocialShareTemplateType.apexYellow
        XCTAssertEqual(apex.rawValue, "Apex Yellow")
        XCTAssertEqual(apex.accentColor, Color.dashYellow)

        let stealth = SocialShareTemplateType.stealthTitanium
        XCTAssertEqual(stealth.rawValue, "Stealth Titanium")
        XCTAssertEqual(stealth.accentColor, Color.dashGold)

        let track = SocialShareTemplateType.trackTelemetry
        XCTAssertEqual(track.rawValue, "Track Telemetry")
    }

    func testSocialShareCardDataCalculations() {
        let sampleTrip = TripModel(
            distanceMeters: 42800, // 42.8 km
            averageSpeedKmh: 64.0,
            maxSpeedKmh: 148.0,
            drivingScore: 96,
            harshBrakingCount: 0,
            harshAccelerationCount: 1,
            harshCorneringCount: 0
        )

        let cardData = SocialShareCardData(
            trip: sampleTrip,
            vehicleName: "Porsche 911 GT3 RS",
            vehicleImageName: "car_porsche_911",
            licensePlate: "APEX-911",
            peakGForce: 0.92,
            template: .apexYellow
        )

        XCTAssertEqual(cardData.driverGrade.grade, "S")
        XCTAssertEqual(cardData.driverGrade.title, "APEX LEGEND")
        XCTAssertEqual(cardData.smoothnessPercentage, 96)
        XCTAssertEqual(cardData.vehicleName, "Porsche 911 GT3 RS")
        XCTAssertEqual(cardData.licensePlate, "APEX-911")
        XCTAssertEqual(cardData.peakGForce, 0.92)
        XCTAssertEqual(cardData.trip.distanceKilometers, 42.8, accuracy: 0.01)
    }

    func testSocialShareCardViewRendering() {
        let sampleTrip = TripModel(
            distanceMeters: 15200,
            averageSpeedKmh: 45.0,
            maxSpeedKmh: 85.0,
            drivingScore: 88
        )
        let data = SocialShareCardData(trip: sampleTrip)
        let cardView = SocialShareCardView(data: data)
        XCTAssertNotNil(cardView.body)
    }

    func testSocialShareSheetViewRendering() {
        let sampleTrip = TripModel(
            distanceMeters: 25000,
            averageSpeedKmh: 60.0,
            maxSpeedKmh: 110.0,
            drivingScore: 92
        )
        let sheetView = SocialShareSheetView(trip: sampleTrip)
        XCTAssertNotNil(sheetView.body)
    }

    func testSmoothnessClamping() {
        // Below 10 score
        let lowTrip = TripModel(drivingScore: 5)
        let lowData = SocialShareCardData(trip: lowTrip)
        XCTAssertEqual(lowData.smoothnessPercentage, 10)

        // Above 100 score
        let highTrip = TripModel(drivingScore: 105)
        let highData = SocialShareCardData(trip: highTrip)
        XCTAssertEqual(highData.smoothnessPercentage, 100)
    }
}
