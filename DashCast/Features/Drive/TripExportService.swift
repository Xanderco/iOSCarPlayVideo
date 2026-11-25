import Foundation

/// Generates portable GPX 1.1 route files and RFC-4180 CSV mileage logs for recorded trips.
public enum TripExportService {
    public static let csvHeader = "Date,Duration,Distance,AvgSpeed,MaxSpeed,DrivingScore,HardBrakes,RapidAccel,SharpTurns"

    private static let posixLocale = Locale(identifier: "en_US_POSIX")
    private static let metersToMiles = 0.000621371
    private static let kmhToMph = 0.621371
    private static let kmhToMetersPerSecond = 1.0 / 3.6

    // MARK: - GPX 1.1 Export

    /// Generates a GPX 1.1 XML document for a single recorded trip.
    /// Point speeds inside `<extensions><speed>` are encoded in meters per second (`m/s`).
    public static func generateGPX(for trip: TripModel, name: String? = nil) -> String {
        let startTimestamp = iso8601Timestamp(from: trip.startTime)
        let resolvedName = (name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? "DashCast Drive \(startTimestamp)"
        let escapedName = xmlEscaped(resolvedName)

        var lines: [String] = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<gpx version=\"1.1\" creator=\"DashCast\" xmlns=\"http://www.topografix.com/GPX/1/1\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd\">",
            "  <metadata>",
            "    <name>\(escapedName)</name>",
            "    <time>\(startTimestamp)</time>",
            "  </metadata>",
            "  <trk>",
            "    <name>\(escapedName)</name>",
            "    <trkseg>"
        ]

        for point in trip.points {
            let lat = String(format: "%.6f", locale: posixLocale, point.latitude)
            let lon = String(format: "%.6f", locale: posixLocale, point.longitude)
            let ele = String(format: "%.1f", locale: posixLocale, point.altitudeMeters)
            let time = iso8601Timestamp(from: point.timestamp)
            let speedMetersPerSecond = max(point.speedKmh, 0) * kmhToMetersPerSecond
            let speed = String(format: "%.2f", locale: posixLocale, speedMetersPerSecond)

            lines.append("      <trkpt lat=\"\(lat)\" lon=\"\(lon)\">")
            lines.append("        <ele>\(ele)</ele>")
            lines.append("        <time>\(time)</time>")
            lines.append("        <extensions>")
            lines.append("          <speed>\(speed)</speed>")
            lines.append("        </extensions>")
            lines.append("      </trkpt>")
        }

        lines.append("    </trkseg>")
        lines.append("  </trk>")
        lines.append("</gpx>")

        return lines.joined(separator: "\n")
    }

    // MARK: - CSV Export

    /// Generates an RFC-4180-safe CSV summary for a single trip.
    public static func generateCSV(for trip: TripModel, useMiles: Bool = false) -> String {
        generateCSV(for: [trip], useMiles: useMiles)
    }

    /// Generates an RFC-4180-safe CSV mileage log for a list of trips.
    public static func generateCSV(for trips: [TripModel], useMiles: Bool = false) -> String {
        var rows: [String] = [csvHeader]
        rows.reserveCapacity(trips.count + 1)

        for trip in trips {
            let dateField = iso8601Timestamp(from: trip.startTime)
            let durationField = formattedDuration(trip.durationSeconds)
            let distanceField = formattedDistance(meters: trip.distanceMeters, useMiles: useMiles)
            let avgSpeedField = formattedSpeed(kmh: trip.averageSpeedKmh, useMiles: useMiles)
            let maxSpeedField = formattedSpeed(kmh: trip.maxSpeedKmh, useMiles: useMiles)

            let fields = [
                dateField,
                durationField,
                distanceField,
                avgSpeedField,
                maxSpeedField,
                "\(trip.drivingScore)",
                "\(trip.harshBrakingCount)",
                "\(trip.harshAccelerationCount)",
                "\(trip.harshCorneringCount)"
            ]

            rows.append(fields.map(csvEscaped).joined(separator: ","))
        }

        return rows.joined(separator: "\r\n")
    }

    // MARK: - Escaping & Formatting Helpers

    /// Escapes XML special characters in element text or attribute values.
    public static func xmlEscaped(_ value: String) -> String {
        var result = value.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }

    /// Quotes and escapes a CSV field in accordance with RFC-4180.
    public static func csvEscaped(_ field: String) -> String {
        let needsQuoting = field.contains(",")
            || field.contains("\"")
            || field.contains("\n")
            || field.contains("\r")
        guard needsQuoting else { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// Formats a `Date` as a UTC ISO-8601 string.
    public static func iso8601Timestamp(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    // MARK: - Temporary File Export

    public static func gpxFilename(for trip: TripModel) -> String {
        "DashCast-Trip-\(filenameTimestamp(from: trip.startTime)).gpx"
    }

    public static func csvFilename(for trip: TripModel) -> String {
        "DashCast-Trip-\(filenameTimestamp(from: trip.startTime)).csv"
    }

    public static func mileageLogCSVFilename(date: Date = Date()) -> String {
        "DashCast-Mileage-Log-\(filenameDateOnly(from: date)).csv"
    }

    public static func exportGPXFile(
        for trip: TripModel,
        name: String? = nil,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let content = generateGPX(for: trip, name: name)
        return try writeTemporaryFile(content: content, filename: gpxFilename(for: trip), directory: directory)
    }

    public static func exportCSVFile(
        for trip: TripModel,
        useMiles: Bool = false,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let content = generateCSV(for: trip, useMiles: useMiles)
        return try writeTemporaryFile(content: content, filename: csvFilename(for: trip), directory: directory)
    }

    public static func exportMileageLogCSVFile(
        for trips: [TripModel],
        useMiles: Bool = false,
        date: Date = Date(),
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let content = generateCSV(for: trips, useMiles: useMiles)
        return try writeTemporaryFile(content: content, filename: mileageLogCSVFilename(date: date), directory: directory)
    }

    public static func writeTemporaryFile(
        content: String,
        filename: String,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let safeFilename = sanitizedFilename(filename)
        let url = directory.appendingPathComponent(safeFilename)
        try Data(content.utf8).write(to: url, options: .atomic)
        return url
    }

    // MARK: - Private

    private static func formattedDistance(meters: Double, useMiles: Bool) -> String {
        let clampedMeters = max(meters, 0)
        if useMiles {
            let miles = clampedMeters * metersToMiles
            return String(format: "%.2f mi", locale: posixLocale, miles)
        }
        return String(format: "%.2f km", locale: posixLocale, clampedMeters / 1000.0)
    }

    private static func formattedSpeed(kmh: Double, useMiles: Bool) -> String {
        let clampedKmh = max(kmh, 0)
        if useMiles {
            return String(format: "%.1f mph", locale: posixLocale, clampedKmh * kmhToMph)
        }
        return String(format: "%.1f km/h", locale: posixLocale, clampedKmh)
    }

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d:%02d", locale: posixLocale, hours, minutes, secs)
    }

    private static func filenameTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = posixLocale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
    }

    private static func filenameDateOnly(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = posixLocale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func sanitizedFilename(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:\0")
        let parts = raw.components(separatedBy: invalid)
        let joined = parts.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? "DashCast-Export.txt" : joined
    }
}
