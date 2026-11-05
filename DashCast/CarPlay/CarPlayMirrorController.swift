import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
import UIKit
#if canImport(CarPlay)
import CarPlay
#endif

/// Renders frames from the DashCastBroadcast extension (via `MirrorFrameReader`)
/// with an `AVSampleBufferDisplayLayer`.
final class CarPlayMirrorRendererView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }

    var displayLayer: AVSampleBufferDisplayLayer {
        // swiftlint:disable:next force_cast
        layer as! AVSampleBufferDisplayLayer
    }

    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        displayLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Decodes one JPEG frame and enqueues it for immediate display.
    @discardableResult
    func display(jpeg: Data) -> Bool {
        guard let image = CIImage(data: jpeg) else { return false }
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        guard width > 0, height > 0 else { return false }

        var pixelBuffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes, &pixelBuffer)
        guard let pixelBuffer else { return false }
        ciContext.render(image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY)), to: pixelBuffer)

        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &format)
        guard let format else { return false }

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard let sampleBuffer else { return false }

        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                dictionary,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }

        let renderer = displayLayer.sampleBufferRenderer
        if renderer.status == .failed || renderer.requiresFlushToResumeDecoding {
            renderer.flush()
        }
        renderer.enqueue(sampleBuffer)
        return true
    }

    func clear() {
        displayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil)
    }
}

/// What the car screen shows.
enum CarMirrorDisplayState: Equatable {
    case instructions
    case mirroring
    case pausedWhileMoving

    /// Pure decision used by the controller (and unit tests).
    static func resolve(featureEnabled: Bool, vehicleMoving: Bool, lastFrameAge: TimeInterval?) -> CarMirrorDisplayState {
        guard featureEnabled else { return .instructions }
        if vehicleMoving { return .pausedWhileMoving }
        guard let age = lastFrameAge, age < staleFrameInterval else { return .instructions }
        return .mirroring
    }

    static let staleFrameInterval: TimeInterval = 2

    static let instructionsText = """
    Mirror your iPhone here

    1. On iPhone, open DashCast → Cast → Car Display.
    2. Turn on “Mirror to CarPlay screen”, then Start Broadcast.

    Mirroring works only while the car is parked.
    """

    static let movingText = """
    Mirroring paused

    Your vehicle is moving. The picture comes back when you are parked.
    """
}

/// Root view placed in the CarPlay window: renderer plus an instructions overlay.
final class CarPlayMirrorRootView: UIView {
    let renderer = CarPlayMirrorRendererView(frame: .zero)
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        renderer.frame = bounds
        renderer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(renderer)

        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        messageLabel.adjustsFontSizeToFitWidth = true
        messageLabel.minimumScaleFactor = 0.6
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
        apply(.instructions)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ state: CarMirrorDisplayState) {
        switch state {
        case .mirroring:
            messageLabel.isHidden = true
            renderer.isHidden = false
        case .instructions:
            renderer.clear()
            renderer.isHidden = true
            messageLabel.text = CarMirrorDisplayState.instructionsText
            messageLabel.isHidden = false
        case .pausedWhileMoving:
            renderer.clear()
            renderer.isHidden = true
            messageLabel.text = CarMirrorDisplayState.movingText
            messageLabel.isHidden = false
        }
    }
}

/// Owns the CarPlay window (when iOS provides one) and pumps mirrored frames
/// into it while parked. Without a window-granting CarPlay entitlement iOS never
/// hands us a window, `attach(window:)` is never called and nothing here runs:
/// the app falls back to the template UI (instructions in the Cast tab).
@MainActor
final class CarPlayMirrorController {
    static let shared = CarPlayMirrorController()
    static let pollInterval: TimeInterval = 1.0 / 15.0

    private(set) var state: CarMirrorDisplayState = .instructions
    private var rootView: CarPlayMirrorRootView?
    private var timer: Timer?
    private var lastSequence: UInt64 = 0
    private var lastFrameAt: Date?
    /// The app-wide parked guard; we only stop it if we were the ones who started it.
    private var parkedGuard: ParkedGuard { CarVideoOutputController.shared.parkedGuard }
    private var startedParkedGuard = false

    var isAttached: Bool { rootView != nil }

    func attach(to window: UIWindow) {
        let controller = UIViewController()
        let root = CarPlayMirrorRootView(frame: window.bounds)
        controller.view = root
        window.rootViewController = controller
        window.makeKeyAndVisible()
        rootView = root
        state = .instructions
        root.apply(.instructions)

        // Poll even while the flag is off so turning it on from the phone takes
        // effect without reconnecting CarPlay; with the flag off a tick is one
        // defaults read.
        timer?.invalidate()
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func detach() {
        timer?.invalidate()
        timer = nil
        stopParkedGuardIfOurs()
        rootView = nil
        lastFrameAt = nil
        lastSequence = 0
        state = .instructions
    }

    private func tick() {
        guard let rootView else { return }
        let enabled = CarMirrorFeature.isEnabled()
        if enabled {
            startParkedGuardIfNeeded()
        } else {
            stopParkedGuardIfOurs()
        }
        guard enabled else {
            if state != .instructions {
                state = .instructions
                rootView.apply(.instructions)
            }
            return
        }
        let moving = CarCastShared.isVehicleMoving()
        if !moving, let url = CarMirrorFeature.framesURL,
           let frame = MirrorFrameReader.latestFrame(at: url, newerThan: lastSequence) {
            lastSequence = frame.sequence
            // Frame timestamps are wall-clock time from the extension, so a frame
            // left over from an earlier broadcast is never shown as live.
            let capturedAt = Date(timeIntervalSince1970: frame.timestamp)
            if Date().timeIntervalSince(capturedAt) < CarMirrorDisplayState.staleFrameInterval,
               rootView.renderer.display(jpeg: frame.jpeg) {
                lastFrameAt = capturedAt
            }
        }
        let age = lastFrameAt.map { Date().timeIntervalSince($0) }
        let next = CarMirrorDisplayState.resolve(featureEnabled: enabled, vehicleMoving: moving, lastFrameAge: age)
        if next != state {
            state = next
            rootView.apply(next)
        }
    }

    private func startParkedGuardIfNeeded() {
        guard !parkedGuard.isMonitoring else { return }
        parkedGuard.start()
        startedParkedGuard = true
    }

    private func stopParkedGuardIfOurs() {
        guard startedParkedGuard else { return }
        startedParkedGuard = false
        parkedGuard.stop()
    }
}
