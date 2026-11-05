import Foundation

public struct IPTVParser {
    /// Decodes playlist bytes, tolerating a UTF-8 BOM and Latin-1 files.
    public static func decode(_ data: Data) -> String? {
        var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        if text?.hasPrefix("\u{FEFF}") == true { text?.removeFirst() }
        return text
    }

    /// Parses an extended M3U / M3U8 playlist.
    /// - Parameter baseURL: where the playlist came from; used to resolve relative stream paths.
    public static func parseM3U(content: String, baseURL: URL? = nil) -> [ChannelModel] {
        var channels: [ChannelModel] = []
        var text = content
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let lines = text.components(separatedBy: .newlines)

        var currentName: String?
        var currentGroup: String?
        var currentLogo: URL?
        var currentGroupFromTag: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if trimmed.uppercased().hasPrefix("#EXTINF:") {
                currentGroup = extractAttribute(named: "group-title", from: trimmed)
                if let logoStr = extractAttribute(named: "tvg-logo", from: trimmed), !logoStr.isEmpty {
                    currentLogo = URL(string: logoStr)
                } else {
                    currentLogo = nil
                }
                let title = displayTitle(fromExtinf: trimmed)
                currentName = (title?.isEmpty == false ? title : nil)
                    ?? extractAttribute(named: "tvg-name", from: trimmed)
            } else if trimmed.uppercased().hasPrefix("#EXTGRP:") {
                currentGroupFromTag = String(trimmed.dropFirst("#EXTGRP:".count)).trimmingCharacters(in: .whitespaces)
            } else if !trimmed.hasPrefix("#") {
                if let streamURL = resolveStreamURL(trimmed, baseURL: baseURL) {
                    let name = currentName ?? streamURL.deletingPathExtension().lastPathComponent
                    let group = [currentGroup, currentGroupFromTag]
                        .compactMap { $0 }
                        .first { !$0.isEmpty } ?? "General"
                    channels.append(ChannelModel(
                        id: UUID().uuidString,
                        name: name.isEmpty ? "Channel \(channels.count + 1)" : name,
                        streamURL: streamURL,
                        groupTitle: group,
                        logoURL: currentLogo
                    ))
                }
                currentName = nil
                currentGroup = nil
                currentGroupFromTag = nil
                currentLogo = nil
            }
        }

        return channels
    }

    /// The display title is everything after the first comma that is not inside quotes.
    static func displayTitle(fromExtinf line: String) -> String? {
        var inQuotes = false
        for index in line.indices {
            let ch = line[index]
            if ch == "\"" { inQuotes.toggle() }
            if ch == "," && !inQuotes {
                return line[line.index(after: index)...].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    static func resolveStreamURL(_ raw: String, baseURL: URL?) -> URL? {
        let cleaned = raw.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed.union(["#", "%"])) ?? raw
        if let url = URL(string: raw) ?? URL(string: cleaned), url.scheme != nil {
            return url
        }
        if let baseURL, let relative = URL(string: cleaned, relativeTo: baseURL) {
            return relative.absoluteURL
        }
        return nil
    }

    private static func extractAttribute(named name: String, from line: String) -> String? {
        let pattern = "\(name)=\"([^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsString = line as NSString
            let results = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))
            if let first = results.first, first.numberOfRanges > 1 {
                return nsString.substring(with: first.range(at: 1))
            }
        }
        return nil
    }

    public static var samplePlaylist: [ChannelModel] {
        var list: [ChannelModel] = []

        // 1. Real Bundled Automotive Test Video #1
        if let nightDriveURL = Bundle.main.url(forResource: "night_drive", withExtension: "mp4") {
            list.append(
                ChannelModel(
                    name: "Night Highway Drive (Bundled 1080p)",
                    streamURL: nightDriveURL,
                    groupTitle: "Movies"
                )
            )
        } else {
            list.append(
                ChannelModel(
                    name: "Night Highway Drive (Sample 1080p)",
                    streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4")!,
                    groupTitle: "Movies"
                )
            )
        }

        // 2. Real Bundled Automotive Test Video #2
        if let trackLapURL = Bundle.main.url(forResource: "track_lap", withExtension: "mp4") {
            list.append(
                ChannelModel(
                    name: "Supercar Track Lap (Bundled 1080p)",
                    streamURL: trackLapURL,
                    groupTitle: "Sports"
                )
            )
        } else {
            list.append(
                ChannelModel(
                    name: "Supercar Track Lap (Sample 1080p)",
                    streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!,
                    groupTitle: "Sports"
                )
            )
        }

        // 3. Online HLS Streams
        list.append(
            ChannelModel(
                name: "Tears of Steel (4K Sci-Fi)",
                streamURL: URL(string: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8")!,
                groupTitle: "Movies"
            )
        )
        list.append(
            ChannelModel(
                name: "NASA TV Live Feed",
                streamURL: URL(string: "https://ntv1.akamaized.net/hls/live/2014075/NASA-NTV1-HLS/master.m3u8")!,
                groupTitle: "Live"
            )
        )
        list.append(
            ChannelModel(
                name: "Red Bull Motorsports",
                streamURL: URL(string: "https://rbmn-live.akamaized.net/hls/live/590964/BoRB-AT/master.m3u8")!,
                groupTitle: "Sports"
            )
        )

        return list
    }
}
