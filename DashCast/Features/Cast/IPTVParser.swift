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
        var currentHeaders: [String: String] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let uppercased = trimmed.uppercased()
            if uppercased.hasPrefix("#EXTINF:") {
                currentGroup = extractAttribute(named: "group-title", from: trimmed)
                if let logoStr = extractAttribute(named: "tvg-logo", from: trimmed), !logoStr.isEmpty {
                    currentLogo = URL(string: logoStr)
                } else {
                    currentLogo = nil
                }
                let title = displayTitle(fromExtinf: trimmed)
                currentName = (title?.isEmpty == false ? title : nil)
                    ?? extractAttribute(named: "tvg-name", from: trimmed)
            } else if uppercased.hasPrefix("#EXTGRP:") {
                currentGroupFromTag = String(trimmed.dropFirst("#EXTGRP:".count)).trimmingCharacters(in: .whitespaces)
            } else if uppercased.hasPrefix("#EXTVLCOPT:") {
                let option = String(trimmed.dropFirst("#EXTVLCOPT:".count)).trimmingCharacters(in: .whitespaces)
                if let parsed = parseVLCOption(option) {
                    currentHeaders[parsed.key] = parsed.value
                }
            } else if uppercased.hasPrefix("#KODIPROP:") {
                let prop = String(trimmed.dropFirst("#KODIPROP:".count)).trimmingCharacters(in: .whitespaces)
                if let parsed = parseKodiStreamHeaders(prop) {
                    for (k, v) in parsed {
                        currentHeaders[k] = v
                    }
                }
            } else if !trimmed.hasPrefix("#") {
                let (rawURLPart, pipeHeaders) = splitStreamLineAndPipeHeaders(trimmed)
                var mergedHeaders = currentHeaders
                for (k, v) in pipeHeaders {
                    mergedHeaders[k] = v
                }
                if !rawURLPart.isEmpty, let streamURL = resolveStreamURL(rawURLPart, baseURL: baseURL) {
                    let name = currentName ?? streamURL.deletingPathExtension().lastPathComponent
                    let group = [currentGroup, currentGroupFromTag]
                        .compactMap { $0 }
                        .first { !$0.isEmpty } ?? "General"
                    channels.append(ChannelModel(
                        id: UUID().uuidString,
                        name: name.isEmpty ? "Channel \(channels.count + 1)" : name,
                        streamURL: streamURL,
                        groupTitle: group,
                        logoURL: currentLogo,
                        httpHeaders: mergedHeaders.isEmpty ? nil : mergedHeaders
                    ))
                }
                currentName = nil
                currentGroup = nil
                currentGroupFromTag = nil
                currentLogo = nil
                currentHeaders = [:]
            }
        }

        return channels
    }

    private static let canonicalHeaderNames: [String: String] = [
        "user-agent": "User-Agent",
        "http-user-agent": "User-Agent",
        "referer": "Referer",
        "referrer": "Referer",
        "http-referer": "Referer",
        "http-referrer": "Referer",
        "origin": "Origin",
        "http-origin": "Origin",
        "cookie": "Cookie",
        "http-cookie": "Cookie",
        "authorization": "Authorization"
    ]

    private static func normalizeHeaderKey(_ rawKey: String) -> String {
        let trimmed = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return canonicalHeaderNames[trimmed.lowercased()] ?? trimmed
    }

    private static func parseVLCOption(_ option: String) -> (key: String, value: String)? {
        guard let eqIndex = option.firstIndex(of: "=") else { return nil }
        let rawKey = String(option[..<eqIndex]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let supportedKeys: Set<String> = ["http-user-agent", "http-referrer", "http-referer", "http-origin", "http-cookie"]
        guard supportedKeys.contains(rawKey) else { return nil }
        let value = String(option[option.index(after: eqIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return (normalizeHeaderKey(rawKey), value)
    }

    private static func parseKodiStreamHeaders(_ prop: String) -> [String: String]? {
        let prefix = "inputstream.adaptive.stream_headers="
        guard prop.lowercased().hasPrefix(prefix) else { return nil }
        let query = String(prop.dropFirst(prefix.count))
        return parseHeaderPairs(query)
    }

    static func splitStreamLineAndPipeHeaders(_ rawLine: String) -> (urlPart: String, headers: [String: String]) {
        guard let pipeIndex = rawLine.firstIndex(of: "|") else {
            return (rawLine, [:])
        }
        let urlPart = String(rawLine[..<pipeIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let optionsPart = String(rawLine[rawLine.index(after: pipeIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (urlPart, parseHeaderPairs(optionsPart))
    }

    private static func parseHeaderPairs(_ query: String) -> [String: String] {
        var headers: [String: String] = [:]
        for pair in query.split(separator: "&") {
            guard let eqIndex = pair.firstIndex(of: "=") else { continue }
            let rawKey = String(pair[..<eqIndex])
            let rawValue = String(pair[pair.index(after: eqIndex)...])
            let decodedKey = (rawKey.removingPercentEncoding ?? rawKey).trimmingCharacters(in: .whitespacesAndNewlines)
            let decodedValue = (rawValue.removingPercentEncoding ?? rawValue).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !decodedKey.isEmpty, !decodedValue.isEmpty else { continue }
            headers[normalizeHeaderKey(decodedKey)] = decodedValue
        }
        return headers
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

    /// Demo content: only DashCast's own bundled videos. No third-party streams
    /// (App Review 5.2 — we must not ship content we don't own the rights to).
    public static var samplePlaylist: [ChannelModel] {
        let demos: [(resource: String, name: String)] = [
            ("night_drive", "Night Drive"),
            ("track_lap", "Track Lap")
        ]
        return demos.compactMap { demo in
            guard let url = Bundle.main.url(forResource: demo.resource, withExtension: "mp4") else { return nil }
            // Stable id so favorites, recents and SwiftUI identity survive re-reads.
            return ChannelModel(id: "demo.\(demo.resource)", name: demo.name, streamURL: url, groupTitle: "Demo Videos")
        }
    }
}
