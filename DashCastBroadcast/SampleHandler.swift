import ReplayKit
import CoreMedia
import CoreImage
import ImageIO
import QuartzCore

/// Broadcast Upload Extension: receives the iPhone screen from ReplayKit and
/// serves it as an MJPEG stream on the local network, so a car with a web
/// browser (or a wireless CarPlay adapter with a browser) on the iPhone's
/// Personal Hotspot / same Wi-Fi can display it while parked.
///
/// Memory limit for broadcast upload extensions is ~50 MB, so frames are
/// downscaled, encoded one at a time, and only produced while a viewer is connected.
final class SampleHandler: RPBroadcastSampleHandler {
    private let server = MirrorStreamServer(port: CarCastShared.mirrorPort)
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let frameInterval: CFTimeInterval = 1.0 / 12.0
    private let maxDimension: CGFloat = 1280

    private let lock = NSLock()
    private var status = BroadcastStatus.idle
    private var lastFrameTime: CFTimeInterval = 0
    private var lastMotionCheck: CFTimeInterval = 0
    private var finished = false

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        if CarCastShared.isVehicleMoving() {
            finishForMotion()
            return
        }

        server.onViewerCountChange = { [weak self] count in
            self?.updateStatus { $0.viewerCount = count }
        }
        server.start()

        updateStatus {
            $0 = BroadcastStatus(
                state: .live,
                startedAt: Date(),
                viewerURL: LocalNetworkAddress.viewerURL(address: LocalNetworkAddress.preferredIPv4()),
                viewerCount: 0,
                message: nil,
                updatedAt: Date()
            )
        }
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        server.stop()
        updateStatus { status in
            if status.state == .live {
                status = .idle
            }
            status.viewerCount = 0
        }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video, !finished else { return }

        let now = CACurrentMediaTime()
        if now - lastMotionCheck >= 1 {
            lastMotionCheck = now
            if CarCastShared.isVehicleMoving() {
                finishForMotion()
                return
            }
        }

        guard server.hasViewers, now - lastFrameTime >= frameInterval else { return }
        lastFrameTime = now

        if let jpeg = autoreleasepool(invoking: { encode(sampleBuffer) }) {
            server.broadcast(frame: jpeg)
        }
    }

    // MARK: - Helpers

    private func encode(_ sampleBuffer: CMSampleBuffer) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        var image = CIImage(cvPixelBuffer: pixelBuffer)

        if let raw = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber,
           let orientation = CGImagePropertyOrientation(rawValue: raw.uint32Value) {
            image = image.oriented(orientation)
        }

        let extent = image.extent
        let longest = max(extent.width, extent.height)
        if longest > maxDimension {
            let scale = maxDimension / longest
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        let quality = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        return ciContext.jpegRepresentation(of: image, colorSpace: colorSpace, options: [quality: 0.6])
    }

    private func finishForMotion() {
        lock.lock()
        let alreadyFinished = finished
        finished = true
        lock.unlock()
        guard !alreadyFinished else { return }

        server.stop()
        let message = "DashCast stopped screen mirroring because your vehicle is moving. Mirroring to the car is only available while parked."
        updateStatus {
            $0.state = .stoppedForMotion
            $0.viewerCount = 0
            $0.message = message
        }
        finishBroadcastWithError(NSError(
            domain: "com.xanderco.dashcast.broadcast",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        ))
    }

    private func updateStatus(_ change: (inout BroadcastStatus) -> Void) {
        lock.lock()
        change(&status)
        status.updatedAt = Date()
        let snapshot = status
        lock.unlock()

        snapshot.save()
        CarCastShared.postDarwinNotification(CarCastShared.DarwinNotification.broadcastStatusChanged)
    }
}
