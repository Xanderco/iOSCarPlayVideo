import Foundation
import AVFoundation

/// Normalized container classification for stream URLs and server metadata.
public enum MediaContainerKind: String, CaseIterable, Equatable, Sendable {
    case mp4
    case m4v
    case mov
    case hls
    case mkv
    case avi
    case webm
    case flv
    case ts
    case wmv
    case ogg
    case unknown

    /// True when iOS `AVPlayer` can generally demux this container natively.
    public var isNativelySupportedByAVPlayer: Bool {
        switch self {
        case .mp4, .m4v, .mov, .hls:
            return true
        case .mkv, .avi, .webm, .flv, .ts, .wmv, .ogg, .unknown:
            return false
        }
    }

    /// True when the container is a known format that iOS `AVPlayer` does not play natively as a standalone file/stream.
    public var isUnsupportedContainer: Bool {
        switch self {
        case .mkv, .avi, .webm, .flv, .ts, .wmv, .ogg:
            return true
        case .mp4, .m4v, .mov, .hls, .unknown:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .mp4: return "MP4"
        case .m4v: return "M4V"
        case .mov: return "QuickTime MOV"
        case .hls: return "HLS"
        case .mkv: return "MKV"
        case .avi: return "AVI"
        case .webm: return "WebM"
        case .flv: return "FLV"
        case .ts: return "MPEG-TS"
        case .wmv: return "WMV"
        case .ogg: return "Ogg"
        case .unknown: return "Stream"
        }
    }
}

/// Diagnostic result produced when inspecting a stream URL and/or AVPlayer failure.
public struct MediaContainerProbeResult: Equatable, Sendable {
    public let container: MediaContainerKind
    public let isNativeContainer: Bool
    public let isDecodeFailure: Bool
    public let canOfferServerTranscode: Bool
    public let userFacingReason: String
    public let technicalCause: String

    public init(container: MediaContainerKind,
                isNativeContainer: Bool,
                isDecodeFailure: Bool,
                canOfferServerTranscode: Bool,
                userFacingReason: String,
                technicalCause: String) {
        self.container = container
        self.isNativeContainer = isNativeContainer
        self.isDecodeFailure = isDecodeFailure
        self.canOfferServerTranscode = canOfferServerTranscode
        self.userFacingReason = userFacingReason
        self.technicalCause = technicalCause
    }
}

/// Classifies stream URLs/containers and translates AVFoundation decode errors into actionable guidance.
public enum MediaContainerProbe: Sendable {
    public static let unsupportedExtensions: Set<String> = [
        "mkv", "avi", "webm", "flv", "ts", "wmv", "ogg", "ogv", "divx", "xvid", "matroska", "asf", "mpegts"
    ]

    public static let nativeExtensions: Set<String> = [
        "mp4", "m4v", "mov", "m3u8", "m3u"
    ]

    /// Maps a URL and optional server-reported container string to a `MediaContainerKind`.
    public static func classify(url: URL, explicitContainer: String? = nil) -> MediaContainerKind {
        if isHLSURL(url) {
            return .hls
        }

        if let explicitContainer, let mapped = classifyContainerTokenList(explicitContainer) {
            return mapped
        }

        let ext = url.pathExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
        if !ext.isEmpty, let mapped = mapToken(ext) {
            return mapped
        }

        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let items = comps.queryItems {
            for key in ["Container", "container", "format", "ext"] {
                if let value = items.first(where: { $0.name == key })?.value,
                   let mapped = classifyContainerTokenList(value) {
                    return mapped
                }
            }
        }

        return .unknown
    }

    /// True if the URL points to an HLS playlist or server HLS transcode endpoint.
    public static func isHLSURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext == "m3u8" || ext == "m3u" {
            return true
        }
        let lowerPath = url.path.lowercased()
        if lowerPath.hasSuffix("/master.m3u8") || lowerPath.hasSuffix("/start.m3u8") {
            return true
        }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let proto = comps.queryItems?.first(where: { $0.name.lowercased() == "protocol" })?.value?.lowercased(),
           proto == "hls" {
            return true
        }
        return false
    }

    /// True if `error` or any underlying error is a network transport error (`NSURLErrorDomain`).
    public static func isNetworkError(_ error: Error) -> Bool {
        var current: NSError? = error as NSError
        var visited = Set<ObjectIdentifier>()
        while let ns = current, visited.insert(ObjectIdentifier(ns)).inserted {
            if ns.domain == NSURLErrorDomain {
                return true
            }
            current = ns.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }

    /// True if `error` indicates a container demux or codec decode failure from AVFoundation / CoreMedia.
    public static func isAVFoundationDecodeError(_ error: Error) -> Bool {
        if isNetworkError(error) {
            return false
        }

        var queue: [NSError] = [error as NSError]
        var visited = Set<ObjectIdentifier>()

        while !queue.isEmpty {
            let ns = queue.removeFirst()
            guard visited.insert(ObjectIdentifier(ns)).inserted else { continue }

            if ns.domain == AVFoundationErrorDomain {
                switch ns.code {
                case AVError.fileFormatNotRecognized.rawValue,
                     AVError.decodeFailed.rawValue,
                     AVError.failedToLoadMediaData.rawValue,
                     AVError.contentIsNotAuthorized.rawValue,
                     AVError.contentIsProtected.rawValue,
                     AVError.noLongerPlayable.rawValue,
                     AVError.unknown.rawValue,
                     -11850,
                     -11867:
                    return true
                default:
                    break
                }
            }

            if ns.domain == NSOSStatusErrorDomain || ns.domain == "CoreMediaErrorDomain" {
                // Common CoreMedia/MediaToolbox format/codec status codes (e.g. -12847, -12848, -12780, -12938, -16840)
                let decodeOSStatusCodes: Set<Int> = [-12847, -12848, -12780, -12938, -16840, -11828, -11821]
                if decodeOSStatusCodes.contains(ns.code) {
                    return true
                }
            }

            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
                queue.append(underlying)
            }
            if let multiple = ns.userInfo[NSMultipleUnderlyingErrorsKey] as? [NSError] {
                queue.append(contentsOf: multiple)
            }
        }

        return false
    }

    /// Produces a user-facing diagnosis and transcode eligibility decision for a stream URL and optional error.
    public static func diagnose(url: URL,
                                error: Error?,
                                explicitContainer: String? = nil,
                                supportsServerTranscode: Bool = false) -> MediaContainerProbeResult {
        let container = classify(url: url, explicitContainer: explicitContainer)
        let isNative = container.isNativelySupportedByAVPlayer

        if let error, isNetworkError(error) {
            let ns = firstURLError(from: error) ?? (error as NSError)
            return MediaContainerProbeResult(
                container: container,
                isNativeContainer: isNative,
                isDecodeFailure: false,
                canOfferServerTranscode: false,
                userFacingReason: String(
                    format: NSLocalizedString("Network error: %@", comment: "Network playback error"),
                    ns.localizedDescription
                ),
                technicalCause: "network_error:\(ns.code)"
            )
        }

        let decodeFailure = error.map(isAVFoundationDecodeError) ?? false
        let allowTranscode = supportsServerTranscode && container != .hls

        if container.isUnsupportedContainer {
            let reason: String
            if allowTranscode {
                reason = String(
                    format: NSLocalizedString(
                        "%@ containers aren't natively supported by iOS AVPlayer. Retry via Server Transcode to stream as HLS.",
                        comment: "Unsupported container with server HLS transcode available"
                    ),
                    container.displayName
                )
            } else {
                reason = String(
                    format: NSLocalizedString(
                        "%@ containers aren't natively supported by iOS AVPlayer. Use server-side HLS transcoding (Jellyfin, Emby, or Plex) or an MP4/HLS stream.",
                        comment: "Unsupported container without server transcode"
                    ),
                    container.displayName
                )
            }
            return MediaContainerProbeResult(
                container: container,
                isNativeContainer: false,
                isDecodeFailure: true,
                canOfferServerTranscode: allowTranscode,
                userFacingReason: reason,
                technicalCause: "unsupported_container:\(container.rawValue)"
            )
        }

        if decodeFailure {
            let reason: String
            if allowTranscode {
                reason = NSLocalizedString(
                    "This video's container or codec isn't supported natively by iOS AVPlayer. Retry via Server Transcode to stream as HLS.",
                    comment: "Codec or demux failure with server HLS transcode available"
                )
            } else {
                reason = NSLocalizedString(
                    "This video's container or codec isn't supported natively by iOS AVPlayer. Try server-side HLS transcoding or an H.264/AAC MP4 stream.",
                    comment: "Codec or demux failure without server transcode"
                )
            }
            return MediaContainerProbeResult(
                container: container,
                isNativeContainer: isNative,
                isDecodeFailure: true,
                canOfferServerTranscode: allowTranscode,
                userFacingReason: reason,
                technicalCause: "avfoundation_decode_error"
            )
        }

        let fallbackText: String
        if let error {
            let ns = error as NSError
            fallbackText = ns.localizedFailureReason ?? ns.localizedDescription
        } else {
            fallbackText = NSLocalizedString("This video could not be played.", comment: "Generic playback failure")
        }

        return MediaContainerProbeResult(
            container: container,
            isNativeContainer: isNative,
            isDecodeFailure: false,
            canOfferServerTranscode: allowTranscode && error != nil,
            userFacingReason: fallbackText,
            technicalCause: error == nil ? "unknown" : "playback_error"
        )
    }

    // MARK: - Private helpers

    private static func classifyContainerTokenList(_ raw: String) -> MediaContainerKind? {
        let tokens = raw
            .lowercased()
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ". ")) }
            .filter { !$0.isEmpty }

        // If a server lists multiple compatible containers (e.g. "mov,mp4,m4a,3gp"), prefer a native one if present.
        for token in tokens {
            if let kind = mapToken(token), kind.isNativelySupportedByAVPlayer {
                return kind
            }
        }
        for token in tokens {
            if let kind = mapToken(token) {
                return kind
            }
        }
        return nil
    }

    private static func mapToken(_ token: String) -> MediaContainerKind? {
        switch token {
        case "mp4": return .mp4
        case "m4v": return .m4v
        case "mov", "qt": return .mov
        case "m3u8", "m3u", "hls": return .hls
        case "mkv", "matroska", "webm,matroska": return .mkv
        case "avi", "divx", "xvid": return .avi
        case "webm": return .webm
        case "flv": return .flv
        case "ts", "m2ts", "mts", "mpegts": return .ts
        case "wmv", "asf": return .wmv
        case "ogg", "ogv", "ogm": return .ogg
        default: return nil
        }
    }

    private static func firstURLError(from error: Error) -> NSError? {
        var current: NSError? = error as NSError
        var visited = Set<ObjectIdentifier>()
        while let ns = current, visited.insert(ObjectIdentifier(ns)).inserted {
            if ns.domain == NSURLErrorDomain {
                return ns
            }
            current = ns.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return nil
    }
}
