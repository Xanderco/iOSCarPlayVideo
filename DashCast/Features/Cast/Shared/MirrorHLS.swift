import Foundation
import VideoToolbox

/// Low-latency HLS for "Mirror iPhone on the CarPlay screen" (ADR-002 §7.5).
///
/// The CarPlay *video app* category (iOS 27) gives no drawable window: video reaches the car
/// only through the system player. So the broadcast extension encodes the ReplayKit frames to
/// H.264 (VideoToolbox), cuts them into ~1 s fMP4 segments and serves a live playlist from its
/// local server; the app plays `MirrorHLS.playlistURL` with AVPlayer (external playback on).
///
/// Compiled into the app (unit tests) and the broadcast extension. Pure logic only.
enum MirrorHLS {
    static let directory = "/hls/"
    static let playlistName = "live.m3u8"
    static let initSegmentName = "init.mp4"
    static var playlistPath: String { directory + playlistName }
    static var initSegmentPath: String { directory + initSegmentName }

    static func segmentName(_ sequence: Int) -> String { "seg\(sequence).m4s" }

    /// The app and the extension run on the same iPhone, so loopback is enough (and works
    /// without Wi-Fi or hotspot).
    static func playlistURL(port: UInt16 = CarCastShared.mirrorPort) -> URL {
        URL(string: "http://127.0.0.1:\(port)\(playlistPath)")!
    }

    enum Route: Equatable {
        case playlist
        case initSegment
        case segment(Int)
        case notHLS
    }

    /// Path of a GET request line ("GET /hls/live.m3u8?x=1 HTTP/1.1"), without the query.
    static func path(forRequest data: Data) -> String? {
        guard let text = String(data: data.prefix(2048), encoding: .utf8),
              let requestLine = text.components(separatedBy: "\r\n").first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return nil }
        return parts[1].split(separator: "?").first.map(String.init) ?? "/"
    }

    static func route(forPath path: String) -> Route {
        guard path.hasPrefix(directory) else { return .notHLS }
        let name = String(path.dropFirst(directory.count))
        if name == playlistName { return .playlist }
        if name == initSegmentName { return .initSegment }
        if name.hasPrefix("seg"), name.hasSuffix(".m4s") {
            let digits = name.dropFirst(3).dropLast(4)
            if !digits.isEmpty, digits.allSatisfy(\.isNumber), let value = Int(digits) {
                return .segment(value)
            }
        }
        return .notHLS
    }

    static func route(forRequest data: Data) -> Route {
        path(forRequest: data).map(route(forPath:)) ?? .notHLS
    }

    /// nil when the request is not an HLS path (falls through to the MJPEG routes).
    static func response(for route: MirrorHLS.Route, store: HLSSegmentStore) -> Data? {
        let body: Data?
        switch route {
        case .notHLS:
            return nil
        case .playlist:
            body = store.playlist().map { Data($0.utf8) }
        case .initSegment:
            body = store.initSegment
        case .segment(let sequence):
            body = store.segment(sequence)?.data
        }
        guard let body else {
            return MJPEGStream.httpResponse(status: "404 Not Found", contentType: "text/plain", body: Data("Not ready".utf8))
        }
        return MJPEGStream.httpResponse(status: "200 OK", contentType: MirrorHLS.contentType(for: route), body: body)
    }

    static func contentType(for route: Route) -> String {
        switch route {
        case .playlist: return "application/vnd.apple.mpegurl"
        case .initSegment: return "video/mp4"
        case .segment: return "video/iso.segment"
        case .notHLS: return "text/plain"
        }
    }
}

/// H.264 encoder settings for the car mirror stream. ~720p, 30 fps, 1 s GOP so every 1 s
/// segment starts with a keyframe; no B-frames and real-time rate control for low latency.
struct MirrorEncoderConfig: Equatable {
    var maxLongSide: Int = 1280
    var maxShortSide: Int = 720
    var framesPerSecond: Int = 30
    var averageBitRate: Int = 3_000_000
    var keyFrameIntervalSeconds: Double = 1
    var segmentDurationSeconds: Double = 1
    /// Segments kept in memory and listed in the playlist. Small: the extension has ~50 MB.
    var playlistWindow: Int = 4

    static let carPlay = MirrorEncoderConfig()

    var maxKeyFrameInterval: Int { max(1, Int((Double(framesPerSecond) * keyFrameIntervalSeconds).rounded())) }

    var minFrameInterval: Double { 1.0 / Double(max(1, framesPerSecond)) }

    /// Hard cap at 1.5× the average bit rate, in bytes per second.
    var dataRateLimitBytesPerSecond: Int { averageBitRate * 3 / 2 / 8 }

    /// Upper bound of what the segment window holds in memory.
    var estimatedWindowBytes: Int {
        Int(Double(dataRateLimitBytesPerSecond) * segmentDurationSeconds) * playlistWindow
    }

    /// Output size for a source frame: aspect ratio kept, never upscaled, even dimensions
    /// (H.264 4:2:0), long side ≤ `maxLongSide` and short side ≤ `maxShortSide`.
    func outputSize(sourceWidth: Int, sourceHeight: Int) -> (width: Int, height: Int) {
        guard sourceWidth > 0, sourceHeight > 0 else { return (0, 0) }
        let long = Double(max(sourceWidth, sourceHeight))
        let short = Double(min(sourceWidth, sourceHeight))
        let scale = min(1, Double(maxLongSide) / long, Double(maxShortSide) / short)
        func even(_ value: Double) -> Int { max(2, Int(value) & ~1) }
        return (even(Double(sourceWidth) * scale), even(Double(sourceHeight) * scale))
    }

    /// VTCompressionSession properties (`VTSessionSetProperty` key → value).
    var compressionProperties: [String: Any] {
        [
            kVTCompressionPropertyKey_RealTime as String: true,
            kVTCompressionPropertyKey_AllowFrameReordering as String: false,
            kVTCompressionPropertyKey_ProfileLevel as String: kVTProfileLevel_H264_Main_AutoLevel as String,
            kVTCompressionPropertyKey_AverageBitRate as String: averageBitRate,
            kVTCompressionPropertyKey_DataRateLimits as String: [dataRateLimitBytesPerSecond, 1],
            kVTCompressionPropertyKey_ExpectedFrameRate as String: framesPerSecond,
            kVTCompressionPropertyKey_MaxKeyFrameInterval as String: maxKeyFrameInterval,
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration as String: keyFrameIntervalSeconds
        ]
    }

    /// Encoder specification: low-latency rate control (iOS 14.5+), hardware encoder.
    var encoderSpecification: [String: Any] {
        [kVTVideoEncoderSpecification_EnableLowLatencyRateControl as String: true]
    }
}

struct HLSSegment: Equatable {
    let sequence: Int
    let duration: Double
    let data: Data
}

/// Builds the live media playlist (fMP4, version 7). No ENDLIST: it is a live stream.
enum HLSPlaylistBuilder {
    static func livePlaylist(segments: [(sequence: Int, duration: Double)], targetDuration: Double) -> String {
        let longest = segments.map(\.duration).max() ?? targetDuration
        let target = max(1, Int(max(longest, targetDuration).rounded(.up)))
        var lines = [
            "#EXTM3U",
            "#EXT-X-VERSION:7",
            "#EXT-X-TARGETDURATION:\(target)",
            "#EXT-X-MEDIA-SEQUENCE:\(segments.first?.sequence ?? 0)",
            "#EXT-X-INDEPENDENT-SEGMENTS",
            "#EXT-X-MAP:URI=\"\(MirrorHLS.initSegmentName)\""
        ]
        for segment in segments {
            lines.append(String(format: "#EXTINF:%.3f,", segment.duration))
            lines.append(MirrorHLS.segmentName(segment.sequence))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// Thread-safe sliding window of fMP4 segments (written by the encoder, read by the server).
final class HLSSegmentStore {
    let window: Int
    let targetDuration: Double
    private let lock = NSLock()
    private var initSegmentData: Data?
    private var segments: [HLSSegment] = []
    private var nextSequence = 0

    init(window: Int = MirrorEncoderConfig.carPlay.playlistWindow,
         targetDuration: Double = MirrorEncoderConfig.carPlay.segmentDurationSeconds) {
        self.window = max(1, window)
        self.targetDuration = targetDuration
    }

    var initSegment: Data? {
        lock.lock(); defer { lock.unlock() }
        return initSegmentData
    }

    /// Ready to play once the init segment and at least one media segment exist.
    var isReady: Bool {
        lock.lock(); defer { lock.unlock() }
        return initSegmentData != nil && !segments.isEmpty
    }

    var sequences: [Int] {
        lock.lock(); defer { lock.unlock() }
        return segments.map(\.sequence)
    }

    func setInitSegment(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        initSegmentData = data
    }

    @discardableResult
    func append(_ data: Data, duration: Double) -> Int {
        lock.lock(); defer { lock.unlock() }
        let sequence = nextSequence
        nextSequence += 1
        let safeDuration = duration.isFinite && duration > 0 ? duration : targetDuration
        segments.append(HLSSegment(sequence: sequence, duration: safeDuration, data: data))
        if segments.count > window {
            segments.removeFirst(segments.count - window)
        }
        return sequence
    }

    func segment(_ sequence: Int) -> HLSSegment? {
        lock.lock(); defer { lock.unlock() }
        return segments.first { $0.sequence == sequence }
    }

    /// nil until the stream is ready (the server answers 404 and AVPlayer retries).
    func playlist() -> String? {
        lock.lock(); defer { lock.unlock() }
        guard initSegmentData != nil, !segments.isEmpty else { return nil }
        return HLSPlaylistBuilder.livePlaylist(
            segments: segments.map { ($0.sequence, $0.duration) },
            targetDuration: targetDuration
        )
    }

    /// New encoder session (e.g. size change): media sequence keeps increasing.
    func reset() {
        lock.lock(); defer { lock.unlock() }
        initSegmentData = nil
        segments.removeAll()
    }
}
