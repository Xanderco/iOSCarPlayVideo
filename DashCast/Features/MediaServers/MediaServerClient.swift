import Foundation

public enum MediaServerError: LocalizedError, Equatable {
    case invalidServerURL
    case notAuthenticated
    case invalidCredentials
    case httpStatus(Int)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .invalidServerURL: return "That doesn't look like a valid server address."
        case .notAuthenticated: return "Sign in to this server again."
        case .invalidCredentials: return "Wrong username or password."
        case .httpStatus(let code): return "The server answered with HTTP \(code)."
        case .decoding(let detail): return "Unexpected server response (\(detail))."
        }
    }
}

/// How a video should be streamed from the server.
public enum MediaStreamMode: Equatable, Sendable {
    /// Original file, no transcoding (`/Videos/{id}/stream?static=true`).
    case directPlay(container: String?)
    /// Server-side HLS (`/Videos/{id}/master.m3u8`), works for any source codec.
    case hls

    /// Containers AVPlayer can direct-play reliably; anything else goes through HLS.
    public static let directPlayContainers: Set<String> = ["mp4", "m4v", "mov"]

    public static func preferred(for item: MediaItem) -> MediaStreamMode {
        let container = (item.container ?? item.mediaSources?.first?.container)?.lowercased()
        if let container, container.split(separator: ",").contains(where: { directPlayContainers.contains(String($0)) }) {
            return .directPlay(container: container.split(separator: ",").first.map(String.init))
        }
        return .hls
    }
}

/// Minimal async/await client for the Jellyfin and Emby REST APIs.
public final class MediaServerClient: @unchecked Sendable {
    public let kind: MediaServerKind
    public let baseURL: URL
    public let deviceId: String
    public private(set) var accessToken: String?
    public private(set) var userId: String?

    public static let clientName = "DashCast"
    public static let clientVersion = "1.0.0"

    private let session: URLSession
    private let deviceName: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(kind: MediaServerKind,
                baseURL: URL,
                deviceId: String,
                deviceName: String = "iPhone",
                accessToken: String? = nil,
                userId: String? = nil,
                session: URLSession = .shared) {
        self.kind = kind
        self.baseURL = baseURL
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.accessToken = accessToken
        self.userId = userId
        self.session = session
    }

    public convenience init(account: MediaServerAccount, accessToken: String?, session: URLSession = .shared) {
        self.init(kind: account.kind,
                  baseURL: account.baseURL,
                  deviceId: account.deviceId,
                  accessToken: accessToken,
                  userId: account.userId,
                  session: session)
    }

    // MARK: - Server address

    /// Turns user input like `media.local:8096/` into `http://media.local:8096`.
    /// For Emby a trailing `/emby` is stripped because the client adds it itself.
    public static func normalizedServerURL(_ input: String, kind: MediaServerKind) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(" ") else { return nil }
        if !text.lowercased().hasPrefix("http://") && !text.lowercased().hasPrefix("https://") {
            text = "http://" + text
        }
        guard var comps = URLComponents(string: text),
              let host = comps.host, !host.isEmpty else { return nil }
        var path = comps.path
        while path.hasSuffix("/") { path.removeLast() }
        if kind == .emby, path.lowercased().hasSuffix("/emby") {
            path.removeLast(5)
        }
        comps.path = path
        comps.query = nil
        comps.fragment = nil
        return comps.url
    }

    // MARK: - URL building

    func endpoint(_ path: String, query: [URLQueryItem] = []) -> URL {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var basePath = comps.path
        while basePath.hasSuffix("/") { basePath.removeLast() }
        comps.path = basePath + kind.apiPathPrefix + path
        comps.queryItems = query.isEmpty ? nil : query
        return comps.url!
    }

    /// `MediaBrowser Client="DashCast", Device="iPhone", DeviceId="…", Version="1.0.0"[, Token="…"]`
    public var authorizationHeaderValue: String {
        func esc(_ s: String) -> String { s.replacingOccurrences(of: "\"", with: "'") }
        var value = "MediaBrowser Client=\"\(Self.clientName)\", Device=\"\(esc(deviceName))\", DeviceId=\"\(esc(deviceId))\", Version=\"\(Self.clientVersion)\""
        if let accessToken { value += ", Token=\"\(accessToken)\"" }
        return value
    }

    private func request(_ url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authorizationHeaderValue, forHTTPHeaderField: kind.authorizationHeaderName)
        if let accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    @discardableResult
    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if http.statusCode == 401 { throw MediaServerError.notAuthenticated }
            throw MediaServerError.httpStatus(http.statusCode)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw MediaServerError.decoding(String(describing: T.self))
        }
    }

    private func requireUser() throws -> String {
        guard accessToken != nil, let userId else { throw MediaServerError.notAuthenticated }
        return userId
    }

    // MARK: - Auth

    public func publicSystemInfo() async throws -> MediaPublicSystemInfo {
        let data = try await send(request(endpoint("/System/Info/Public")))
        return try decode(MediaPublicSystemInfo.self, from: data)
    }

    /// `POST /Users/AuthenticateByName`. On success the client keeps the token + user id.
    @discardableResult
    public func authenticate(username: String, password: String) async throws -> MediaAuthResult {
        let body = try encoder.encode(["Username": username, "Pw": password])
        let data: Data
        do {
            data = try await send(request(endpoint("/Users/AuthenticateByName"), method: "POST", body: body))
        } catch MediaServerError.notAuthenticated {
            throw MediaServerError.invalidCredentials
        }
        let result = try decode(MediaAuthResult.self, from: data)
        accessToken = result.accessToken
        userId = result.user.id
        return result
    }

    /// Best-effort server-side logout; the caller should also delete the stored token.
    public func logout() async {
        guard accessToken != nil else { return }
        _ = try? await send(request(endpoint("/Sessions/Logout"), method: "POST"))
        accessToken = nil
    }

    // MARK: - Browse

    static let itemFields = "Overview,PrimaryImageAspectRatio,MediaSources,UserData"

    /// The user's top-level libraries (`GET /Users/{userId}/Views`).
    public func libraries() async throws -> [MediaItem] {
        let user = try requireUser()
        let data = try await send(request(endpoint("/Users/\(user)/Views")))
        return try decode(MediaItemsResponse.self, from: data).items
    }

    /// Movies, series and videos inside a library, sorted by name.
    public func items(parentId: String,
                      includeItemTypes: [String] = ["Movie", "Series", "Video", "MusicVideo"],
                      startIndex: Int = 0,
                      limit: Int = 200) async throws -> [MediaItem] {
        let user = try requireUser()
        let url = endpoint("/Users/\(user)/Items", query: [
            URLQueryItem(name: "ParentId", value: parentId),
            URLQueryItem(name: "IncludeItemTypes", value: includeItemTypes.joined(separator: ",")),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "Fields", value: Self.itemFields),
            URLQueryItem(name: "StartIndex", value: String(startIndex)),
            URLQueryItem(name: "Limit", value: String(limit))
        ])
        let data = try await send(request(url))
        return try decode(MediaItemsResponse.self, from: data).items
    }

    /// Items the user started but didn't finish.
    public func resumeItems(limit: Int = 20) async throws -> [MediaItem] {
        let user = try requireUser()
        let url = endpoint("/Users/\(user)/Items/Resume", query: [
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "MediaTypes", value: "Video"),
            URLQueryItem(name: "Fields", value: Self.itemFields)
        ])
        let data = try await send(request(url))
        return try decode(MediaItemsResponse.self, from: data).items
    }

    /// Full item (with fresh `UserData` for the resume position).
    public func item(id: String) async throws -> MediaItem {
        let user = try requireUser()
        let data = try await send(request(endpoint("/Users/\(user)/Items/\(id)")))
        return try decode(MediaItem.self, from: data)
    }

    /// Seasons of a series, sorted by season number (specials/unnumbered last).
    public func seasons(seriesId: String) async throws -> [MediaItem] {
        let user = try requireUser()
        let url = endpoint("/Shows/\(seriesId)/Seasons", query: [
            URLQueryItem(name: "UserId", value: user),
            URLQueryItem(name: "Fields", value: "UserData")
        ])
        let data = try await send(request(url))
        return Self.sortedSeasons(try decode(MediaItemsResponse.self, from: data).items)
    }

    /// Episodes of a series (optionally a single season), sorted by season then episode.
    public func episodes(seriesId: String, seasonId: String? = nil) async throws -> [MediaItem] {
        let user = try requireUser()
        var query = [
            URLQueryItem(name: "UserId", value: user),
            URLQueryItem(name: "Fields", value: Self.itemFields)
        ]
        if let seasonId { query.append(URLQueryItem(name: "SeasonId", value: seasonId)) }
        let data = try await send(request(endpoint("/Shows/\(seriesId)/Episodes", query: query)))
        return Self.sortedEpisodes(try decode(MediaItemsResponse.self, from: data).items)
    }

    static func sortedSeasons(_ seasons: [MediaItem]) -> [MediaItem] {
        seasons.sorted { a, b in
            switch (a.indexNumber, b.indexNumber) {
            case let (x?, y?): return x == y ? a.name < b.name : x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.name < b.name
            }
        }
    }

    static func sortedEpisodes(_ episodes: [MediaItem]) -> [MediaItem] {
        episodes.sorted { a, b in
            let sa = a.parentIndexNumber ?? Int.max, sb = b.parentIndexNumber ?? Int.max
            if sa != sb { return sa < sb }
            let ea = a.indexNumber ?? Int.max, eb = b.indexNumber ?? Int.max
            if ea != eb { return ea < eb }
            return a.name < b.name
        }
    }

    // MARK: - Streams & images

    /// Playable URL with `api_key` so AVPlayer needs no custom headers.
    public func streamURL(for item: MediaItem, mode: MediaStreamMode? = nil, playSessionId: String? = nil) throws -> URL {
        guard let accessToken else { throw MediaServerError.notAuthenticated }
        let mediaSourceId = item.mediaSources?.first?.id ?? item.id
        var query = [
            URLQueryItem(name: "MediaSourceId", value: mediaSourceId),
            URLQueryItem(name: "DeviceId", value: deviceId),
            URLQueryItem(name: "api_key", value: accessToken)
        ]
        if let playSessionId { query.append(URLQueryItem(name: "PlaySessionId", value: playSessionId)) }

        switch mode ?? MediaStreamMode.preferred(for: item) {
        case .directPlay(let container):
            query.insert(URLQueryItem(name: "static", value: "true"), at: 0)
            if let container { query.insert(URLQueryItem(name: "Container", value: container), at: 1) }
            return endpoint("/Videos/\(item.id)/stream", query: query)
        case .hls:
            query.append(contentsOf: [
                URLQueryItem(name: "VideoCodec", value: "h264,hevc"),
                URLQueryItem(name: "AudioCodec", value: "aac,mp3,ac3,eac3"),
                URLQueryItem(name: "SegmentContainer", value: "mp4"),
                URLQueryItem(name: "TranscodingMaxAudioChannels", value: "2")
            ])
            return endpoint("/Videos/\(item.id)/master.m3u8", query: query)
        }
    }

    public func imageURL(for item: MediaItem, maxWidth: Int = 400) -> URL? {
        guard let tag = item.imageTags?["Primary"] else { return nil }
        return endpoint("/Items/\(item.id)/Images/Primary", query: [
            URLQueryItem(name: "maxWidth", value: String(maxWidth)),
            URLQueryItem(name: "tag", value: tag),
            URLQueryItem(name: "quality", value: "90")
        ])
    }

    // MARK: - Playback reporting

    public enum PlaybackEvent: String, Sendable {
        case start = "/Sessions/Playing"
        case progress = "/Sessions/Playing/Progress"
        case stopped = "/Sessions/Playing/Stopped"
    }

    public struct PlaybackReport: Encodable, Equatable, Sendable {
        public var itemId: String
        public var mediaSourceId: String
        public var playSessionId: String
        public var positionTicks: Int64
        public var isPaused: Bool
        public var playMethod: String
        public var canSeek: Bool = true

        enum CodingKeys: String, CodingKey {
            case itemId = "ItemId"
            case mediaSourceId = "MediaSourceId"
            case playSessionId = "PlaySessionId"
            case positionTicks = "PositionTicks"
            case isPaused = "IsPaused"
            case playMethod = "PlayMethod"
            case canSeek = "CanSeek"
        }
    }

    /// Reports start / progress / stop so the server tracks "continue watching".
    public func reportPlayback(_ event: PlaybackEvent, report: PlaybackReport) async throws {
        _ = try requireUser()
        let body = try encoder.encode(report)
        try await send(request(endpoint(event.rawValue), method: "POST", body: body))
    }
}
