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
    /// Original file, no transcoding.
    case directPlay(container: String?)
    /// Server-side HLS, works for any source codec.
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

/// Minimal async/await client for Jellyfin, Emby, Plex, and Xtream Codes APIs.
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
    /// Strips kind-specific suffixes (`/emby`, `/player_api.php`, `/get.php`, `/web`).
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
        switch kind {
        case .emby:
            if path.lowercased().hasSuffix("/emby") { path.removeLast(5) }
        case .xtream:
            for suffix in ["/player_api.php", "/get.php"] where path.lowercased().hasSuffix(suffix) {
                path.removeLast(suffix.count)
                break
            }
        case .plex:
            for suffix in ["/web", "/identity"] where path.lowercased().hasSuffix(suffix) {
                path.removeLast(suffix.count)
                break
            }
        case .jellyfin:
            break
        }
        comps.path = path
        comps.query = nil
        comps.fragment = nil
        return comps.url
    }

    // MARK: - URL building & requests

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
        switch kind {
        case .jellyfin, .emby:
            request.setValue(authorizationHeaderValue, forHTTPHeaderField: kind.authorizationHeaderName)
            if let accessToken {
                request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")
            }
        case .plex:
            request.setValue(deviceId, forHTTPHeaderField: "X-Plex-Client-Identifier")
            request.setValue(Self.clientName, forHTTPHeaderField: "X-Plex-Product")
            request.setValue(Self.clientVersion, forHTTPHeaderField: "X-Plex-Version")
            request.setValue(deviceName, forHTTPHeaderField: "X-Plex-Device")
            if let accessToken {
                request.setValue(accessToken, forHTTPHeaderField: "X-Plex-Token")
            }
        case .xtream:
            break
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

    private func requireToken() throws -> String {
        guard let accessToken, !accessToken.isEmpty else { throw MediaServerError.notAuthenticated }
        return accessToken
    }

    // MARK: - Auth

    public func publicSystemInfo() async throws -> MediaPublicSystemInfo {
        let data = try await send(request(endpoint("/System/Info/Public")))
        return try decode(MediaPublicSystemInfo.self, from: data)
    }

    /// `POST /Users/AuthenticateByName` for Jellyfin/Emby. On success keeps token + user id.
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

    /// Validates a Plex server URL + `X-Plex-Token` via `GET /` (or `/identity`).
    @discardableResult
    public func authenticatePlex(token: String) async throws -> PlexServerIdentityContainer {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MediaServerError.invalidCredentials }
        accessToken = trimmed
        do {
            let identity = try await plexIdentity()
            userId = identity.myPlexUsername ?? identity.machineIdentifier ?? "plex-user"
            return identity
        } catch MediaServerError.notAuthenticated, MediaServerError.httpStatus(403) {
            accessToken = nil
            userId = nil
            throw MediaServerError.invalidCredentials
        } catch {
            accessToken = nil
            userId = nil
            throw error
        }
    }

    /// Validates an Xtream Codes account via `player_api.php?username=...&password=...`.
    /// Keeps `password` in `accessToken` (which `MediaServerStore` persists strictly in Keychain).
    @discardableResult
    public func authenticateXtream(username: String, password: String) async throws -> XtreamAuthResponse {
        let cleanUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUser.isEmpty, !password.isEmpty else { throw MediaServerError.invalidCredentials }
        userId = cleanUser
        accessToken = password
        do {
            let response = try await xtreamAuthInfo()
            guard response.isAuthorized else {
                accessToken = nil
                userId = nil
                throw MediaServerError.invalidCredentials
            }
            return response
        } catch MediaServerError.notAuthenticated, MediaServerError.httpStatus(403) {
            accessToken = nil
            userId = nil
            throw MediaServerError.invalidCredentials
        } catch {
            accessToken = nil
            userId = nil
            throw error
        }
    }

    /// Best-effort server-side logout for MediaBrowser servers.
    public func logout() async {
        guard kind.isMediaBrowser, accessToken != nil else {
            accessToken = nil
            return
        }
        _ = try? await send(request(endpoint("/Sessions/Logout"), method: "POST"))
        accessToken = nil
    }

    // MARK: - Unified Browse

    static let itemFields = "Overview,PrimaryImageAspectRatio,MediaSources,UserData"

    private enum XtreamVirtualFolder {
        static let live = "xtream:live"
        static let vod = "xtream:vod"
        static let series = "xtream:series"
        static let liveCatPrefix = "xtream:live:cat:"
        static let vodCatPrefix = "xtream:vod:cat:"
        static let seriesCatPrefix = "xtream:series:cat:"
        static let liveStreamPrefix = "xtream:live:stream:"
        static let vodStreamPrefix = "xtream:vod:stream:"
        static let seriesShowPrefix = "xtream:series:show:"
        static let episodePrefix = "xtream:episode:"
    }

    /// The user's top-level libraries.
    public func libraries() async throws -> [MediaItem] {
        switch kind {
        case .jellyfin, .emby:
            let user = try requireUser()
            let data = try await send(request(endpoint("/Users/\(user)/Views")))
            return try decode(MediaItemsResponse.self, from: data).items
        case .plex:
            return try await plexSections().map { $0.toMediaItem() }
        case .xtream:
            _ = try requireUser()
            return [
                MediaItem(id: XtreamVirtualFolder.live, name: "Live TV", type: "CollectionFolder", collectionType: "livetv"),
                MediaItem(id: XtreamVirtualFolder.vod, name: "Movies (VOD)", type: "CollectionFolder", collectionType: "movies"),
                MediaItem(id: XtreamVirtualFolder.series, name: "Series", type: "CollectionFolder", collectionType: "tvshows")
            ]
        }
    }

    /// Movies, series, categories, and videos inside a library or folder.
    public func items(parentId: String,
                      includeItemTypes: [String] = ["Movie", "Series", "Video", "MusicVideo"],
                      startIndex: Int = 0,
                      limit: Int = 200) async throws -> [MediaItem] {
        switch kind {
        case .jellyfin, .emby:
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
        case .plex:
            return try await plexSectionItems(sectionKey: parentId).map { $0.toMediaItem() }
        case .xtream:
            return try await xtreamItems(parentId: parentId)
        }
    }

    /// Items the user started but didn't finish.
    public func resumeItems(limit: Int = 20) async throws -> [MediaItem] {
        switch kind {
        case .jellyfin, .emby:
            let user = try requireUser()
            let url = endpoint("/Users/\(user)/Items/Resume", query: [
                URLQueryItem(name: "Limit", value: String(limit)),
                URLQueryItem(name: "MediaTypes", value: "Video"),
                URLQueryItem(name: "Fields", value: Self.itemFields)
            ])
            let data = try await send(request(url))
            return try decode(MediaItemsResponse.self, from: data).items
        case .plex:
            return Array(try await plexOnDeck().prefix(limit)).map { $0.toMediaItem() }
        case .xtream:
            return []
        }
    }

    /// Full item (with fresh `UserData` for the resume position).
    public func item(id: String) async throws -> MediaItem {
        switch kind {
        case .jellyfin, .emby:
            let user = try requireUser()
            let data = try await send(request(endpoint("/Users/\(user)/Items/\(id)")))
            return try decode(MediaItem.self, from: data)
        case .plex:
            return try await plexMetadata(ratingKey: id).toMediaItem()
        case .xtream:
            throw MediaServerError.httpStatus(404)
        }
    }

    /// Seasons of a series, sorted by season number (specials/unnumbered last).
    public func seasons(seriesId: String) async throws -> [MediaItem] {
        switch kind {
        case .jellyfin, .emby:
            let user = try requireUser()
            let url = endpoint("/Shows/\(seriesId)/Seasons", query: [
                URLQueryItem(name: "UserId", value: user),
                URLQueryItem(name: "Fields", value: "UserData")
            ])
            let data = try await send(request(url))
            return Self.sortedSeasons(try decode(MediaItemsResponse.self, from: data).items)
        case .plex:
            let children = try await plexChildren(ratingKey: seriesId)
            let seasons = children.filter { $0.type?.lowercased() == "season" }.map { $0.toMediaItem() }
            return Self.sortedSeasons(seasons)
        case .xtream:
            let rawId = seriesId.hasPrefix(XtreamVirtualFolder.seriesShowPrefix)
                ? String(seriesId.dropFirst(XtreamVirtualFolder.seriesShowPrefix.count))
                : seriesId
            let info = try await xtreamSeriesInfo(seriesId: rawId)
            let seasons = (info.seasons ?? []).map { season in
                MediaItem(
                    id: "season-\(season.seasonNumber)",
                    name: season.name ?? "Season \(season.seasonNumber)",
                    type: "Season",
                    indexNumber: season.seasonNumber
                )
            }
            return Self.sortedSeasons(seasons)
        }
    }

    /// Episodes of a series (optionally a single season), sorted by season then episode.
    public func episodes(seriesId: String, seasonId: String? = nil) async throws -> [MediaItem] {
        switch kind {
        case .jellyfin, .emby:
            let user = try requireUser()
            var query = [
                URLQueryItem(name: "UserId", value: user),
                URLQueryItem(name: "Fields", value: Self.itemFields)
            ]
            if let seasonId { query.append(URLQueryItem(name: "SeasonId", value: seasonId)) }
            let data = try await send(request(endpoint("/Shows/\(seriesId)/Episodes", query: query)))
            return Self.sortedEpisodes(try decode(MediaItemsResponse.self, from: data).items)
        case .plex:
            let items: [PlexMetadata]
            if let seasonId {
                items = try await plexChildren(ratingKey: seasonId)
            } else {
                items = try await plexAllLeaves(seriesKey: seriesId)
            }
            return Self.sortedEpisodes(items.map { $0.toMediaItem() })
        case .xtream:
            let rawId = seriesId.hasPrefix(XtreamVirtualFolder.seriesShowPrefix)
                ? String(seriesId.dropFirst(XtreamVirtualFolder.seriesShowPrefix.count))
                : seriesId
            let info = try await xtreamSeriesInfo(seriesId: rawId)
            let showName = info.info?.name
            let allEpisodes = (info.episodes ?? [:]).flatMap { seasonKey, list in
                let fallbackSeason = Int(seasonKey)
                return list.map { ep -> MediaItem in
                    let seasonNum = ep.season ?? fallbackSeason
                    return MediaItem(
                        id: "\(XtreamVirtualFolder.episodePrefix)\(ep.id)",
                        name: ep.title,
                        type: "Episode",
                        seriesId: seriesId,
                        seriesName: showName,
                        seasonId: seasonNum.map { "season-\($0)" },
                        indexNumber: ep.episodeNum,
                        parentIndexNumber: seasonNum,
                        container: ep.containerExtension ?? XtreamStreamKind.series.defaultExtension
                    )
                }
            }
            let filtered = seasonId.map { sid in allEpisodes.filter { $0.seasonId == sid } } ?? allEpisodes
            return Self.sortedEpisodes(filtered)
        }
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

    // MARK: - Plex API

    public func plexIdentity() async throws -> PlexServerIdentityContainer {
        _ = try requireToken()
        let data = try await send(request(endpoint("/")))
        return try decode(PlexMediaContainerResponse<PlexServerIdentityContainer>.self, from: data).mediaContainer
    }

    public func plexSections() async throws -> [PlexDirectory] {
        _ = try requireToken()
        let data = try await send(request(endpoint("/library/sections")))
        return try decode(PlexMediaContainerResponse<PlexSectionsContainer>.self, from: data).mediaContainer.directory ?? []
    }

    public func plexSectionItems(sectionKey: String) async throws -> [PlexMetadata] {
        _ = try requireToken()
        let data = try await send(request(endpoint("/library/sections/\(sectionKey)/all")))
        return try decode(PlexMediaContainerResponse<PlexMetadataContainer>.self, from: data).mediaContainer.metadata ?? []
    }

    public func plexOnDeck() async throws -> [PlexMetadata] {
        _ = try requireToken()
        let data = try await send(request(endpoint("/library/onDeck")))
        return try decode(PlexMediaContainerResponse<PlexMetadataContainer>.self, from: data).mediaContainer.metadata ?? []
    }

    public func plexMetadata(ratingKey: String) async throws -> PlexMetadata {
        _ = try requireToken()
        let data = try await send(request(endpoint("/library/metadata/\(ratingKey)")))
        guard let item = try decode(PlexMediaContainerResponse<PlexMetadataContainer>.self, from: data).mediaContainer.metadata?.first else {
            throw MediaServerError.decoding("PlexMetadata")
        }
        return item
    }

    public func plexChildren(ratingKey: String) async throws -> [PlexMetadata] {
        _ = try requireToken()
        let data = try await send(request(endpoint("/library/metadata/\(ratingKey)/children")))
        return try decode(PlexMediaContainerResponse<PlexMetadataContainer>.self, from: data).mediaContainer.metadata ?? []
    }

    public func plexAllLeaves(seriesKey: String) async throws -> [PlexMetadata] {
        _ = try requireToken()
        let data = try await send(request(endpoint("/library/metadata/\(seriesKey)/allLeaves")))
        return try decode(PlexMediaContainerResponse<PlexMetadataContainer>.self, from: data).mediaContainer.metadata ?? []
    }

    // MARK: - Xtream Codes API

    private func xtreamEndpoint(action: String? = nil, extraQuery: [URLQueryItem] = []) throws -> URL {
        let username = try requireUser()
        let password = try requireToken()
        var query = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        if let action { query.append(URLQueryItem(name: "action", value: action)) }
        query.append(contentsOf: extraQuery)
        return endpoint("/player_api.php", query: query)
    }

    public func xtreamAuthInfo() async throws -> XtreamAuthResponse {
        let url = try xtreamEndpoint()
        let data = try await send(request(url))
        return try decode(XtreamAuthResponse.self, from: data)
    }

    public func xtreamLiveCategories() async throws -> [XtreamCategory] {
        let url = try xtreamEndpoint(action: "get_live_categories")
        let data = try await send(request(url))
        return try decode([XtreamCategory].self, from: data)
    }

    public func xtreamVodCategories() async throws -> [XtreamCategory] {
        let url = try xtreamEndpoint(action: "get_vod_categories")
        let data = try await send(request(url))
        return try decode([XtreamCategory].self, from: data)
    }

    public func xtreamSeriesCategories() async throws -> [XtreamCategory] {
        let url = try xtreamEndpoint(action: "get_series_categories")
        let data = try await send(request(url))
        return try decode([XtreamCategory].self, from: data)
    }

    public func xtreamLiveStreams(categoryId: String? = nil) async throws -> [XtreamLiveStream] {
        let extra = categoryId.map { [URLQueryItem(name: "category_id", value: $0)] } ?? []
        let url = try xtreamEndpoint(action: "get_live_streams", extraQuery: extra)
        let data = try await send(request(url))
        return try decode([XtreamLiveStream].self, from: data)
    }

    public func xtreamVodStreams(categoryId: String? = nil) async throws -> [XtreamVodStream] {
        let extra = categoryId.map { [URLQueryItem(name: "category_id", value: $0)] } ?? []
        let url = try xtreamEndpoint(action: "get_vod_streams", extraQuery: extra)
        let data = try await send(request(url))
        return try decode([XtreamVodStream].self, from: data)
    }

    public func xtreamSeries(categoryId: String? = nil) async throws -> [XtreamSeries] {
        let extra = categoryId.map { [URLQueryItem(name: "category_id", value: $0)] } ?? []
        let url = try xtreamEndpoint(action: "get_series", extraQuery: extra)
        let data = try await send(request(url))
        return try decode([XtreamSeries].self, from: data)
    }

    public func xtreamSeriesInfo(seriesId: String) async throws -> XtreamSeriesInfo {
        let url = try xtreamEndpoint(action: "get_series_info",
                                     extraQuery: [URLQueryItem(name: "series_id", value: seriesId)])
        let data = try await send(request(url))
        return try decode(XtreamSeriesInfo.self, from: data)
    }

    private func xtreamItems(parentId: String) async throws -> [MediaItem] {
        switch parentId {
        case XtreamVirtualFolder.live:
            return try await xtreamLiveCategories().map {
                MediaItem(id: "\(XtreamVirtualFolder.liveCatPrefix)\($0.categoryId)", name: $0.categoryName, type: "Folder")
            }
        case XtreamVirtualFolder.vod:
            return try await xtreamVodCategories().map {
                MediaItem(id: "\(XtreamVirtualFolder.vodCatPrefix)\($0.categoryId)", name: $0.categoryName, type: "Folder")
            }
        case XtreamVirtualFolder.series:
            return try await xtreamSeriesCategories().map {
                MediaItem(id: "\(XtreamVirtualFolder.seriesCatPrefix)\($0.categoryId)", name: $0.categoryName, type: "Folder")
            }
        default:
            if parentId.hasPrefix(XtreamVirtualFolder.liveCatPrefix) {
                let catId = String(parentId.dropFirst(XtreamVirtualFolder.liveCatPrefix.count))
                return try await xtreamLiveStreams(categoryId: catId).map {
                    MediaItem(id: "\(XtreamVirtualFolder.liveStreamPrefix)\($0.streamId)",
                              name: $0.name,
                              type: "Video",
                              container: $0.containerExtension ?? XtreamStreamKind.live.defaultExtension,
                              imagePath: $0.streamIcon)
                }
            }
            if parentId.hasPrefix(XtreamVirtualFolder.vodCatPrefix) {
                let catId = String(parentId.dropFirst(XtreamVirtualFolder.vodCatPrefix.count))
                return try await xtreamVodStreams(categoryId: catId).map {
                    MediaItem(id: "\(XtreamVirtualFolder.vodStreamPrefix)\($0.streamId)",
                              name: $0.name,
                              type: "Movie",
                              container: $0.containerExtension ?? XtreamStreamKind.movie.defaultExtension,
                              imagePath: $0.streamIcon)
                }
            }
            if parentId.hasPrefix(XtreamVirtualFolder.seriesCatPrefix) {
                let catId = String(parentId.dropFirst(XtreamVirtualFolder.seriesCatPrefix.count))
                return try await xtreamSeries(categoryId: catId).map {
                    MediaItem(id: "\(XtreamVirtualFolder.seriesShowPrefix)\($0.seriesId)",
                              name: $0.name,
                              type: "Series",
                              overview: $0.plot,
                              imagePath: $0.cover)
                }
            }
            return []
        }
    }

    // MARK: - Streams & images

    /// Builds an Xtream Codes stream URL: `{baseURL}/{live|movie|series}/{user}/{pass}/{id}.{ext}`.
    public func xtreamStreamURL(kind: XtreamStreamKind,
                                streamId: String,
                                containerExtension: String? = nil) throws -> URL {
        let username = try requireUser()
        let password = try requireToken()
        let rawExt = (containerExtension ?? kind.defaultExtension)
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let ext = rawExt.isEmpty ? kind.defaultExtension : rawExt
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var basePath = comps.path
        while basePath.hasSuffix("/") { basePath.removeLast() }
        let safeUser = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let safePass = password.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? password
        let safeId = streamId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? streamId
        comps.path = "\(basePath)/\(kind.rawValue)/\(safeUser)/\(safePass)/\(safeId).\(ext)"
        comps.queryItems = nil
        return comps.url!
    }

    /// Builds a Plex direct-play (`/library/parts/...`) or Universal HLS transcode URL.
    public func plexStreamURL(for item: MediaItem, mode: MediaStreamMode? = nil) throws -> URL {
        let token = try requireToken()
        let resolvedMode = mode ?? MediaStreamMode.preferred(for: item)
        if case .directPlay = resolvedMode,
           let partKey = item.mediaSources?.first?.id,
           partKey.hasPrefix("/") {
            return endpoint(partKey, query: [URLQueryItem(name: "X-Plex-Token", value: token)])
        }
        return endpoint("/video/:/transcode/universal/start.m3u8", query: [
            URLQueryItem(name: "path", value: "/library/metadata/\(item.id)"),
            URLQueryItem(name: "mediaIndex", value: "0"),
            URLQueryItem(name: "partIndex", value: "0"),
            URLQueryItem(name: "protocol", value: "hls"),
            URLQueryItem(name: "directPlay", value: "0"),
            URLQueryItem(name: "directStream", value: "1"),
            URLQueryItem(name: "X-Plex-Client-Identifier", value: deviceId),
            URLQueryItem(name: "X-Plex-Product", value: Self.clientName),
            URLQueryItem(name: "X-Plex-Token", value: token)
        ])
    }

    /// Playable URL with auth token/credentials so AVPlayer needs no custom headers.
    public func streamURL(for item: MediaItem, mode: MediaStreamMode? = nil, playSessionId: String? = nil) throws -> URL {
        switch kind {
        case .jellyfin, .emby:
            let token = try requireToken()
            let mediaSourceId = item.mediaSources?.first?.id ?? item.id
            var query = [
                URLQueryItem(name: "MediaSourceId", value: mediaSourceId),
                URLQueryItem(name: "DeviceId", value: deviceId),
                URLQueryItem(name: "api_key", value: token)
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

        case .plex:
            return try plexStreamURL(for: item, mode: mode)

        case .xtream:
            if item.id.hasPrefix(XtreamVirtualFolder.liveStreamPrefix) {
                let sid = String(item.id.dropFirst(XtreamVirtualFolder.liveStreamPrefix.count))
                return try xtreamStreamURL(kind: .live, streamId: sid, containerExtension: item.container)
            }
            if item.id.hasPrefix(XtreamVirtualFolder.vodStreamPrefix) {
                let sid = String(item.id.dropFirst(XtreamVirtualFolder.vodStreamPrefix.count))
                return try xtreamStreamURL(kind: .movie, streamId: sid, containerExtension: item.container)
            }
            if item.id.hasPrefix(XtreamVirtualFolder.episodePrefix) {
                let sid = String(item.id.dropFirst(XtreamVirtualFolder.episodePrefix.count))
                return try xtreamStreamURL(kind: .series, streamId: sid, containerExtension: item.container)
            }
            let defaultKind: XtreamStreamKind = item.type == "Movie" ? .movie : (item.type == "Episode" ? .series : .live)
            return try xtreamStreamURL(kind: defaultKind, streamId: item.id, containerExtension: item.container)
        }
    }

    public func imageURL(for item: MediaItem, maxWidth: Int = 400) -> URL? {
        switch kind {
        case .jellyfin, .emby:
            guard let tag = item.imageTags?["Primary"] else { return nil }
            return endpoint("/Items/\(item.id)/Images/Primary", query: [
                URLQueryItem(name: "maxWidth", value: String(maxWidth)),
                URLQueryItem(name: "tag", value: tag),
                URLQueryItem(name: "quality", value: "90")
            ])
        case .plex:
            guard let path = item.imagePath, !path.isEmpty, let token = accessToken else { return nil }
            if path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://") {
                return URL(string: path)
            }
            let normalized = path.hasPrefix("/") ? path : "/\(path)"
            return endpoint(normalized, query: [URLQueryItem(name: "X-Plex-Token", value: token)])
        case .xtream:
            guard let path = item.imagePath, !path.isEmpty,
                  let url = URL(string: path),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else { return nil }
            return url
        }
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
        switch kind {
        case .jellyfin, .emby:
            _ = try requireUser()
            let body = try encoder.encode(report)
            try await send(request(endpoint(event.rawValue), method: "POST", body: body))
        case .plex:
            let token = try requireToken()
            let state: String
            switch event {
            case .stopped: state = "stopped"
            case .start, .progress: state = report.isPaused ? "paused" : "playing"
            }
            let timeMs = MediaTicks.milliseconds(fromTicks: report.positionTicks)
            let url = endpoint("/:/timeline", query: [
                URLQueryItem(name: "ratingKey", value: report.itemId),
                URLQueryItem(name: "key", value: "/library/metadata/\(report.itemId)"),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "time", value: String(timeMs)),
                URLQueryItem(name: "X-Plex-Token", value: token)
            ])
            _ = try await send(request(url))
        case .xtream:
            break
        }
    }
}
