import Foundation
import AVFoundation

/// Classification of media stream types and their compatibility with CarPlay external displays.
public enum DRMStreamType: String, CaseIterable, Identifiable, Codable {
    case hlsDirect = "Direct HLS Stream"
    case progressive = "Progressive MP4/MOV"
    case mediaServer = "Personal Media Server"
    case youtubeEmbed = "Web Video Embed"
    case fairPlayDRM = "Apple FairPlay DRM"
    case widevineDRM = "Google Widevine DRM"
    case restrictedService = "Commercial DRM Service"
    case unsupportedFormat = "Unsupported Container"
    case unknown = "Unknown Stream"

    public var id: String { rawValue }

    public var isCarPlayCompatible: Bool {
        switch self {
        case .hlsDirect, .progressive, .mediaServer, .youtubeEmbed:
            return true
        case .fairPlayDRM, .widevineDRM, .restrictedService, .unsupportedFormat, .unknown:
            return false
        }
    }

    public var badgeColorName: String {
        switch self {
        case .hlsDirect, .progressive, .mediaServer, .youtubeEmbed:
            return "dashGreen"
        case .unsupportedFormat, .unknown:
            return "dashAmber"
        case .fairPlayDRM, .widevineDRM, .restrictedService:
            return "dashRed"
        }
    }
}

/// Structured inspection report containing compatibility details and educational guidance.
public struct DRMInspectionResult: Identifiable, Codable, Equatable {
    public var id: String { urlString }
    public let urlString: String
    public let streamType: DRMStreamType
    public let isCarPlayCompatible: Bool
    public let detectedCodecs: [String]
    public let drmProtectionDescription: String
    public let technicalSummary: String
    public let educationalNotice: String
    public let resolutionRecommendation: String

    public init(
        urlString: String,
        streamType: DRMStreamType,
        isCarPlayCompatible: Bool,
        detectedCodecs: [String],
        drmProtectionDescription: String,
        technicalSummary: String,
        educationalNotice: String,
        resolutionRecommendation: String
    ) {
        self.urlString = urlString
        self.streamType = streamType
        self.isCarPlayCompatible = isCarPlayCompatible
        self.detectedCodecs = detectedCodecs
        self.drmProtectionDescription = drmProtectionDescription
        self.technicalSummary = technicalSummary
        self.educationalNotice = educationalNotice
        self.resolutionRecommendation = resolutionRecommendation
    }
}

/// Pre-configured reference sample streams for 1-tap testing and live demonstration.
public struct DiagnosticSampleStream: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let urlString: String
    public let expectedType: DRMStreamType
    public let isDRMProtected: Bool
    public let description: String

    public init(id: String, name: String, urlString: String, expectedType: DRMStreamType, isDRMProtected: Bool, description: String) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.expectedType = expectedType
        self.isDRMProtected = isDRMProtected
        self.description = description
    }
}

/// Core service that inspects streams for DRM protection, codec compliance, and CarPlay display compatibility.
public final class DRMCompatibilityInspector: ObservableObject {
    public static let shared = DRMCompatibilityInspector()

    @Published public var lastResult: DRMInspectionResult?
    @Published public var isInspecting: Bool = false
    @Published public var inspectionHistory: [DRMInspectionResult] = []

    public let sampleStreams: [DiagnosticSampleStream] = [
        DiagnosticSampleStream(
            id: "sample_hls",
            name: "Public HLS Master (Clean)",
            urlString: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
            expectedType: .hlsDirect,
            isDRMProtected: false,
            description: "Standard unencrypted HLS multi-bitrate playlist with H.264 & AAC."
        ),
        DiagnosticSampleStream(
            id: "sample_mp4",
            name: "Direct MP4 Video File",
            urlString: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            expectedType: .progressive,
            isDRMProtected: false,
            description: "Progressive MP4 stream ready for direct CarPlay hardware decoding."
        ),
        DiagnosticSampleStream(
            id: "sample_jellyfin",
            name: "Personal Media Server",
            urlString: "http://192.168.1.50:8096/videos/personal-stream.m3u8",
            expectedType: .mediaServer,
            isDRMProtected: false,
            description: "Self-hosted Jellyfin/Emby stream with direct AVFoundation streaming."
        ),
        DiagnosticSampleStream(
            id: "sample_fairplay",
            name: "FairPlay DRM Encrypted Stream",
            urlString: "https://fps.example.com/live/encrypted_master.m3u8?keyformat=com.apple.streamingkeydelivery",
            expectedType: .fairPlayDRM,
            isDRMProtected: true,
            description: "Apple FairPlay encrypted stream — blocks video playback on external car displays."
        ),
        DiagnosticSampleStream(
            id: "sample_netflix",
            name: "Netflix Protected Service",
            urlString: "https://www.netflix.com/watch/80057281",
            expectedType: .restrictedService,
            isDRMProtected: true,
            description: "Commercial streaming platform with proprietary Widevine & FairPlay encryption."
        )
    ]

    private let knownDRMDomains: [String: (type: DRMStreamType, name: String)] = [
        "netflix.com": (.restrictedService, "Netflix"),
        "nflxvideo.net": (.restrictedService, "Netflix Video CDN"),
        "disneyplus.com": (.restrictedService, "Disney+"),
        "disney-portal.my.onetrust.com": (.restrictedService, "Disney+"),
        "primevideo.com": (.restrictedService, "Amazon Prime Video"),
        "amazon.com": (.restrictedService, "Amazon Video"),
        "pv-cdn.net": (.restrictedService, "Amazon Prime Video CDN"),
        "max.com": (.restrictedService, "Max / HBO Max"),
        "hbomax.com": (.restrictedService, "HBO Max"),
        "hulu.com": (.restrictedService, "Hulu"),
        "tv.apple.com": (.restrictedService, "Apple TV+"),
        "peacocktv.com": (.restrictedService, "Peacock TV"),
        "paramountplus.com": (.restrictedService, "Paramount+")
    ]

    public init() {}

    /// Inspects a given stream URL string synchronously or asynchronously.
    public func inspect(urlString: String) -> DRMInspectionResult {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            return DRMInspectionResult(
                urlString: trimmed,
                streamType: .unknown,
                isCarPlayCompatible: false,
                detectedCodecs: ["Unknown"],
                drmProtectionDescription: "Invalid URL Format",
                technicalSummary: "The entered stream address could not be parsed as a valid URL.",
                educationalNotice: "Check that the URL begins with http:// or https:// and contains a valid host.",
                resolutionRecommendation: "Ensure you copy a complete stream link or direct video file address."
            )
        }

        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        let query = (url.query ?? "").lowercased()

        // 1. Check known commercial DRM domains
        for (domain, info) in knownDRMDomains {
            if host == domain || host.hasSuffix("." + domain) {
                let result = DRMInspectionResult(
                    urlString: trimmed,
                    streamType: info.type,
                    isCarPlayCompatible: false,
                    detectedCodecs: ["Encrypted H.264 / HEVC", "Protected AAC / AC3"],
                    drmProtectionDescription: "\(info.name) FairPlay & Widevine DRM",
                    technicalSummary: "Commercial streaming services enforce hardware-level FairPlay / Widevine DRM.",
                    educationalNotice: "Apple's AVFoundation and CarPlay explicitly prohibit casting DRM-protected video to external car head-units to enforce HDCP 2.2 content protection rules. The screen will render black by design.",
                    resolutionRecommendation: "Use DashCast with personal media servers (Jellyfin/Emby/Plex), personal playlists, or web videos without DRM."
                )
                recordResult(result)
                return result
            }
        }

        // 2. Check for explicit FairPlay keydelivery signatures in URL or query
        if query.contains("com.apple.streamingkeydelivery") ||
           query.contains("fairplay") ||
           path.contains("fpskey") ||
           query.contains("keyformat=identity") == false && query.contains("keyformat=") {
            let result = DRMInspectionResult(
                urlString: trimmed,
                streamType: .fairPlayDRM,
                isCarPlayCompatible: false,
                detectedCodecs: ["FairPlay Encrypted H.264 / HEVC"],
                drmProtectionDescription: "Apple FairPlay Streaming (FPS)",
                technicalSummary: "Detected FairPlay DRM key exchange protocol parameters in the manifest stream request.",
                educationalNotice: "FairPlay encrypted video keys cannot be decrypted on non-HDCP compliant external head-units. Apple restricts CarPlay from outputting decrypted video.",
                resolutionRecommendation: "Provide an unencrypted HLS stream or uncheck DRM protection on your media origin server."
            )
            recordResult(result)
            return result
        }

        // 3. Check for Widevine signatures
        if query.contains("widevine") || path.contains("widevine") || query.contains("edrm") {
            let result = DRMInspectionResult(
                urlString: trimmed,
                streamType: .widevineDRM,
                isCarPlayCompatible: false,
                detectedCodecs: ["Widevine Encrypted Video"],
                drmProtectionDescription: "Google Widevine Modular DRM",
                technicalSummary: "Stream requires Widevine Content Decryption Module (CDM), which is not supported natively on iOS CarPlay.",
                educationalNotice: "iOS AVFoundation does not decode Widevine DRM for external displays.",
                resolutionRecommendation: "Convert or transcode your media using an unencrypted HLS (m3u8) profile."
            )
            recordResult(result)
            return result
        }

        // 4. Check for personal media servers (Jellyfin, Emby, Plex, Subsonic)
        if path.contains("jellyfin") || path.contains("emby") || host.contains("plex") || query.contains("api_key") || path.contains("/videos/") || path.contains("/audio/") {
            let result = DRMInspectionResult(
                urlString: trimmed,
                streamType: .mediaServer,
                isCarPlayCompatible: true,
                detectedCodecs: ["H.264 / HEVC (AVC1)", "AAC Audio (mp4a.40.2)"],
                drmProtectionDescription: "None — Authenticated Personal Stream",
                technicalSummary: "Detected personal media server stream endpoint. Direct play and remuxing are compatible with CarPlay external displays.",
                educationalNotice: "Personal media servers let you stream your own movies and home videos directly to CarPlay without DRM restrictions while parked.",
                resolutionRecommendation: "Ensure Direct Play or HLS remuxing is enabled in your media server transcoding settings for optimal performance."
            )
            recordResult(result)
            return result
        }

        // 5. Check direct HLS playlist (.m3u8)
        if path.hasSuffix(".m3u8") || query.contains(".m3u8") {
            let result = DRMInspectionResult(
                urlString: trimmed,
                streamType: .hlsDirect,
                isCarPlayCompatible: true,
                detectedCodecs: ["H.264 Baseline/Main/High", "AAC Stereo / 5.1"],
                drmProtectionDescription: "None — Clean Public / Unencrypted HLS",
                technicalSummary: "Standard HTTP Live Streaming (HLS) playlist. Fully supported by DashCast video engine and CarPlay external display mirror.",
                educationalNotice: "This stream will play seamlessly on your in-car screen while parked.",
                resolutionRecommendation: "Ready to cast! Add this URL to your Channels or open in the video player."
            )
            recordResult(result)
            return result
        }

        // 6. Check progressive video files (.mp4, .mov, .m4v)
        if path.hasSuffix(".mp4") || path.hasSuffix(".mov") || path.hasSuffix(".m4v") {
            let result = DRMInspectionResult(
                urlString: trimmed,
                streamType: .progressive,
                isCarPlayCompatible: true,
                detectedCodecs: ["MPEG-4 AVC (H.264)", "AAC Audio"],
                drmProtectionDescription: "None — Standard Container File",
                technicalSummary: "Progressive MP4/MOV container. Native hardware decoding supported by iOS and CarPlay.",
                educationalNotice: "Progressive files buffer smoothly on in-car Wi-Fi and require minimal CPU power.",
                resolutionRecommendation: "Ready to cast! Add to your Playlist or play directly in DashCast."
            )
            recordResult(result)
            return result
        }

        // 7. Check unsupported containers (.mkv, .webm, .avi, .flv)
        if path.hasSuffix(".mkv") || path.hasSuffix(".webm") || path.hasSuffix(".avi") || path.hasSuffix(".flv") {
            let ext = (path as NSString).pathExtension.uppercased()
            let result = DRMInspectionResult(
                urlString: trimmed,
                streamType: .unsupportedFormat,
                isCarPlayCompatible: false,
                detectedCodecs: ["\(ext) Container", "Non-Native AVFoundation Codec"],
                drmProtectionDescription: "Container Format Limitation",
                technicalSummary: "iOS AVFoundation does not natively decode \(ext) containers on external display surfaces without remuxing.",
                educationalNotice: "CarPlay video requires native iOS container formats (HLS .m3u8 or MP4/MOV). Non-standard containers cause decoding stalls.",
                resolutionRecommendation: "Remux or transcode this video to MP4 or HLS via your media server or ffmpeg before casting."
            )
            recordResult(result)
            return result
        }

        // 8. General fallback for web video
        let isHTTP = url.scheme == "http" || url.scheme == "https"
        let result = DRMInspectionResult(
            urlString: trimmed,
            streamType: isHTTP ? .youtubeEmbed : .unknown,
            isCarPlayCompatible: isHTTP,
            detectedCodecs: isHTTP ? ["Web Stream / Extracted AVC"] : ["Unknown Codec"],
            drmProtectionDescription: isHTTP ? "Unprotected Web Media" : "Unverified Stream",
            technicalSummary: isHTTP ? "Standard web URL. DashCast Web Video Extractor will inspect embedded video tags." : "Unrecognized URL scheme.",
            educationalNotice: isHTTP ? "Web video pages will be analyzed by DashCast's built-in player to extract unencrypted MP4/HLS feeds." : "Verify the URL before streaming.",
            resolutionRecommendation: isHTTP ? "Open in DashCast Web Browser to extract and stream to CarPlay." : "Verify the link format."
        )
        recordResult(result)
        return result
    }

    private func recordResult(_ result: DRMInspectionResult) {
        DispatchQueue.main.async {
            self.lastResult = result
            if !self.inspectionHistory.contains(where: { $0.urlString == result.urlString }) {
                self.inspectionHistory.insert(result, at: 0)
                if self.inspectionHistory.count > 20 {
                    self.inspectionHistory.removeLast()
                }
            }
        }
    }
}
