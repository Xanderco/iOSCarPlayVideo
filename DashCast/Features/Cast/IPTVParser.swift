import Foundation

public struct IPTVParser {
    public static func parseM3U(content: String) -> [ChannelModel] {
        var channels: [ChannelModel] = []
        let lines = content.components(separatedBy: .newlines)

        var currentName: String?
        var currentGroup = "General"
        var currentLogo: URL?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("#EXTINF:") {
                // Parse attributes: tvg-name, tvg-logo, group-title, and channel display title
                currentGroup = extractAttribute(named: "group-title", from: trimmed) ?? "General"

                if let logoStr = extractAttribute(named: "tvg-logo", from: trimmed),
                   let logoURL = URL(string: logoStr) {
                    currentLogo = logoURL
                } else {
                    currentLogo = nil
                }

                // Extract name after the last comma
                if let commaIndex = trimmed.lastIndex(of: ",") {
                    let titlePart = trimmed[trimmed.index(after: commaIndex)...].trimmingCharacters(in: .whitespaces)
                    if !titlePart.isEmpty {
                        currentName = titlePart
                    }
                }

                if currentName == nil {
                    currentName = extractAttribute(named: "tvg-name", from: trimmed) ?? "Channel \(channels.count + 1)"
                }
            } else if !trimmed.hasPrefix("#") {
                // This is the stream URL line
                if let streamURL = URL(string: trimmed), let name = currentName {
                    let channel = ChannelModel(
                        id: UUID().uuidString,
                        name: name,
                        streamURL: streamURL,
                        groupTitle: currentGroup,
                        logoURL: currentLogo
                    )
                    channels.append(channel)
                }
                // Reset for next channel
                currentName = nil
                currentGroup = "General"
                currentLogo = nil
            }
        }

        return channels
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
