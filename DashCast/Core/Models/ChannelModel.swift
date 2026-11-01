import Foundation

public struct ChannelModel: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var streamURL: URL
    public var groupTitle: String
    public var logoURL: URL?
    public var isFavorite: Bool
    public var lastWatched: Date?

    public init(
        id: String = UUID().uuidString,
        name: String,
        streamURL: URL,
        groupTitle: String = "General",
        logoURL: URL? = nil,
        isFavorite: Bool = false,
        lastWatched: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.groupTitle = groupTitle
        self.logoURL = logoURL
        self.isFavorite = isFavorite
        self.lastWatched = lastWatched
    }
}

public struct IPTVPlaylist: Codable, Identifiable {
    public var id: UUID
    public var title: String
    public var url: URL?
    public var channels: [ChannelModel]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        url: URL? = nil,
        channels: [ChannelModel] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.channels = channels
        self.createdAt = createdAt
    }
}
