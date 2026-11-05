import Foundation

/// Which flavour of MediaBrowser-style server we are talking to.
/// Jellyfin is a fork of Emby, so the REST APIs are nearly identical; the
/// differences we care about are the auth header name and the URL prefix.
public enum MediaServerKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case jellyfin
    case emby

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .jellyfin: return "Jellyfin"
        case .emby: return "Emby"
        }
    }

    /// Emby serves its API under `/emby`; Jellyfin serves it at the root.
    var apiPathPrefix: String {
        switch self {
        case .jellyfin: return ""
        case .emby: return "/emby"
        }
    }

    /// Jellyfin 10.9+ expects the standard `Authorization` header; Emby uses `X-Emby-Authorization`.
    var authorizationHeaderName: String {
        switch self {
        case .jellyfin: return "Authorization"
        case .emby: return "X-Emby-Authorization"
        }
    }
}

/// A saved server login. The access token is deliberately NOT part of this
/// struct: it lives only in the Keychain (see `MediaServerTokenStore`).
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

/// A library ("view"), movie, series, season or episode.
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
