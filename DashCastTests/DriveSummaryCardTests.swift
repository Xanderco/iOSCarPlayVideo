import XCTest
import SwiftUI
@testable import DashCast

final class DriveSummaryCardTests: XCTestCase {

    // MARK: - 1. SmoothnessScorer & Badge Tiers

    @MainActor
    func testSmoothnessScorerBaseScoreAndTier() {
        let scorer = SmoothnessScorer.shared
        scorer.reset()

        XCTAssertEqual(scorer.currentScore, 100)
        XCTAssertEqual(scorer.currentBadgeTier, .formulaElite)
        XCTAssertEqual(scorer.currentBadgeTier.title, "PRO PILOT")
        XCTAssertEqual(scorer.currentBadgeTier.accentHex, "#FFE600")
    }

    func testSmoothnessBadgeTierThresholds() {
        XCTAssertEqual(SmoothnessBadgeTier.tier(for: 100), .formulaElite)
        XCTAssertEqual(SmoothnessBadgeTier.tier(for: 95), .formulaElite)
        XCTAssertEqual(SmoothnessBadgeTier.tier(for: 94), .smoothOperator)
        XCTAssertEqual(SmoothnessBadgeTier.tier(for: 85), .smoothOperator)
        XCTAssertEqual(SmoothnessBadgeTier.tier(for: 84), .urbanCruiser)
        XCTAssertEqual(SmoothnessBadgeTier.tier(for: 70), .urbanCruiser)
        XCTAssertEqual(SmoothnessBadgeTier.tier(for: 69), .spiritedDriver)
        XCTAssertEqual(SmoothnessBadgeTier.tier(for: 50), .spiritedDriver)
        XCTAssertEqual(SmoothnessBadgeTier.tier(for: 49), .trackDemon)
        XCTAssertEqual(SmoothnessBadgeTier.tier(for: 10), .trackDemon)
    }

    @MainActor
    func testSmoothnessScorerHarshPenaltiesAndFloor() {
        let scorer = SmoothnessScorer.shared
        scorer.reset()

        scorer.recordHarshEvent(.braking)     // 100 - 4 = 96
        XCTAssertEqual(scorer.currentScore, 96)
        XCTAssertEqual(scorer.currentBadgeTier, .formulaElite)

        scorer.recordHarshEvent(.acceleration) // 96 - 3 = 93
        XCTAssertEqual(scorer.currentScore, 93)
        XCTAssertEqual(scorer.currentBadgeTier, .smoothOperator)

        scorer.recordHarshEvent(.cornering)    // 93 - 3 = 90
        XCTAssertEqual(scorer.currentScore, 90)
        XCTAssertEqual(scorer.currentBadgeTier, .smoothOperator)

        // Trigger 30 harsh braking events (30 * 4 = 120 penalty)
        for _ in 0..<30 {
            scorer.recordHarshEvent(.braking)
        }
        XCTAssertEqual(scorer.currentScore, 10) // Floor clamped at 10
        XCTAssertEqual(scorer.currentBadgeTier, .trackDemon)
    }

    @MainActor
    func testSmoothnessScorerPeakGTracking() {
        let scorer = SmoothnessScorer.shared
        scorer.reset()

        scorer.analyzeGForce(x: 0.42, y: 0.35, z: 0.0)
        XCTAssertEqual(scorer.peakLateralG, 0.42, accuracy: 0.001)
        XCTAssertEqual(scorer.peakLongitudinalG, 0.35, accuracy: 0.001)
        let expectedCombined = sqrt(0.42 * 0.42 + 0.35 * 0.35)
        XCTAssertEqual(scorer.peakCombinedG, expectedCombined, accuracy: 0.001)

        // Higher G should update peak
        scorer.analyzeGForce(x: 0.88, y: 0.20, z: 0.0)
        XCTAssertEqual(scorer.peakLateralG, 0.88, accuracy: 0.001)
        XCTAssertGreaterThan(scorer.harshCorneringCount, 0) // Exceeded 0.52g threshold
    }

    func testSmoothnessScorerTripEvaluation() {
        let trip = TripModel(
            distanceMeters: 15400,
            averageSpeedKmh: 64.0,
            maxSpeedKmh: 128.0,
            drivingScore: 92,
            points: [],
            harshBrakingCount: 1,
            harshAccelerationCount: 1,
            harshCorneringCount: 0
        )

        let metrics = SmoothnessScorer.evaluate(trip: trip)
        XCTAssertEqual(metrics.score, 92)
        XCTAssertEqual(metrics.badgeTier, .smoothOperator)
        XCTAssertEqual(metrics.harshBrakingCount, 1)
        XCTAssertEqual(metrics.harshAccelerationCount, 1)
        XCTAssertGreaterThan(metrics.peakCombinedG, 0.4)
    }

    // MARK: - 2. DriveSummaryCardData Formatting & Serialization

    func testCardDataInitializationFromTrip() {
        let points = [
            TripPoint(latitude: 37.7749, longitude: -122.4194, speedKmh: 35.0, altitudeMeters: 10),
            TripPoint(latitude: 37.7755, longitude: -122.4180, speedKmh: 65.0, altitudeMeters: 12),
            TripPoint(latitude: 37.7760, longitude: -122.4170, speedKmh: 95.0, altitudeMeters: 15)
        ]

        let trip = TripModel(
            id: UUID(),
            startTime: Date(timeIntervalSince1970: 1700000000),
            endTime: Date(timeIntervalSince1970: 1700001800), // 30 minutes
            distanceMeters: 25000,                            // 25 km
            averageSpeedKmh: 50.0,
            maxSpeedKmh: 110.0,
            drivingScore: 97,
            points: points,
            harshBrakingCount: 0,
            harshAccelerationCount: 1,
            harshCorneringCount: 0
        )

        let cardData = DriveSummaryCardData(trip: trip)

        XCTAssertEqual(cardData.drivingScore, 97)
        XCTAssertEqual(cardData.badgeTier, .formulaElite)
        XCTAssertEqual(cardData.targetWidth, 1080)
        XCTAssertEqual(cardData.targetHeight, 1920)
        XCTAssertEqual(cardData.routeCoordinates.count, 3)
        XCTAssertEqual(cardData.formattedDuration, "30m 00s")
        XCTAssertEqual(cardData.formattedDistance, "25.0 KM")
        XCTAssertEqual(cardData.formattedTopSpeed, "110 KM/H")
        XCTAssertEqual(cardData.formattedAverageSpeed, "50 KM/H")
    }

    func testCardDataFormattingWithImperialUnits() {
        var prefs = UserPreferences()
        prefs.useMilesPerHour = true

        let trip = TripModel(
            distanceMeters: 16093.4, // ~10.0 miles
            averageSpeedKmh: 96.56,  // ~60.0 mph
            maxSpeedKmh: 128.74,     // ~80.0 mph
            drivingScore: 88
        )

        let cardData = DriveSummaryCardData(trip: trip, preferences: prefs)

        XCTAssertTrue(cardData.formattedDistance.contains("MI"))
        XCTAssertTrue(cardData.formattedTopSpeed.contains("MPH"))
        XCTAssertTrue(cardData.formattedAverageSpeed.contains("MPH"))
    }

    func testCardDataJSONSerializationRoundtrip() throws {
        let initialData = DriveSummaryCardData(
            id: UUID(),
            tripId: UUID(),
            date: Date(),
            durationSeconds: 1245,
            distanceMeters: 18450,
            averageSpeedKmh: 62.5,
            topSpeedKmh: 135.0,
            drivingScore: 98,
            badgeTier: .formulaElite,
            peakLateralG: 0.78,
            peakLongitudinalG: 0.42,
            peakCombinedG: 0.88,
            harshBrakingCount: 0,
            harshAccelerationCount: 0,
            harshCorneringCount: 0,
            vehicleName: "911 GT3 RS",
            vehicleBrand: "PORSCHE",
            vehicleImageName: "car_porsche_911",
            vehicleAccentHex: "#FFE600",
            useMilesPerHour: false,
            routeCoordinates: [
                DriveSummaryCardData.RouteCoordinate(latitude: 37.77, longitude: -122.41, speedKmh: 45),
                DriveSummaryCardData.RouteCoordinate(latitude: 37.78, longitude: -122.40, speedKmh: 85)
            ]
        )

        let encoded = try initialData.toJSONData()
        XCTAssertGreaterThan(encoded.count, 0)

        let decoded = try DriveSummaryCardData.fromJSONData(encoded)
        XCTAssertEqual(decoded.id, initialData.id)
        XCTAssertEqual(decoded.tripId, initialData.tripId)
        XCTAssertEqual(decoded.drivingScore, initialData.drivingScore)
        XCTAssertEqual(decoded.badgeTier, initialData.badgeTier)
        XCTAssertEqual(decoded.vehicleName, initialData.vehicleName)
        XCTAssertEqual(decoded.routeCoordinates.count, 2)
        XCTAssertEqual(decoded.targetWidth, 1080)
        XCTAssertEqual(decoded.targetHeight, 1920)
    }

    // MARK: - 3. Off-Screen Image Renderer & Bitmap Output

    @MainActor
    func testOffscreenStoryCardRenderingDimensions() async {
        let renderer = DriveSummaryCardRendererService.shared

        let trip = TripModel(
            distanceMeters: 12500,
            averageSpeedKmh: 58.0,
            maxSpeedKmh: 105.0,
            drivingScore: 96,
            points: [
                TripPoint(latitude: 34.0522, longitude: -118.2437, speedKmh: 40.0, altitudeMeters: 50),
                TripPoint(latitude: 34.0535, longitude: -118.2420, speedKmh: 75.0, altitudeMeters: 52)
            ]
        )

        let image = await renderer.renderStoryCard(from: trip, forceRefresh: true)

        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, 1080, accuracy: 1.0)
        XCTAssertEqual(image.size.height, 1920, accuracy: 1.0)
    }

    @MainActor
    func testEmptyRouteDoesNotCrashRenderer() async {
        let renderer = DriveSummaryCardRendererService.shared

        let trip = TripModel(
            distanceMeters: 0,
            averageSpeedKmh: 0,
            maxSpeedKmh: 0,
            drivingScore: 100,
            points: [] // Empty GPS points
        )

        let image = await renderer.renderStoryCard(from: trip, forceRefresh: true)
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, 1080, accuracy: 1.0)
        XCTAssertEqual(image.size.height, 1920, accuracy: 1.0)
    }

    @MainActor
    func testImageCompressionDataExport() async throws {
        let renderer = DriveSummaryCardRendererService.shared

        let trip = TripModel(
            distanceMeters: 8400,
            averageSpeedKmh: 48.0,
            maxSpeedKmh: 92.0,
            drivingScore: 94
        )

        let pngData = try await renderer.renderCardData(from: trip, format: .png)
        XCTAssertGreaterThan(pngData.count, 1024) // > 1KB

        let jpegData = try await renderer.renderCardData(from: trip, format: .jpeg, compressionQuality: 0.85)
        XCTAssertGreaterThan(jpegData.count, 1024) // > 1KB
    }

    @MainActor
    func testRendererCachingBehavior() async {
        let renderer = DriveSummaryCardRendererService.shared
        renderer.clearCache()

        let trip = TripModel(
            id: UUID(),
            distanceMeters: 5000,
            averageSpeedKmh: 45.0,
            maxSpeedKmh: 80.0,
            drivingScore: 91
        )

        let firstImage = await renderer.renderStoryCard(from: trip)
        let cachedImage = await renderer.renderStoryCard(from: trip)

        XCTAssertEqual(firstImage, cachedImage)
    }
}
