import XCTest
@testable import DashCast

final class TripExportServiceTests: XCTestCase {

    private func makeSampleTrip(points: [TripPoint]? = nil) -> TripModel {
        let t0 = Date(timeIntervalSince1970: 1_764_090_000) // 2025-11-25T17:00:00Z
        let resolvedPoints = points ?? [
            TripPoint(
                latitude: 37.774900,
                longitude: -122.419400,
                speedKmh: 36.0, // 10.00 m/s
                altitudeMeters: 15.5,
                timestamp: t0
            ),
            TripPoint(
                latitude: 37.775500,
                longitude: -122.418000,
                speedKmh: 72.0, // 20.00 m/s
                altitudeMeters: 18.0,
                timestamp: t0.addingTimeInterval(60)
            )
        ]

        return TripModel(
            id: UUID(),
            startTime: t0,
            endTime: t0.addingTimeInterval(1800), // 30m 00s
            distanceMeters: 10_000,             // 10.00 km / 6.21 mi
            averageSpeedKmh: 50.0,              // 31.1 mph
            maxSpeedKmh: 80.0,                  // 49.7 mph
            drivingScore: 91,
            points: resolvedPoints,
            harshBrakingCount: 1,
            harshAccelerationCount: 2,
            harshCorneringCount: 0
        )
    }

    func testGPXGenerationContainsValidStructureAndPoints() throws {
        let trip = makeSampleTrip()
        let gpx = TripExportService.generateGPX(for: trip, name: "Morning Commute")

        XCTAssertTrue(gpx.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(gpx.contains("<gpx version=\"1.1\""))
        XCTAssertTrue(gpx.contains("<trk>"))
        XCTAssertTrue(gpx.contains("<trkseg>"))
        XCTAssertTrue(gpx.contains("<name>Morning Commute</name>"))
        XCTAssertTrue(gpx.contains("<trkpt lat=\"37.774900\" lon=\"-122.419400\">"))
        XCTAssertTrue(gpx.contains("<ele>15.5</ele>"))
        XCTAssertTrue(gpx.contains("<extensions>"))
        XCTAssertTrue(gpx.contains("<speed>10.00</speed>"))
        XCTAssertTrue(gpx.contains("<speed>20.00</speed>"))
        XCTAssertTrue(gpx.contains("</gpx>"))

        let parser = XMLParser(data: Data(gpx.utf8))
        XCTAssertTrue(parser.parse(), "Generated GPX must be well-formed XML: \(parser.parserError?.localizedDescription ?? "unknown")")
    }

    func testXMLEscapingAndISO8601Timestamps() throws {
        let raw = "Tom & Jerry's <Drive> \"Fast\" > Safe"
        let escaped = TripExportService.xmlEscaped(raw)
        XCTAssertEqual(escaped, "Tom &amp; Jerry&apos;s &lt;Drive&gt; &quot;Fast&quot; &gt; Safe")

        let trip = makeSampleTrip()
        let gpx = TripExportService.generateGPX(for: trip, name: raw)
        XCTAssertTrue(gpx.contains("<name>Tom &amp; Jerry&apos;s &lt;Drive&gt; &quot;Fast&quot; &gt; Safe</name>"))

        let expectedStartISO = TripExportService.iso8601Timestamp(from: trip.startTime)
        let expectedPoint2ISO = TripExportService.iso8601Timestamp(from: trip.points[1].timestamp)
        XCTAssertTrue(expectedStartISO.hasSuffix("Z"))
        XCTAssertTrue(gpx.contains("<time>\(expectedStartISO)</time>"))
        XCTAssertTrue(gpx.contains("<time>\(expectedPoint2ISO)</time>"))

        let parser = XMLParser(data: Data(gpx.utf8))
        XCTAssertTrue(parser.parse())
    }

    func testCSVQuotingRFC4180() {
        XCTAssertEqual(TripExportService.csvEscaped("plain"), "plain")
        XCTAssertEqual(TripExportService.csvEscaped("a,b"), "\"a,b\"")
        XCTAssertEqual(TripExportService.csvEscaped("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(TripExportService.csvEscaped("line1\nline2"), "\"line1\nline2\"")
        XCTAssertEqual(TripExportService.csvEscaped("line1\r\nline2"), "\"line1\r\nline2\"")
    }

    func testCSVUnitConversionKilometersAndMiles() {
        let trip = makeSampleTrip()

        let kmCSV = TripExportService.generateCSV(for: trip, useMiles: false)
        let kmRows = kmCSV.components(separatedBy: "\r\n")
        XCTAssertEqual(kmRows.count, 2)
        XCTAssertEqual(kmRows[0], "Date,Duration,Distance,AvgSpeed,MaxSpeed,DrivingScore,HardBrakes,RapidAccel,SharpTurns")

        let kmCols = kmRows[1].components(separatedBy: ",")
        XCTAssertEqual(kmCols.count, 9)
        XCTAssertEqual(kmCols[0], TripExportService.iso8601Timestamp(from: trip.startTime))
        XCTAssertEqual(kmCols[1], "00:30:00")
        XCTAssertEqual(kmCols[2], "10.00 km")
        XCTAssertEqual(kmCols[3], "50.0 km/h")
        XCTAssertEqual(kmCols[4], "80.0 km/h")
        XCTAssertEqual(kmCols[5], "91")
        XCTAssertEqual(kmCols[6], "1")
        XCTAssertEqual(kmCols[7], "2")
        XCTAssertEqual(kmCols[8], "0")

        let miCSV = TripExportService.generateCSV(for: trip, useMiles: true)
        let miRows = miCSV.components(separatedBy: "\r\n")
        XCTAssertEqual(miRows.count, 2)
        let miCols = miRows[1].components(separatedBy: ",")
        XCTAssertEqual(miCols[2], "6.21 mi")
        XCTAssertEqual(miCols[3], "31.1 mph")
        XCTAssertEqual(miCols[4], "49.7 mph")
    }

    func testEmptyTripAndEmptyHistoryEdgeCases() throws {
        let emptyPointsTrip = makeSampleTrip(points: [])
        let emptyGPX = TripExportService.generateGPX(for: emptyPointsTrip, name: "   ")
        XCTAssertTrue(emptyGPX.contains("<trkseg>\n    </trkseg>"))
        XCTAssertTrue(emptyGPX.contains("<name>DashCast Drive "))

        let parser = XMLParser(data: Data(emptyGPX.utf8))
        XCTAssertTrue(parser.parse())

        let emptyHistoryCSV = TripExportService.generateCSV(for: [], useMiles: false)
        XCTAssertEqual(emptyHistoryCSV, TripExportService.csvHeader)

        let multiCSV = TripExportService.generateCSV(for: [emptyPointsTrip, makeSampleTrip()], useMiles: false)
        XCTAssertEqual(multiCSV.components(separatedBy: "\r\n").count, 3)
    }

    func testTemporaryFileExportsWriteValidUTF8Files() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TripExportTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let trip = makeSampleTrip()
        let gpxURL = try TripExportService.exportGPXFile(for: trip, directory: tempDir)
        let csvURL = try TripExportService.exportCSVFile(for: trip, useMiles: true, directory: tempDir)
        let logURL = try TripExportService.exportMileageLogCSVFile(for: [trip], useMiles: false, directory: tempDir)

        XCTAssertEqual(gpxURL.pathExtension, "gpx")
        XCTAssertEqual(csvURL.pathExtension, "csv")
        XCTAssertEqual(logURL.pathExtension, "csv")

        let gpxContent = try String(contentsOf: gpxURL, encoding: .utf8)
        let csvContent = try String(contentsOf: csvURL, encoding: .utf8)
        let logContent = try String(contentsOf: logURL, encoding: .utf8)

        XCTAssertTrue(gpxContent.contains("<gpx version=\"1.1\""))
        XCTAssertTrue(csvContent.contains("6.21 mi"))
        XCTAssertTrue(logContent.contains("10.00 km"))
    }
}
