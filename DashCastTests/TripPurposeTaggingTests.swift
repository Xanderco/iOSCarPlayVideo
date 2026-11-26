import XCTest
@testable import DashCast

final class TripPurposeTaggingTests: XCTestCase {

    func testLegacyTripJSONWithoutCategoryOrNoteDecodesCleanly() throws {
        let tripId = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_001_200)

        let legacyJSON: [String: Any] = [
            "id": tripId.uuidString,
            "startTime": start.timeIntervalSinceReferenceDate,
            "endTime": end.timeIntervalSinceReferenceDate,
            "distanceMeters": 14_500.0,
            "averageSpeedKmh": 43.5,
            "maxSpeedKmh": 82.0,
            "drivingScore": 91,
            "points": [],
            "harshBrakingCount": 1,
            "harshAccelerationCount": 0,
            "harshCorneringCount": 2
        ]

        let data = try JSONSerialization.data(withJSONObject: legacyJSON)
        let decoded = try JSONDecoder().decode(TripModel.self, from: data)

        XCTAssertEqual(decoded.id, tripId)
        XCTAssertEqual(decoded.distanceMeters, 14_500.0, accuracy: 0.001)
        XCTAssertEqual(decoded.drivingScore, 91)
        XCTAssertEqual(decoded.harshBrakingCount, 1)
        XCTAssertEqual(decoded.harshCorneringCount, 2)
        XCTAssertNil(decoded.category)
        XCTAssertNil(decoded.note)
    }

    func testUnknownCategoryStringDecodesAsNilWithoutFailing() throws {
        let tripId = UUID()
        let start = Date(timeIntervalSince1970: 1_700_010_000)

        let futureJSON: [String: Any] = [
            "id": tripId.uuidString,
            "startTime": start.timeIntervalSinceReferenceDate,
            "distanceMeters": 5_000.0,
            "averageSpeedKmh": 40.0,
            "maxSpeedKmh": 70.0,
            "drivingScore": 88,
            "category": "future_unknown_category",
            "note": "  Airport drop-off  "
        ]

        let data = try JSONSerialization.data(withJSONObject: futureJSON)
        let decoded = try JSONDecoder().decode(TripModel.self, from: data)

        XCTAssertEqual(decoded.id, tripId)
        XCTAssertNil(decoded.category)
        XCTAssertEqual(decoded.note, "Airport drop-off")
        XCTAssertTrue(decoded.points.isEmpty)
        XCTAssertEqual(decoded.harshBrakingCount, 0)
    }

    func testTripCategoryAndNoteRoundTripEncoding() throws {
        let trip = TripModel(
            distanceMeters: 22_000,
            averageSpeedKmh: 55,
            maxSpeedKmh: 95,
            drivingScore: 96,
            category: .business,
            note: "  Client site visit \n"
        )

        XCTAssertEqual(trip.note, "Client site visit")

        let data = try JSONEncoder().encode(trip)
        let decoded = try JSONDecoder().decode(TripModel.self, from: data)

        XCTAssertEqual(decoded.category, .business)
        XCTAssertEqual(decoded.note, "Client site visit")
    }

    func testWhitespaceOnlyNoteNormalizesToNil() {
        let trip = TripModel(
            distanceMeters: 1_000,
            drivingScore: 90,
            category: .commute,
            note: "   \n\t  "
        )
        XCTAssertNil(trip.note)
        XCTAssertNil(TripModel.normalizedNote("   "))
        XCTAssertNil(TripModel.normalizedNote(nil))
    }

    func testCategoryFilteringAndSummaryTotals() {
        let trips = [
            TripModel(distanceMeters: 10_000, drivingScore: 90, category: .business),
            TripModel(distanceMeters: 25_000, drivingScore: 80, category: .business),
            TripModel(distanceMeters: 8_000, drivingScore: 94, category: .commute),
            TripModel(distanceMeters: 12_000, drivingScore: 86, category: .personal),
            TripModel(distanceMeters: 5_000, drivingScore: 100, category: nil)
        ]

        let allSummary = TripCategorySummary.summarize(trips, category: nil)
        XCTAssertEqual(allSummary.tripCount, 5)
        XCTAssertEqual(allSummary.totalDistanceMeters, 60_000, accuracy: 0.001)
        XCTAssertEqual(allSummary.totalDistanceKilometers, 60.0, accuracy: 0.001)
        XCTAssertEqual(allSummary.averageScore, 90)

        let businessSummary = TripCategorySummary.summarize(trips, category: .business)
        XCTAssertEqual(businessSummary.tripCount, 2)
        XCTAssertEqual(businessSummary.totalDistanceMeters, 35_000, accuracy: 0.001)
        XCTAssertEqual(businessSummary.totalDistanceMiles, 35_000 * 0.000621371, accuracy: 0.001)
        XCTAssertEqual(businessSummary.averageScore, 85)

        let commuteSummary = TripCategorySummary.summarize(trips, category: .commute)
        XCTAssertEqual(commuteSummary.tripCount, 1)
        XCTAssertEqual(commuteSummary.totalDistanceMeters, 8_000, accuracy: 0.001)
        XCTAssertEqual(commuteSummary.averageScore, 94)

        let personalSummary = TripCategorySummary.summarize(trips, category: .personal)
        XCTAssertEqual(personalSummary.tripCount, 1)
        XCTAssertEqual(personalSummary.totalDistanceMeters, 12_000, accuracy: 0.001)
        XCTAssertEqual(personalSummary.averageScore, 86)

        let emptyBusiness = TripCategorySummary.summarize([], category: .business)
        XCTAssertEqual(emptyBusiness.tripCount, 0)
        XCTAssertEqual(emptyBusiness.totalDistanceMeters, 0, accuracy: 0.001)
        XCTAssertEqual(emptyBusiness.averageScore, 0)

        let breakdown = TripCategorySummary.breakdown(for: trips)
        XCTAssertEqual(breakdown[.business], businessSummary)
        XCTAssertEqual(breakdown[.commute], commuteSummary)
        XCTAssertEqual(breakdown[.personal], personalSummary)
    }

    func testPersistenceUpdateTripPersistsCategoryAndNoteInPlace() {
        let suiteName = "DashCastTripPurposeTaggingTests"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistence = PersistenceController(userDefaults: defaults)
        let first = TripModel(distanceMeters: 4_000, drivingScore: 90, category: nil, note: nil)
        let second = TripModel(distanceMeters: 9_000, drivingScore: 84, category: .personal, note: "Grocery")
        persistence.saveTrips([first, second])

        var updatedFirst = first
        updatedFirst.category = .business
        updatedFirst.note = "Client meeting"
        persistence.updateTrip(updatedFirst)

        let loaded = persistence.loadTrips()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, first.id)
        XCTAssertEqual(loaded[0].category, .business)
        XCTAssertEqual(loaded[0].note, "Client meeting")
        XCTAssertEqual(loaded[1].id, second.id)
        XCTAssertEqual(loaded[1].category, .personal)
    }
}
