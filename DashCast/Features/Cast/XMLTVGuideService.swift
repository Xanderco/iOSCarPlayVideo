import Foundation
import Combine

/// A single programme slot parsed from an XMLTV feed (`<programme>`).
public struct XMLTVProgramme: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let channelID: String
    public let title: String
    public let subtitle: String?
    public let description: String?
    public let category: String?
    public let start: Date
    public let stop: Date

    public init(
        id: String? = nil,
        channelID: String,
        title: String,
        subtitle: String? = nil,
        description: String? = nil,
        category: String? = nil,
        start: Date,
        stop: Date
    ) {
        self.id = id ?? "\(channelID)|\(Int(start.timeIntervalSince1970))"
        self.channelID = channelID
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.category = category
        self.start = start
        self.stop = stop
    }

    public func contains(_ date: Date) -> Bool {
        date >= start && date < stop
    }

    public func progress(at date: Date) -> Double {
        let duration = stop.timeIntervalSince(start)
        guard duration > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(start)
        return min(max(elapsed / duration, 0), 1)
    }
}

/// Now & Next EPG snapshot for a single channel at a point in time.
public struct ChannelEPGSlot: Equatable, Sendable {
    public let now: XMLTVProgramme?
    public let next: XMLTVProgramme?
    public let progress: Double?

    public init(now: XMLTVProgramme? = nil, next: XMLTVProgramme? = nil, progress: Double? = nil) {
        self.now = now
        self.next = next
        self.progress = progress
    }

    public var isEmpty: Bool {
        now == nil && next == nil
    }
}

/// Decoded contents of an XMLTV document.
public struct XMLTVGuideData: Sendable, Equatable {
    public let displayNamesByChannelID: [String: [String]]
    public let programmesByChannelID: [String: [XMLTVProgramme]]

    public init(
        displayNamesByChannelID: [String: [String]] = [:],
        programmesByChannelID: [String: [XMLTVProgramme]] = [:]
    ) {
        self.displayNamesByChannelID = displayNamesByChannelID
        self.programmesByChannelID = programmesByChannelID
    }
}

public enum XMLTVGuideError: LocalizedError, Equatable {
    case invalidResponse
    case httpStatus(Int)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The EPG server returned an invalid response."
        case .httpStatus(let code):
            return "The EPG server answered with HTTP \(code)."
        case .parseFailed(let message):
            return "Could not parse XMLTV guide: \(message)"
        }
    }
}

/// Parses and serves XMLTV Electronic Program Guide (EPG) feeds for IPTV playlists.
/// Uses Foundation's `XMLParser` with injectable `URLSession` for deterministic offline testing.
@MainActor
public final class XMLTVGuideService: ObservableObject {
    public static let shared = XMLTVGuideService()

    @Published public private(set) var programmesByChannelID: [String: [XMLTVProgramme]] = [:]
    @Published public private(set) var displayNamesByChannelID: [String: [String]] = [:]
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: String?
    @Published public private(set) var loadedFeedURLs: Set<URL> = []

    private let session: URLSession
    private var lowercasedChannelIDIndex: [String: String] = [:]
    private var channelIDByNormalizedDisplayName: [String: String] = [:]

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Loading

    /// Downloads and ingests an XMLTV feed from `url`.
    @discardableResult
    public func loadGuide(from url: URL, forceRefresh: Bool = false) async throws -> XMLTVGuideData {
        if !forceRefresh && loadedFeedURLs.contains(url) {
            return XMLTVGuideData(
                displayNamesByChannelID: displayNamesByChannelID,
                programmesByChannelID: programmesByChannelID
            )
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                let err = XMLTVGuideError.httpStatus(http.statusCode)
                lastError = err.errorDescription
                throw err
            }
            let parsed = try Self.parseXMLTV(data: data)
            merge(parsed)
            loadedFeedURLs.insert(url)
            return parsed
        } catch let guideError as XMLTVGuideError {
            lastError = guideError.errorDescription
            throw guideError
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Loads EPG feeds referenced by any playlist's `epgURL` (`url-tvg` / `x-tvg-url`).
    public func loadGuides(for playlists: [IPTVPlaylist], forceRefresh: Bool = false) async {
        var seen: Set<URL> = []
        let urls = playlists.compactMap(\.epgURL).filter { seen.insert($0).inserted }
        for url in urls {
            _ = try? await loadGuide(from: url, forceRefresh: forceRefresh)
        }
    }

    /// Parses and merges raw XMLTV bytes directly into the in-memory guide store.
    @discardableResult
    public func ingest(data: Data, sourceURL: URL? = nil) throws -> XMLTVGuideData {
        let parsed = try Self.parseXMLTV(data: data)
        merge(parsed)
        if let sourceURL {
            loadedFeedURLs.insert(sourceURL)
        }
        return parsed
    }

    public func clear() {
        programmesByChannelID = [:]
        displayNamesByChannelID = [:]
        lowercasedChannelIDIndex = [:]
        channelIDByNormalizedDisplayName = [:]
        loadedFeedURLs = []
        lastError = nil
    }

    // MARK: - Now / Next Lookup

    /// Computes Now, Next, and elapsed progress for a specific XMLTV channel ID.
    public func slot(for channelID: String, at date: Date = Date()) -> ChannelEPGSlot {
        let trimmed = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ChannelEPGSlot() }

        let resolvedID = programmesByChannelID[trimmed] != nil
            ? trimmed
            : lowercasedChannelIDIndex[trimmed.lowercased()]

        guard let resolvedID, let programmes = programmesByChannelID[resolvedID], !programmes.isEmpty else {
            return ChannelEPGSlot()
        }

        let now = programmes.first { $0.contains(date) }
        let nextAnchor = now?.stop ?? date
        let next = programmes.first { $0.start >= nextAnchor && $0.id != now?.id }
        let progress = now.map { $0.progress(at: date) }
        return ChannelEPGSlot(now: now, next: next, progress: progress)
    }

    /// Computes Now, Next, and elapsed progress for a `ChannelModel`, matching `tvgID` first
    /// and falling back to `<display-name>` if `tvgID` is absent or unmatched.
    public func slot(for channel: ChannelModel, at date: Date = Date()) -> ChannelEPGSlot {
        if let tvgID = channel.tvgID, !tvgID.isEmpty {
            let direct = slot(for: tvgID, at: date)
            if !direct.isEmpty { return direct }
        }
        if let mappedID = channelIDByNormalizedDisplayName[Self.normalizeName(channel.name)] {
            return slot(for: mappedID, at: date)
        }
        return ChannelEPGSlot()
    }

    // MARK: - Merging

    private func merge(_ data: XMLTVGuideData) {
        for (channelID, names) in data.displayNamesByChannelID {
            var existing = displayNamesByChannelID[channelID] ?? []
            for name in names where !existing.contains(name) {
                existing.append(name)
            }
            displayNamesByChannelID[channelID] = existing
            lowercasedChannelIDIndex[channelID.lowercased()] = channelID
            for name in existing {
                let normalized = Self.normalizeName(name)
                if !normalized.isEmpty {
                    channelIDByNormalizedDisplayName[normalized] = channelID
                }
            }
        }

        for (channelID, incoming) in data.programmesByChannelID {
            var mergedByID: [String: XMLTVProgramme] = [:]
            for prog in programmesByChannelID[channelID] ?? [] {
                mergedByID[prog.id] = prog
            }
            for prog in incoming {
                mergedByID[prog.id] = prog
            }
            programmesByChannelID[channelID] = mergedByID.values.sorted {
                if $0.start != $1.start { return $0.start < $1.start }
                return $0.stop < $1.stop
            }
            lowercasedChannelIDIndex[channelID.lowercased()] = channelID
        }
    }

    private static func normalizeName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - XMLTV Parsing

    /// Parses raw XMLTV XML data into channels and sorted programmes.
    nonisolated public static func parseXMLTV(data: Data) throws -> XMLTVGuideData {
        let delegate = XMLTVParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            let message = parser.parserError?.localizedDescription ?? "Malformed XMLTV document"
            throw XMLTVGuideError.parseFailed(message)
        }

        var sortedProgrammes: [String: [XMLTVProgramme]] = [:]
        for (channelID, items) in delegate.programmesByChannelID {
            sortedProgrammes[channelID] = items.sorted {
                if $0.start != $1.start { return $0.start < $1.start }
                return $0.stop < $1.stop
            }
        }

        return XMLTVGuideData(
            displayNamesByChannelID: delegate.displayNamesByChannelID,
            programmesByChannelID: sortedProgrammes
        )
    }

    /// Parses XMLTV timestamp strings such as `20261125100000 +0000`, `20261125100000`, or `202611251000 -0500`.
    nonisolated public static func parseXMLTVDate(_ raw: String) -> Date? {
        XMLTVDateParser().parse(raw)
    }
}

private struct XMLTVDateParser {
    private let formatters: [DateFormatter]
    private let isoFormatter: ISO8601DateFormatter

    init() {
        let specs: [(format: String, utcDefault: Bool)] = [
            ("yyyyMMddHHmmss Z", false),
            ("yyyyMMddHHmmssZ", false),
            ("yyyyMMddHHmmss", true),
            ("yyyyMMddHHmm Z", false),
            ("yyyyMMddHHmmZ", false),
            ("yyyyMMddHHmm", true)
        ]
        self.formatters = specs.map { spec in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            if spec.utcDefault {
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
            }
            formatter.dateFormat = spec.format
            return formatter
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        self.isoFormatter = iso
    }

    func parse(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for formatter in formatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return isoFormatter.date(from: trimmed)
    }
}

// MARK: - Foundation XMLParser Delegate

private final class XMLTVParserDelegate: NSObject, XMLParserDelegate {
    var displayNamesByChannelID: [String: [String]] = [:]
    var programmesByChannelID: [String: [XMLTVProgramme]] = [:]

    private let dateParser = XMLTVDateParser()
    private var currentChannelElementID: String?
    private var currentProgrammeChannelID: String?
    private var currentProgrammeStart: Date?
    private var currentProgrammeStop: Date?

    private var currentTitle: String?
    private var currentSubtitle: String?
    private var currentDescription: String?
    private var currentCategory: String?

    private var activeElementName: String?
    private var characterBuffer: String = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let lower = elementName.lowercased()
        activeElementName = lower
        characterBuffer = ""

        if lower == "channel" {
            let id = attributeDict["id"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            currentChannelElementID = (id?.isEmpty == false) ? id : nil
        } else if lower == "programme" {
            let channel = attributeDict["channel"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let start = attributeDict["start"].flatMap { dateParser.parse($0) }
            let stop = attributeDict["stop"].flatMap { dateParser.parse($0) }
            if let channel, !channel.isEmpty, let start, let stop, stop > start {
                currentProgrammeChannelID = channel
                currentProgrammeStart = start
                currentProgrammeStop = stop
            } else {
                currentProgrammeChannelID = nil
                currentProgrammeStart = nil
                currentProgrammeStop = nil
            }
            currentTitle = nil
            currentSubtitle = nil
            currentDescription = nil
            currentCategory = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let lower = elementName.lowercased()
        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if let channelID = currentChannelElementID, lower == "display-name", !text.isEmpty {
            var names = displayNamesByChannelID[channelID] ?? []
            if !names.contains(text) {
                names.append(text)
            }
            displayNamesByChannelID[channelID] = names
        } else if currentProgrammeChannelID != nil {
            switch lower {
            case "title":
                if currentTitle == nil && !text.isEmpty { currentTitle = text }
            case "sub-title":
                if currentSubtitle == nil && !text.isEmpty { currentSubtitle = text }
            case "desc":
                if currentDescription == nil && !text.isEmpty { currentDescription = text }
            case "category":
                if currentCategory == nil && !text.isEmpty { currentCategory = text }
            case "programme":
                if let channelID = currentProgrammeChannelID,
                   let start = currentProgrammeStart,
                   let stop = currentProgrammeStop,
                   let title = currentTitle, !title.isEmpty {
                    let programme = XMLTVProgramme(
                        channelID: channelID,
                        title: title,
                        subtitle: currentSubtitle,
                        description: currentDescription,
                        category: currentCategory,
                        start: start,
                        stop: stop
                    )
                    programmesByChannelID[channelID, default: []].append(programme)
                }
                currentProgrammeChannelID = nil
                currentProgrammeStart = nil
                currentProgrammeStop = nil
                currentTitle = nil
                currentSubtitle = nil
                currentDescription = nil
                currentCategory = nil
            default:
                break
            }
        }

        if lower == "channel" {
            currentChannelElementID = nil
        }
        activeElementName = nil
        characterBuffer = ""
    }
}
