import Foundation

/// Which flavour of media server we are talking to.
/// Jellyfin and Emby share the MediaBrowser REST API; Plex uses its XML/JSON
/// MediaContainer API with `X-Plex-Token`; Xtream Codes uses `player_api.php`.
public enum MediaServerKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case jellyfin
    case emby
    case plex
    case xtream

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .jellyfin: return "Jellyfin"
        case .emby: return "Emby"
        case .plex: return "Plex"
        case .xtream: return "Xtream Codes"
        }
    }

    /// Compact label suitable for segmented pickers.
    public var pickerLabel: String {
        switch self {
        case .jellyfin: return "Jellyfin"
        case .emby: return "Emby"
        case .plex: return "Plex"
        case .xtream: return "Xtream"
        }
    }

    public var defaultAddressPlaceholder: String {
        switch self {
        case .jellyfin, .emby: return "http://192.168.1.10:8096"
        case .plex: return "http://192.168.1.10:32400"
        case .xtream: return "http://iptv.example.com:8080"
        }
    }

    /// Emby serves its API under `/emby`; Jellyfin, Plex, and Xtream serve at the root.
    var apiPathPrefix: String {
        switch self {
        case .emby: return "/emby"
        case .jellyfin, .plex, .xtream: return ""
        }
    }

    /// Auth header name used by header-authenticated servers.
    var authorizationHeaderName: String {
        switch self {
        case .jellyfin, .xtream: return "Authorization"
        case .emby: return "X-Emby-Authorization"
        case .plex: return "X-Plex-Token"
        }
    }

    var isMediaBrowser: Bool {
        self == .jellyfin || self == .emby
    }
}

/// A saved server login. Secrets (access tokens, `X-Plex-Token`, and Xtream
/// passwords) are deliberately NOT part of this struct: they live only in the
/// Keychain (see `MediaServerTokenStore`).
public struct MediaServerAccount: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: MediaServerKind
    public var baseURL: URL
    public var serverName: String
    public var serverId: String?
    public var username: String
    public var userId: String
    public var deviceId: String

    public init(id: UUID = UUID(),
                kind: MediaServerKind,
                baseURL: URL,
                serverName: String,
                serverId: String? = nil,
                username: String,
                userId: String,
                deviceId: String) {
        self.id = id
        self.kind = kind
        self.baseURL = baseURL
        self.serverName = serverName
        self.serverId = serverId
        self.username = username
        self.userId = userId
        self.deviceId = deviceId
    }
}

// MARK: - Wire DTOs (PascalCase JSON as returned by Jellyfin / Emby)

public struct MediaAuthResult: Decodable, Sendable {
    public struct User: Decodable, Sendable {
        public let id: String
        public let name: String?

        enum CodingKeys: String, CodingKey {
            case id = "Id"
            case name = "Name"
        }
    }

    public let user: User
    public let accessToken: String
    public let serverId: String?

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case accessToken = "AccessToken"
        case serverId = "ServerId"
    }
}

public struct MediaPublicSystemInfo: Decodable, Sendable {
    public let serverName: String?
    public let id: String?
    public let version: String?

    enum CodingKeys: String, CodingKey {
        case serverName = "ServerName"
        case id = "Id"
        case version = "Version"
    }
}

public struct MediaItemsResponse: Decodable, Sendable {
    public let items: [MediaItem]
    public let totalRecordCount: Int?

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}

public struct MediaUserData: Codable, Hashable, Sendable {
    public var playbackPositionTicks: Int64?
    public var played: Bool?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case played = "Played"
    }

    public init(playbackPositionTicks: Int64? = nil, played: Bool? = nil) {
        self.playbackPositionTicks = playbackPositionTicks
        self.played = played
    }
}

public struct MediaSourceInfo: Codable, Hashable, Sendable {
    public var id: String?
    public var container: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case container = "Container"
    }

    public init(id: String? = nil, container: String? = nil) {
        self.id = id
        self.container = container
    }
}

/// A library ("view"), category, movie, series, season, episode or live stream.
public struct MediaItem: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var type: String?
    public var collectionType: String?
    public var seriesId: String?
    public var seriesName: String?
    public var seasonId: String?
    public var indexNumber: Int?
    public var parentIndexNumber: Int?
    public var productionYear: Int?
    public var runTimeTicks: Int64?
    public var overview: String?
    public var container: String?
    public var imageTags: [String: String]?
    public var imagePath: String?
    public var userData: MediaUserData?
    public var mediaSources: [MediaSourceInfo]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case collectionType = "CollectionType"
        case seriesId = "SeriesId"
        case seriesName = "SeriesName"
        case seasonId = "SeasonId"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case productionYear = "ProductionYear"
        case runTimeTicks = "RunTimeTicks"
        case overview = "Overview"
        case container = "Container"
        case imageTags = "ImageTags"
        case imagePath = "ImagePath"
        case userData = "UserData"
        case mediaSources = "MediaSources"
    }

    public init(id: String,
                name: String,
                type: String? = nil,
                collectionType: String? = nil,
                seriesId: String? = nil,
                seriesName: String? = nil,
                seasonId: String? = nil,
                indexNumber: Int? = nil,
                parentIndexNumber: Int? = nil,
                productionYear: Int? = nil,
                runTimeTicks: Int64? = nil,
                overview: String? = nil,
                container: String? = nil,
                imageTags: [String: String]? = nil,
                imagePath: String? = nil,
                userData: MediaUserData? = nil,
                mediaSources: [MediaSourceInfo]? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.collectionType = collectionType
        self.seriesId = seriesId
        self.seriesName = seriesName
        self.seasonId = seasonId
        self.indexNumber = indexNumber
        self.parentIndexNumber = parentIndexNumber
        self.productionYear = productionYear
        self.runTimeTicks = runTimeTicks
        self.overview = overview
        self.container = container
        self.imageTags = imageTags
        self.imagePath = imagePath
        self.userData = userData
        self.mediaSources = mediaSources
    }

    public var isSeries: Bool { type == "Series" }
    public var isFolder: Bool { type == "Folder" || type == "BoxSet" || type == "CollectionFolder" }
    public var isPlayable: Bool { type == "Movie" || type == "Episode" || type == "Video" || type == "MusicVideo" }

    /// Saved resume position in seconds (server ticks are 100ns units).
    public var resumePositionSeconds: Double {
        guard let ticks = userData?.playbackPositionTicks, ticks > 0 else { return 0 }
        return MediaTicks.seconds(fromTicks: ticks)
    }

    public var runtimeSeconds: Double? {
        runTimeTicks.map(MediaTicks.seconds(fromTicks:))
    }

    /// "S1E3" style label for episodes.
    public var episodeLabel: String? {
        guard type == "Episode" else { return nil }
        switch (parentIndexNumber, indexNumber) {
        case let (s?, e?): return "S\(s)E\(e)"
        case let (nil, e?): return "E\(e)"
        default: return nil
        }
    }
}

public enum MediaTicks {
    public static let perSecond: Int64 = 10_000_000

    public static func seconds(fromTicks ticks: Int64) -> Double {
        Double(ticks) / Double(perSecond)
    }

    public static func ticks(fromSeconds seconds: Double) -> Int64 {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int64((seconds * Double(perSecond)).rounded())
    }

    public static func ticks(fromMilliseconds ms: Int64) -> Int64 {
        guard ms > 0 else { return 0 }
        return ms * 10_000
    }

    public static func milliseconds(fromTicks ticks: Int64) -> Int64 {
        guard ticks > 0 else { return 0 }
        return ticks / 10_000
    }
}

/// Episodes bucketed under their season, in season order (empty seasons dropped).
public struct MediaSeasonGroup: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let episodes: [MediaItem]

    /// Groups already-sorted episodes under their season.
    public static func group(episodes: [MediaItem], seasons: [MediaItem]) -> [MediaSeasonGroup] {
        var order: [String] = seasons.map(\.id)
        var titles: [String: String] = Dictionary(seasons.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        var buckets: [String: [MediaItem]] = [:]
        for episode in episodes {
            let key = episode.seasonId ?? "season-\(episode.parentIndexNumber ?? -1)"
            if titles[key] == nil {
                titles[key] = episode.parentIndexNumber.map { "Season \($0)" } ?? "Episodes"
                order.append(key)
            }
            buckets[key, default: []].append(episode)
        }
        return order.compactMap { key in
            guard let list = buckets[key], !list.isEmpty else { return nil }
            return MediaSeasonGroup(id: key, title: titles[key] ?? "Episodes", episodes: list)
        }
    }
}

// MARK: - Xtream Codes DTOs

public enum XtreamStreamKind: String, Codable, Sendable {
    case live
    case movie
    case series

    var defaultExtension: String {
        switch self {
        case .live: return "m3u8"
        case .movie, .series: return "mp4"
        }
    }
}

/// Decodes JSON fields that Xtream panels inconsistently emit as either `String` or `Int`.
private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: Key) -> String? {
        if let str = try? decodeIfPresent(String.self, forKey: key) { return str }
        if let int = try? decodeIfPresent(Int.self, forKey: key) { return String(int) }
        return nil
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) -> Int? {
        if let int = try? decodeIfPresent(Int.self, forKey: key) { return int }
        if let str = try? decodeIfPresent(String.self, forKey: key) { return Int(str) }
        return nil
    }
}

public struct XtreamAuthResponse: Decodable, Sendable {
    public struct UserInfo: Decodable, Sendable {
        public let username: String?
        public let status: String?
        public let auth: Int?
        public let expDate: String?
        public let maxConnections: String?

        enum CodingKeys: String, CodingKey {
            case username
            case status
            case auth
            case expDate = "exp_date"
            case maxConnections = "max_connections"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            username = c.decodeFlexibleStringIfPresent(forKey: .username)
            status = c.decodeFlexibleStringIfPresent(forKey: .status)
            auth = c.decodeFlexibleIntIfPresent(forKey: .auth)
            expDate = c.decodeFlexibleStringIfPresent(forKey: .expDate)
            maxConnections = c.decodeFlexibleStringIfPresent(forKey: .maxConnections)
        }
    }

    public struct ServerInfo: Decodable, Sendable {
        public let url: String?
        public let port: String?
        public let httpsPort: String?
        public let serverProtocol: String?

        enum CodingKeys: String, CodingKey {
            case url
            case port
            case httpsPort = "https_port"
            case serverProtocol = "server_protocol"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            url = c.decodeFlexibleStringIfPresent(forKey: .url)
            port = c.decodeFlexibleStringIfPresent(forKey: .port)
            httpsPort = c.decodeFlexibleStringIfPresent(forKey: .httpsPort)
            serverProtocol = c.decodeFlexibleStringIfPresent(forKey: .serverProtocol)
        }
    }

    public let userInfo: UserInfo?
    public let serverInfo: ServerInfo?

    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case serverInfo = "server_info"
    }

    public var isAuthorized: Bool {
        guard let userInfo else { return false }
        if let auth = userInfo.auth { return auth == 1 }
        return userInfo.status?.lowercased() == "active"
    }
}

public struct XtreamCategory: Decodable, Identifiable, Hashable, Sendable {
    public let categoryId: String
    public let categoryName: String
    public let parentId: Int?

    public var id: String { categoryId }

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
        case parentId = "parent_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let cid = c.decodeFlexibleStringIfPresent(forKey: .categoryId),
              let name = c.decodeFlexibleStringIfPresent(forKey: .categoryName) else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "Missing Xtream category fields"))
        }
        categoryId = cid
        categoryName = name
        parentId = c.decodeFlexibleIntIfPresent(forKey: .parentId)
    }
}

public struct XtreamLiveStream: Decodable, Identifiable, Hashable, Sendable {
    public let streamId: String
    public let name: String
    public let streamIcon: String?
    public let categoryId: String?
    public let epgChannelId: String?
    public let containerExtension: String?

    public var id: String { streamId }

    enum CodingKeys: String, CodingKey {
        case streamId = "stream_id"
        case name
        case streamIcon = "stream_icon"
        case categoryId = "category_id"
        case epgChannelId = "epg_channel_id"
        case containerExtension = "container_extension"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let sid = c.decodeFlexibleStringIfPresent(forKey: .streamId),
              let title = c.decodeFlexibleStringIfPresent(forKey: .name) else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "Missing Xtream live stream fields"))
        }
        streamId = sid
        name = title
        streamIcon = c.decodeFlexibleStringIfPresent(forKey: .streamIcon)
        categoryId = c.decodeFlexibleStringIfPresent(forKey: .categoryId)
        epgChannelId = c.decodeFlexibleStringIfPresent(forKey: .epgChannelId)
        containerExtension = c.decodeFlexibleStringIfPresent(forKey: .containerExtension)
    }
}

public struct XtreamVodStream: Decodable, Identifiable, Hashable, Sendable {
    public let streamId: String
    public let name: String
    public let streamIcon: String?
    public let categoryId: String?
    public let containerExtension: String?

    public var id: String { streamId }

    enum CodingKeys: String, CodingKey {
        case streamId = "stream_id"
        case name
        case streamIcon = "stream_icon"
        case categoryId = "category_id"
        case containerExtension = "container_extension"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let sid = c.decodeFlexibleStringIfPresent(forKey: .streamId),
              let title = c.decodeFlexibleStringIfPresent(forKey: .name) else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "Missing Xtream VOD fields"))
        }
        streamId = sid
        name = title
        streamIcon = c.decodeFlexibleStringIfPresent(forKey: .streamIcon)
        categoryId = c.decodeFlexibleStringIfPresent(forKey: .categoryId)
        containerExtension = c.decodeFlexibleStringIfPresent(forKey: .containerExtension)
    }
}

public struct XtreamSeries: Decodable, Identifiable, Hashable, Sendable {
    public let seriesId: String
    public let name: String
    public let cover: String?
    public let plot: String?
    public let categoryId: String?

    public var id: String { seriesId }

    enum CodingKeys: String, CodingKey {
        case seriesId = "series_id"
        case name
        case cover
        case plot
        case categoryId = "category_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let sid = c.decodeFlexibleStringIfPresent(forKey: .seriesId),
              let title = c.decodeFlexibleStringIfPresent(forKey: .name) else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "Missing Xtream series fields"))
        }
        seriesId = sid
        name = title
        cover = c.decodeFlexibleStringIfPresent(forKey: .cover)
        plot = c.decodeFlexibleStringIfPresent(forKey: .plot)
        categoryId = c.decodeFlexibleStringIfPresent(forKey: .categoryId)
    }
}

public struct XtreamSeason: Decodable, Identifiable, Hashable, Sendable {
    public let seasonNumber: Int
    public let name: String?

    public var id: Int { seasonNumber }

    enum CodingKeys: String, CodingKey {
        case seasonNumber = "season_number"
        case name
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seasonNumber = c.decodeFlexibleIntIfPresent(forKey: .seasonNumber) ?? 0
        name = c.decodeFlexibleStringIfPresent(forKey: .name)
    }
}

public struct XtreamEpisode: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let episodeNum: Int?
    public let season: Int?
    public let title: String
    public let containerExtension: String?

    enum CodingKeys: String, CodingKey {
        case id
        case episodeNum = "episode_num"
        case season
        case title
        case containerExtension = "container_extension"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let eid = c.decodeFlexibleStringIfPresent(forKey: .id) else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "Missing Xtream episode id"))
        }
        id = eid
        episodeNum = c.decodeFlexibleIntIfPresent(forKey: .episodeNum)
        season = c.decodeFlexibleIntIfPresent(forKey: .season)
        title = c.decodeFlexibleStringIfPresent(forKey: .title) ?? "Episode \(eid)"
        containerExtension = c.decodeFlexibleStringIfPresent(forKey: .containerExtension)
    }
}

public struct XtreamSeriesInfo: Decodable, Sendable {
    public struct Info: Decodable, Sendable {
        public let name: String?
        public let plot: String?
        public let cover: String?
    }

    public let seasons: [XtreamSeason]?
    public let episodes: [String: [XtreamEpisode]]?
    public let info: Info?
}

// MARK: - Plex DTOs

public struct PlexMediaContainerResponse<Container: Decodable & Sendable>: Decodable, Sendable {
    public let mediaContainer: Container

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

public struct PlexServerIdentityContainer: Decodable, Sendable {
    public let friendlyName: String?
    public let machineIdentifier: String?
    public let version: String?
    public let myPlexUsername: String?
}

public struct PlexDirectory: Decodable, Identifiable, Hashable, Sendable {
    public let key: String
    public let title: String
    public let type: String?
    public let thumb: String?

    public var id: String { key }

    public func toMediaItem() -> MediaItem {
        let mappedCollection: String?
        switch type?.lowercased() {
        case "movie": mappedCollection = "movies"
        case "show": mappedCollection = "tvshows"
        case "artist": mappedCollection = "music"
        default: mappedCollection = type
        }
        return MediaItem(
            id: key,
            name: title,
            type: "CollectionFolder",
            collectionType: mappedCollection,
            imagePath: thumb
        )
    }
}

public struct PlexSectionsContainer: Decodable, Sendable {
    public let directory: [PlexDirectory]?

    enum CodingKeys: String, CodingKey {
        case directory = "Directory"
    }
}

public struct PlexPart: Decodable, Hashable, Sendable {
    public let id: Int?
    public let key: String
    public let container: String?
}

public struct PlexMedia: Decodable, Hashable, Sendable {
    public let id: Int?
    public let container: String?
    public let videoCodec: String?
    public let audioCodec: String?
    public let parts: [PlexPart]?

    enum CodingKeys: String, CodingKey {
        case id
        case container
        case videoCodec
        case audioCodec
        case parts = "Part"
    }
}

public struct PlexMetadata: Decodable, Identifiable, Hashable, Sendable {
    public let ratingKey: String
    public let key: String?
    public let type: String?
    public let title: String
    public let summary: String?
    public let year: Int?
    public let duration: Int64?
    public let viewOffset: Int64?
    public let viewCount: Int?
    public let thumb: String?
    public let parentIndex: Int?
    public let index: Int?
    public let parentRatingKey: String?
    public let grandparentTitle: String?
    public let media: [PlexMedia]?

    public var id: String { ratingKey }

    enum CodingKeys: String, CodingKey {
        case ratingKey
        case key
        case type
        case title
        case summary
        case year
        case duration
        case viewOffset
        case viewCount
        case thumb
        case parentIndex
        case index
        case parentRatingKey
        case grandparentTitle
        case media = "Media"
    }

    public func toMediaItem() -> MediaItem {
        let normalizedType: String?
        switch type?.lowercased() {
        case "movie": normalizedType = "Movie"
        case "show": normalizedType = "Series"
        case "season": normalizedType = "Season"
        case "episode": normalizedType = "Episode"
        default: normalizedType = "Video"
        }

        let firstMedia = media?.first
        let firstPart = firstMedia?.parts?.first
        let container = firstPart?.container ?? firstMedia?.container
        let mediaSources = firstPart.map { [MediaSourceInfo(id: $0.key, container: container)] }
        let userData: MediaUserData? = (viewOffset != nil || viewCount != nil)
            ? MediaUserData(playbackPositionTicks: viewOffset.map(MediaTicks.ticks(fromMilliseconds:)),
                            played: (viewCount ?? 0) > 0)
            : nil

        return MediaItem(
            id: ratingKey,
            name: title,
            type: normalizedType,
            seriesName: grandparentTitle,
            seasonId: parentRatingKey,
            indexNumber: index,
            parentIndexNumber: parentIndex,
            productionYear: year,
            runTimeTicks: duration.map(MediaTicks.ticks(fromMilliseconds:)),
            overview: summary,
            container: container,
            imagePath: thumb,
            userData: userData,
            mediaSources: mediaSources
        )
    }
}

public struct PlexMetadataContainer: Decodable, Sendable {
    public let metadata: [PlexMetadata]?

    enum CodingKeys: String, CodingKey {
        case metadata = "Metadata"
    }
}
