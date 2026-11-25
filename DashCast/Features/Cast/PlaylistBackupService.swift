import Foundation

public struct PlaylistBackupPayload: Codable, Equatable, Sendable {
    public var version: Int
    public var exportedAt: Date
    public var playlists: [IPTVPlaylist]
    public var favoriteStreamURLs: [String]
    public var hiddenGroups: [String]

    public init(
        version: Int = PlaylistBackupService.currentVersion,
        exportedAt: Date = Date(),
        playlists: [IPTVPlaylist],
        favoriteStreamURLs: [String],
        hiddenGroups: [String]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.playlists = playlists
        self.favoriteStreamURLs = favoriteStreamURLs
        self.hiddenGroups = hiddenGroups
    }
}

public struct PlaylistBackupSummary: Equatable, Sendable {
    public var playlistsAdded: Int
    public var playlistsUpdated: Int
    public var favoritesAdded: Int
    public var hiddenGroupsAdded: Int

    public init(
        playlistsAdded: Int,
        playlistsUpdated: Int,
        favoritesAdded: Int,
        hiddenGroupsAdded: Int
    ) {
        self.playlistsAdded = playlistsAdded
        self.playlistsUpdated = playlistsUpdated
        self.favoritesAdded = favoritesAdded
        self.hiddenGroupsAdded = hiddenGroupsAdded
    }
}

public enum PlaylistBackupError: LocalizedError, Equatable {
    case invalidFormat
    case unsupportedVersion(Int)
    case emptyBackup

    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return String(localized: "That file isn't a valid DashCast playlist backup.")
        case .unsupportedVersion(let version):
            return String(localized: "Backup version \(version) isn't supported by this version of DashCast.")
        case .emptyBackup:
            return String(localized: "This backup doesn't contain any playlists, favorites, or hidden groups.")
        }
    }
}

/// Pure serialization helpers for playlist JSON backups and standard M3U exports.
public enum PlaylistBackupService {
    public static let currentVersion = 1

    public static func encodeBackup(
        playlists: [IPTVPlaylist],
        favoriteStreamURLs: [String],
        hiddenGroups: [String],
        exportedAt: Date = Date()
    ) throws -> Data {
        let payload = PlaylistBackupPayload(
            version: currentVersion,
            exportedAt: exportedAt,
            playlists: playlists,
            favoriteStreamURLs: favoriteStreamURLs.sorted(),
            hiddenGroups: hiddenGroups.sorted()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    public static func decodeBackup(from data: Data) throws -> PlaylistBackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload: PlaylistBackupPayload
        do {
            payload = try decoder.decode(PlaylistBackupPayload.self, from: data)
        } catch {
            throw PlaylistBackupError.invalidFormat
        }

        guard payload.version == currentVersion else {
            throw PlaylistBackupError.unsupportedVersion(payload.version)
        }

        guard !payload.playlists.isEmpty
            || !payload.favoriteStreamURLs.isEmpty
            || !payload.hiddenGroups.isEmpty else {
            throw PlaylistBackupError.emptyBackup
        }

        return payload
    }

    public static func exportM3U(playlist: IPTVPlaylist) -> String {
        var lines: [String] = ["#EXTM3U"]
        for channel in playlist.channels {
            let group = sanitizeAttributeValue(channel.groupTitle.isEmpty ? "General" : channel.groupTitle)
            let name = channel.name
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            var extinf = "#EXTINF:-1 group-title=\"\(group)\""
            if let logo = channel.logoURL {
                extinf += " tvg-logo=\"\(sanitizeAttributeValue(logo.absoluteString))\""
            }
            extinf += ",\(name.isEmpty ? channel.streamURL.lastPathComponent : name)"
            lines.append(extinf)
            lines.append(channel.streamURL.absoluteString)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func sanitizedFilename(from rawTitle: String, fallback: String = "playlist") -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = rawTitle.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let collapsed = String(mapped).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return collapsed.isEmpty ? fallback : collapsed
    }

    public static func writeTemporaryFile(data: Data, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func sanitizeAttributeValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
