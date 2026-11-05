import AVFoundation
import CoreMedia
import QuartzCore
import UniformTypeIdentifiers
import VideoToolbox

/// ReplayKit frames → H.264 (VTCompressionSession, low latency) → ~1 s fMP4 segments
/// (AVAssetWriter in passthrough, `.mpeg4AppleHLS` profile) → `HLSSegmentStore`, which
/// `MirrorStreamServer` serves as a live HLS playlist on 127.0.0.1:8088/hls/live.m3u8.
///
/// Memory: one compression session, one writer, `playlistWindow` segments (≈2–3 MB) —
/// well inside the ~50 MB broadcast extension limit.
final class MirrorHLSEncoder: NSObject, AVAssetWriterDelegate {
    let store: HLSSegmentStore
    private let config: MirrorEncoderConfig
    private let queue = DispatchQueue(label: "com.xanderco.dashcast.broadcast.hls")

    // Touched only on the ReplayKit sample queue.
    private var session: VTCompressionSession?
    private var lastEncodeTime: CFTimeInterval = 0
    private var failed = false

    // Touched only on `queue`.
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var waitingForKeyFrame = false

    init(config: MirrorEncoderConfig = .carPlay) {
        self.config = config
        self.store = HLSSegmentStore(window: config.playlistWindow, targetDuration: config.segmentDurationSeconds)
        super.init()
    }

    /// Call from `processSampleBuffer` for video samples. Throttled to the configured fps.
    func encode(_ sampleBuffer: CMSampleBuffer) {
        guard !failed, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = CACurrentMediaTime()
        guard now - lastEncodeTime >= config.minFrameInterval * 0.9 else { return }
        lastEncodeTime = now

        if session == nil {
            let size = config.outputSize(
                sourceWidth: CVPixelBufferGetWidth(pixelBuffer),
                sourceHeight: CVPixelBufferGetHeight(pixelBuffer)
            )
            session = makeSession(width: size.width, height: size.height)
            if session == nil {
                failed = true
                return
            }
        }
        guard let session else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMTime(value: 1, timescale: CMTimeScale(config.framesPerSecond))
        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: duration,
            frameProperties: nil,
            infoFlagsOut: nil
        ) { [weak self] status, _, encoded in
            guard status == noErr, let encoded, let self else { return }
            self.queue.async { self.append(encoded) }
        }
    }

    func stop() {
        if let session {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }
        session = nil
        queue.sync {
            if let writer, writer.status == .writing {
                input?.markAsFinished()
                writer.cancelWriting()
            }
            writer = nil
            input = nil
        }
        store.reset()
    }

    // MARK: - Encoder

    private func makeSession(width: Int, height: Int) -> VTCompressionSession? {
        guard width > 0, height > 0 else { return nil }
        var created: VTCompressionSession?
        var status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: config.encoderSpecification as CFDictionary,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &created
        )
        if status != noErr || created == nil {
            // Low-latency rate control unavailable: fall back to the default encoder.
            status = VTCompressionSessionCreate(
                allocator: kCFAllocatorDefault,
                width: Int32(width),
                height: Int32(height),
                codecType: kCMVideoCodecType_H264,
                encoderSpecification: nil,
                imageBufferAttributes: nil,
                compressedDataAllocator: nil,
                outputCallback: nil,
                refcon: nil,
                compressionSessionOut: &created
            )
        }
        guard status == noErr, let session = created else { return nil }
        for (key, value) in config.compressionProperties {
            // Unsupported properties (e.g. under low-latency mode) are ignored, not fatal.
            _ = VTSessionSetProperty(session, key: key as CFString, value: value as CFTypeRef)
        }
        VTCompressionSessionPrepareToEncodeFrames(session)
        return session
    }

    // MARK: - Segmenter (on `queue`)

    private func append(_ sample: CMSampleBuffer) {
        if writer == nil {
            guard Self.isKeyFrame(sample), let format = CMSampleBufferGetFormatDescription(sample) else { return }
            startWriter(format: format, at: CMSampleBufferGetPresentationTimeStamp(sample))
        }
        guard let writer, writer.status == .writing, let input else { return }

        if waitingForKeyFrame {
            guard Self.isKeyFrame(sample) else { return }
            waitingForKeyFrame = false
        }
        if input.isReadyForMoreMediaData {
            if !input.append(sample) { waitingForKeyFrame = true }
        } else {
            // Drop instead of queueing; resume at the next keyframe so the stream stays decodable.
            waitingForKeyFrame = true
        }
    }

    private func startWriter(format: CMFormatDescription, at time: CMTime) {
        let writer = AVAssetWriter(contentType: UTType(AVFileType.mp4.rawValue) ?? .mpeg4Movie)
        writer.outputFileTypeProfile = .mpeg4AppleHLS
        writer.preferredOutputSegmentInterval = CMTime(seconds: config.segmentDurationSeconds, preferredTimescale: 600)
        writer.initialSegmentStartTime = time
        writer.delegate = self

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: format)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { return }
        writer.add(input)
        guard writer.startWriting() else { return }
        writer.startSession(atSourceTime: time)
        self.writer = writer
        self.input = input
    }

    static func isKeyFrame(_ sample: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[CFString: Any]],
              let first = attachments.first else { return true }
        return !((first[kCMSampleAttachmentKey_NotSync] as? Bool) ?? false)
    }

    // MARK: - AVAssetWriterDelegate

    func assetWriter(
        _ writer: AVAssetWriter,
        didOutputSegmentData segmentData: Data,
        segmentType: AVAssetSegmentType,
        segmentReport: AVAssetSegmentReport?
    ) {
        switch segmentType {
        case .initialization:
            store.setInitSegment(segmentData)
        case .separable:
            let duration = segmentReport?.trackReports.first?.duration.seconds ?? config.segmentDurationSeconds
            store.append(segmentData, duration: duration)
        @unknown default:
            break
        }
    }
}
