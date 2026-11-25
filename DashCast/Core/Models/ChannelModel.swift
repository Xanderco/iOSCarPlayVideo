import Foundation

public struct ChannelModel: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var streamURL: URL
    public var groupTitle: String
    public var logoURL: URL?
    public var tvgID: String?
    public var isFavorite: Bool
    public var lastWatched: Date?

    public init(
        id: String = UUID().uuidString,
        name: String,
        streamURL: URL,
        groupTitle: String = "General",
        logoURL: URL? = nil,
        tvgID: String? = nil,
        isFavorite: Bool = false,
        lastWatched: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.groupTitle = groupTitle
        self.logoURL = logoURL
        self.tvgID = tvgID
        self.isFavorite = isFavorite
        self.lastWatched = lastWatched
    }
}

public struct IPTVPlaylist: Codable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var url: URL?
    public var epgURL: URL?
    public var channels: [ChannelModel]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        url: URL? = nil,
        epgURL: URL? = nil,
        channels: [ChannelModel] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.epgURL = epgURL
        self.channels = channels
        self.createdAt = createdAt
    }
}
