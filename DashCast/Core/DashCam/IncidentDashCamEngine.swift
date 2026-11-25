import Foundation
import AVFoundation
import CoreMotion
import CoreGraphics
import CoreText
import QuartzCore
import Combine

// MARK: - Domain Models

public enum IncidentTriggerReason: String, Codable, Sendable, CaseIterable {
    case gShockDeceleration = "g_shock"
    case manualEmergency = "manual"
    case simulatedTest = "test"

    public var displayTitle: String {
        switch self {
        case .gShockDeceleration: return "G-Shock Impact"
        case .manualEmergency: return "Manual Save"
        case .simulatedTest: return "Test Event"
        }
    }
}

public struct DashCamSegment: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let filename: String
    public let startTime: Date
    public var endTime: Date
    public var duration: TimeInterval
    public var peakDecelerationG: Double
    public var peakSpeedKmh: Double

    public init(
        id: UUID = UUID(),
        filename: String,
        startTime: Date,
        endTime: Date,
        peakDecelerationG: Double = 0,
        peakSpeedKmh: Double = 0
    ) {
        self.id = id
        self.filename = filename
        self.startTime = startTime
        self.endTime = endTime
        self.duration = max(0, endTime.timeIntervalSince(startTime))
        self.peakDecelerationG = peakDecelerationG
        self.peakSpeedKmh = peakSpeedKmh
    }
}

public struct RollingTelemetrySample: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let speedKmh: Double
    public let decelerationG: Double

    public init(timestamp: Date, speedKmh: Double, decelerationG: Double) {
        self.timestamp = timestamp
        self.speedKmh = speedKmh
        self.decelerationG = decelerationG
    }
}

public struct IncidentClipRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let triggerReason: IncidentTriggerReason
    public let peakDecelerationG: Double
    public let speedKmhAtImpact: Double
    public let useMilesPerHour: Bool
    public let durationSeconds: TimeInterval
    public let clipFilename: String
    public let watermarkText: String
    public var isLocked: Bool

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        triggerReason: IncidentTriggerReason,
        peakDecelerationG: Double,
        speedKmhAtImpact: Double,
        useMilesPerHour: Bool,
        durationSeconds: TimeInterval,
        clipFilename: String,
        watermarkText: String,
        isLocked: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.triggerReason = triggerReason
        self.peakDecelerationG = peakDecelerationG
        self.speedKmhAtImpact = speedKmhAtImpact
        self.useMilesPerHour = useMilesPerHour
        self.durationSeconds = durationSeconds
        self.clipFilename = clipFilename
        self.watermarkText = watermarkText
        self.isLocked = isLocked
    }
}

// MARK: - Pure Policy & Physics Calculations

public enum IncidentTriggerPolicy {
    /// Hard deceleration threshold (> 0.6G) required to trigger incident archiving.
    public static let standardDecelerationThresholdG: Double = 0.6
    public static let minThresholdG: Double = 0.4
    public static let maxThresholdG: Double = 1.5
    /// 60-second rolling circular buffer window.
    public static let rollingWindowSeconds: TimeInterval = 60.0
    /// Target duration for each circular buffer video segment.
    public static let segmentDurationSeconds: TimeInterval = 10.0
    /// Minimum spacing between automatic triggers for a single braking event.
    public static let triggerCooldownSeconds: TimeInterval = 15.0
    /// Maximum number of unlocked incident clips retained in the local sandbox.
    public static let maxArchivedClips: Int = 20
    /// Standard Earth gravitational acceleration (m/s^2).
    public static let standardGravityMs2: Double = 9.80665

    public static func clampedThreshold(_ g: Double) -> Double {
        guard g.isFinite else { return standardDecelerationThresholdG }
        return min(max(g, minThresholdG), maxThresholdG)
    }

    /// Computes linear deceleration in G-force units from consecutive speed samples.
    /// Positive return values indicate braking / deceleration; acceleration returns 0.
    public static func decelerationFromSpeedDelta(
        previousSpeedKmh: Double,
        currentSpeedKmh: Double,
        dt: TimeInterval
    ) -> Double {
        guard previousSpeedKmh.isFinite,
              currentSpeedKmh.isFinite,
              dt.isFinite,
              dt > 0.05,
              dt <= 5.0 else {
            return 0
        }
        let speedDropMs = max(0, (previousSpeedKmh - currentSpeedKmh) / 3.6)
        guard speedDropMs > 0 else { return 0 }
        let decelMs2 = speedDropMs / dt
        return decelMs2 / standardGravityMs2
    }

    /// Computes vector magnitude (G) from CoreMotion gravity-subtracted `userAcceleration`.
    public static func userAccelerationMagnitudeG(x: Double, y: Double, z: Double) -> Double {
        guard x.isFinite, y.isFinite, z.isFinite else { return 0 }
        return sqrt((x * x) + (y * y) + (z * z))
    }

    /// Combines hardware accelerometer magnitude and GPS deceleration into an effective G value.
    public static func effectiveDecelerationG(
        userAccelerationG: (x: Double, y: Double, z: Double)?,
        gpsDecelerationG: Double
    ) -> Double {
        let motionG = userAccelerationG.map {
            userAccelerationMagnitudeG(x: $0.x, y: $0.y, z: $0.z)
        } ?? 0
        let safeGpsG = gpsDecelerationG.isFinite ? max(0, gpsDecelerationG) : 0
        return max(motionG, safeGpsG)
    }

    /// Returns true strictly when deceleration exceeds threshold (> 0.6G by default) and cooldown elapsed.
    public static func shouldTriggerIncident(
        decelerationG: Double,
        thresholdG: Double = standardDecelerationThresholdG,
        lastTriggerTime: Date?,
        now: Date,
        cooldown: TimeInterval = triggerCooldownSeconds
    ) -> Bool {
        guard decelerationG.isFinite, thresholdG.isFinite else { return false }
        guard decelerationG > thresholdG else { return false }
        if let lastTriggerTime {
            let elapsed = now.timeIntervalSince(lastTriggerTime)
            if elapsed < cooldown {
                return false
            }
        }
        return true
    }
}

// MARK: - Rolling 60s Circular Buffer

public struct RollingSegmentBuffer: Sendable {
    public private(set) var segments: [DashCamSegment] = []
    public let windowSeconds: TimeInterval

    public init(windowSeconds: TimeInterval = IncidentTriggerPolicy.rollingWindowSeconds) {
        self.windowSeconds = max(1.0, windowSeconds)
    }

    public var totalBufferedDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    /// Appends a newly completed segment and returns expired segments whose end timestamps
    /// fall outside the rolling window relative to the newest segment.
    @discardableResult
    public mutating func append(_ segment: DashCamSegment) -> [DashCamSegment] {
        segments.append(segment)
        segments.sort { $0.startTime < $1.startTime }

        let newestEnd = segments.map(\.endTime).max() ?? segment.endTime
        let cutoff = newestEnd.addingTimeInterval(-windowSeconds)

        var expired: [DashCamSegment] = []
        var retained: [DashCamSegment] = []
        for item in segments {
            if item.endTime <= cutoff {
                expired.append(item)
            } else {
                retained.append(item)
            }
        }
        segments = retained
        return expired
    }

    /// Returns chronological segments overlapping `[triggerTime - windowSeconds, triggerTime]`.
    public func snapshotSegments(around triggerTime: Date) -> [DashCamSegment] {
        let lowerBound = triggerTime.addingTimeInterval(-windowSeconds)
        return segments
            .filter { $0.endTime > lowerBound && $0.startTime <= triggerTime }
            .sorted { $0.startTime < $1.startTime }
    }

    public mutating func clear() -> [DashCamSegment] {
        let removed = segments
        segments.removeAll()
        return removed
    }
}

// MARK: - Windshield Telemetry Watermark

public enum WindshieldTelemetryOverlay {
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    public static func formatWatermark(
        speedKmh: Double,
        decelerationG: Double,
        useMilesPerHour: Bool,
        timestamp: Date
    ) -> String {
        let safeSpeedKmh = speedKmh.isFinite ? max(0, speedKmh) : 0
        let displaySpeed = useMilesPerHour ? (safeSpeedKmh * 0.621371) : safeSpeedKmh
        let unit = useMilesPerHour ? "MPH" : "KM/H"
        let safeG = decelerationG.isFinite ? max(0, decelerationG) : 0
        let timeString = timestampFormatter.string(from: timestamp)
        return String(format: "%.0f %@  •  %.2f G  •  %@", displaySpeed, unit, safeG, timeString)
    }

    /// Builds a CoreAnimation overlay layer for `AVVideoCompositionCoreAnimationTool`.
    public static func makeCompositionWatermarkLayer(text: String, renderSize: CGSize) -> CALayer {
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: renderSize)

        let badgeHeight: CGFloat = max(32, renderSize.height * 0.065)
        let horizontalMargin: CGFloat = max(16, renderSize.width * 0.025)
        let badgeWidth: CGFloat = min(renderSize.width - (horizontalMargin * 2), max(340, renderSize.width * 0.65))

        let pillLayer = CALayer()
        pillLayer.frame = CGRect(
            x: horizontalMargin,
            y: horizontalMargin,
            width: badgeWidth,
            height: badgeHeight
        )
        pillLayer.backgroundColor = CGColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 0.78)
        pillLayer.cornerRadius = badgeHeight / 2
        pillLayer.borderWidth = 1.0
        pillLayer.borderColor = CGColor(red: 0.17, green: 0.89, blue: 0.50, alpha: 0.7)

        let textLayer = CATextLayer()
        textLayer.frame = CGRect(x: 14, y: (badgeHeight - 18) / 2, width: badgeWidth - 28, height: 20)
        textLayer.string = "DASHCAST  •  \(text)"
        textLayer.font = CTFontCreateWithName("Menlo-Bold" as CFString, 13, nil)
        textLayer.fontSize = 13
        textLayer.foregroundColor = CGColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        textLayer.contentsScale = 2.0
        textLayer.alignmentMode = .left

        pillLayer.addSublayer(textLayer)
        overlayLayer.addSublayer(pillLayer)
        return overlayLayer
    }
}

// MARK: - Incident DashCam Engine

@MainActor
public final class IncidentDashCamEngine: NSObject, ObservableObject {
    public static let shared = IncidentDashCamEngine()

    @Published public private(set) var isArmed: Bool = false
    @Published public private(set) var isRecordingBuffer: Bool = false
    @Published public private(set) var isCameraAvailable: Bool = false
    @Published public private(set) var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published public private(set) var decelerationThresholdG: Double
    @Published public private(set) var currentDecelerationG: Double = 0
    @Published public private(set) var peakSessionDecelerationG: Double = 0
    @Published public private(set) var currentSpeedKmh: Double = 0
    @Published public private(set) var latestTelemetryWatermark: String = ""
    @Published public private(set) var bufferedSeconds: TimeInterval = 0
    @Published public private(set) var bufferedSegmentCount: Int = 0
    @Published public private(set) var archivedClips: [IncidentClipRecord] = []
    @Published public private(set) var lastIncidentEvent: IncidentClipRecord?
    @Published public private(set) var lastErrorMessage: String?

    /// Capture session exposed for the live preview layer when camera hardware is active.
    public let captureSession = AVCaptureSession()

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let sandboxRootDirectory: URL
    private let now: () -> Date

    private var rollingBuffer = RollingSegmentBuffer()
    private var telemetryRing: [RollingTelemetrySample] = []
    private var lastSpeedSample: (speedKmh: Double, timestamp: Date)?
    private var latestUserAcceleration: (x: Double, y: Double, z: Double)?
    private var lastTriggerTime: Date?
    private var isArchiving: Bool = false

    private let motionManager = CMMotionManager()
    private var movieOutput: AVCaptureMovieFileOutput?
    private var isCaptureConfigured = false
    private var activeSegmentStartTime: Date?
    private var activeSegmentPeakDecelG: Double = 0
    private var activeSegmentPeakSpeedKmh: Double = 0
    private var segmentRotationTimer: Timer?
    private var telemetryHeartbeatTimer: Timer?

    private static let thresholdDefaultsKey = "dashcam_deceleration_threshold_g_v1"
    private static let indexFilename = "incident_index.json"

    private var rollingBufferDirectory: URL {
        sandboxRootDirectory.appendingPathComponent("RollingBuffer", isDirectory: true)
    }

    private var incidentClipsDirectory: URL {
        sandboxRootDirectory.appendingPathComponent("IncidentClips", isDirectory: true)
    }

    private var indexFileURL: URL {
        incidentClipsDirectory.appendingPathComponent(Self.indexFilename)
    }

    public init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        sandboxRootDirectory: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.now = now

        if let sandboxRootDirectory {
            self.sandboxRootDirectory = sandboxRootDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.sandboxRootDirectory = appSupport.appendingPathComponent("DashCastDashCam", isDirectory: true)
        }

        let storedThreshold = defaults.object(forKey: Self.thresholdDefaultsKey) as? Double
        self.decelerationThresholdG = IncidentTriggerPolicy.clampedThreshold(
            storedThreshold ?? IncidentTriggerPolicy.standardDecelerationThresholdG
        )

        super.init()

        ensureSandboxDirectories()
        loadArchivedClips()
        refreshHardwareAndPermissionState()
        latestTelemetryWatermark = WindshieldTelemetryOverlay.formatWatermark(
            speedKmh: 0,
            decelerationG: 0,
            useMilesPerHour: false,
            timestamp: now()
        )
    }

    // MARK: - Configuration & Lifecycle

    public func refreshHardwareAndPermissionState() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        isCameraAvailable = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    public func setDecelerationThresholdG(_ value: Double) {
        let clamped = IncidentTriggerPolicy.clampedThreshold(value)
        decelerationThresholdG = clamped
        defaults.set(clamped, forKey: Self.thresholdDefaultsKey)
    }

    public func requestCameraAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraPermissionStatus = .authorized
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
            return granted
        default:
            cameraPermissionStatus = status
            return false
        }
    }

    public func arm(useMilesPerHour: Bool = false) {
        guard !isArmed else { return }
        lastErrorMessage = nil
        ensureSandboxDirectories()
        isArmed = true
        peakSessionDecelerationG = 0
        latestTelemetryWatermark = WindshieldTelemetryOverlay.formatWatermark(
            speedKmh: currentSpeedKmh,
            decelerationG: currentDecelerationG,
            useMilesPerHour: useMilesPerHour,
            timestamp: now()
        )

        startMotionMonitoring()
        startCaptureOrTelemetryLoop()
    }

    public func disarm() {
        guard isArmed else { return }
        isArmed = false
        isRecordingBuffer = false
        stopMotionMonitoring()
        stopCaptureAndRotationTimers()
        clearRollingBufferFiles()
        currentDecelerationG = 0
        lastSpeedSample = nil
        latestUserAcceleration = nil
    }

    // MARK: - Telemetry & Motion Ingestion

    public func ingestMotionAcceleration(
        x: Double,
        y: Double,
        z: Double,
        timestamp: Date? = nil,
        useMilesPerHour: Bool = false
    ) {
        let eventTime = timestamp ?? now()
        latestUserAcceleration = (x, y, z)
        let effectiveG = IncidentTriggerPolicy.effectiveDecelerationG(
            userAccelerationG: latestUserAcceleration,
            gpsDecelerationG: 0
        )
        evaluateTelemetrySample(
            speedKmh: currentSpeedKmh,
            decelerationG: effectiveG,
            timestamp: eventTime,
            useMilesPerHour: useMilesPerHour
        )
    }

    public func ingestTelemetry(
        speedKmh: Double,
        decelerationOverrideG: Double? = nil,
        timestamp: Date? = nil,
        useMilesPerHour: Bool = false
    ) {
        let eventTime = timestamp ?? now()
        let safeSpeed = speedKmh.isFinite ? max(0, speedKmh) : 0

        let gpsDecelG: Double
        if let override = decelerationOverrideG {
            gpsDecelG = max(0, override)
        } else if let prev = lastSpeedSample {
            let dt = eventTime.timeIntervalSince(prev.timestamp)
            gpsDecelG = IncidentTriggerPolicy.decelerationFromSpeedDelta(
                previousSpeedKmh: prev.speedKmh,
                currentSpeedKmh: safeSpeed,
                dt: dt
            )
        } else {
            gpsDecelG = 0
        }

        lastSpeedSample = (safeSpeed, eventTime)
        currentSpeedKmh = safeSpeed

        let effectiveG = IncidentTriggerPolicy.effectiveDecelerationG(
            userAccelerationG: latestUserAcceleration,
            gpsDecelerationG: gpsDecelG
        )

        evaluateTelemetrySample(
            speedKmh: safeSpeed,
            decelerationG: effectiveG,
            timestamp: eventTime,
            useMilesPerHour: useMilesPerHour
        )
    }

    private func evaluateTelemetrySample(
        speedKmh: Double,
        decelerationG: Double,
        timestamp: Date,
        useMilesPerHour: Bool
    ) {
        currentDecelerationG = decelerationG
        if decelerationG > peakSessionDecelerationG {
            peakSessionDecelerationG = decelerationG
        }
        if decelerationG > activeSegmentPeakDecelG {
            activeSegmentPeakDecelG = decelerationG
        }
        if speedKmh > activeSegmentPeakSpeedKmh {
            activeSegmentPeakSpeedKmh = speedKmh
        }

        latestTelemetryWatermark = WindshieldTelemetryOverlay.formatWatermark(
            speedKmh: speedKmh,
            decelerationG: decelerationG,
            useMilesPerHour: useMilesPerHour,
            timestamp: timestamp
        )

        appendTelemetryRingSample(
            RollingTelemetrySample(timestamp: timestamp, speedKmh: speedKmh, decelerationG: decelerationG),
            at: timestamp
        )

        guard isArmed else { return }

        if IncidentTriggerPolicy.shouldTriggerIncident(
            decelerationG: decelerationG,
            thresholdG: decelerationThresholdG,
            lastTriggerTime: lastTriggerTime,
            now: timestamp
        ) {
            lastTriggerTime = timestamp
            Task { [weak self] in
                guard let self else { return }
                _ = await self.triggerIncidentArchive(
                    reason: .gShockDeceleration,
                    decelerationG: decelerationG,
                    speedKmh: speedKmh,
                    useMilesPerHour: useMilesPerHour,
                    at: timestamp
                )
            }
        }
    }

    private func appendTelemetryRingSample(_ sample: RollingTelemetrySample, at timestamp: Date) {
        telemetryRing.append(sample)
        let cutoff = timestamp.addingTimeInterval(-IncidentTriggerPolicy.rollingWindowSeconds)
        telemetryRing.removeAll { $0.timestamp < cutoff }
        if !isCameraAvailable || cameraPermissionStatus != .authorized {
            updateBufferedMetricsFromTelemetry()
        }
    }

    private func updateBufferedMetricsFromTelemetry() {
        guard let first = telemetryRing.first, let last = telemetryRing.last else {
            bufferedSeconds = rollingBuffer.totalBufferedDuration
            bufferedSegmentCount = rollingBuffer.segments.count
            return
        }
        let span = max(0, last.timestamp.timeIntervalSince(first.timestamp))
        bufferedSeconds = min(
            IncidentTriggerPolicy.rollingWindowSeconds,
            max(span, rollingBuffer.totalBufferedDuration)
        )
        bufferedSegmentCount = rollingBuffer.segments.count
    }

    // MARK: - Rolling Segment Recording & Retention

    public func recordCompletedSegment(
        fileURL: URL,
        startTime: Date,
        endTime: Date,
        peakDecelerationG: Double,
        peakSpeedKmh: Double
    ) {
        let segment = DashCamSegment(
            filename: fileURL.lastPathComponent,
            startTime: startTime,
            endTime: endTime,
            peakDecelerationG: peakDecelerationG,
            peakSpeedKmh: peakSpeedKmh
        )
        let expired = rollingBuffer.append(segment)
        for old in expired {
            let oldURL = rollingBufferDirectory.appendingPathComponent(old.filename)
            try? fileManager.removeItem(at: oldURL)
        }
        bufferedSeconds = min(
            IncidentTriggerPolicy.rollingWindowSeconds,
            rollingBuffer.totalBufferedDuration
        )
        bufferedSegmentCount = rollingBuffer.segments.count
    }

    // MARK: - Incident Archiving

    @discardableResult
    public func triggerIncidentArchive(
        reason: IncidentTriggerReason,
        decelerationG: Double? = nil,
        speedKmh: Double? = nil,
        useMilesPerHour: Bool = false,
        at timestamp: Date? = nil
    ) async -> IncidentClipRecord? {
        guard !isArchiving else { return nil }
        isArchiving = true
        defer { isArchiving = false }

        ensureSandboxDirectories()
        let eventTime = timestamp ?? now()
        let impactG = decelerationG ?? currentDecelerationG
        let impactSpeed = speedKmh ?? currentSpeedKmh
        let watermark = WindshieldTelemetryOverlay.formatWatermark(
            speedKmh: impactSpeed,
            decelerationG: impactG,
            useMilesPerHour: useMilesPerHour,
            timestamp: eventTime
        )

        let snapshot = rollingBuffer.snapshotSegments(around: eventTime)
        let clipID = UUID()
        let isVideoArchiveAvailable = !snapshot.isEmpty
        let filename = isVideoArchiveAvailable
            ? "incident-\(clipID.uuidString).mp4"
            : "incident-\(clipID.uuidString).dashcam.json"
        let destinationURL = incidentClipsDirectory.appendingPathComponent(filename)

        var durationSeconds = snapshot.reduce(0) { $0 + $1.duration }
        if durationSeconds <= 0, let first = telemetryRing.first, let last = telemetryRing.last {
            durationSeconds = min(
                IncidentTriggerPolicy.rollingWindowSeconds,
                max(1.0, last.timestamp.timeIntervalSince(first.timestamp))
            )
        }
        if durationSeconds <= 0 {
            durationSeconds = min(IncidentTriggerPolicy.rollingWindowSeconds, max(1.0, bufferedSeconds))
        }

        if isVideoArchiveAvailable {
            let segmentURLs = snapshot.map { rollingBufferDirectory.appendingPathComponent($0.filename) }
            let exported = await exportWatermarkedClip(
                segmentURLs: segmentURLs,
                watermarkText: watermark,
                destinationURL: destinationURL
            )
            if !exported {
                // Fallback to telemetry archive manifest if headless AVAssetExportSession fails
                let fallbackFilename = "incident-\(clipID.uuidString).dashcam.json"
                let fallbackURL = incidentClipsDirectory.appendingPathComponent(fallbackFilename)
                writeTelemetryArtifact(
                    to: fallbackURL,
                    watermark: watermark,
                    reason: reason,
                    peakG: impactG,
                    speedKmh: impactSpeed,
                    createdAt: eventTime
                )
                return finalizeArchiveRecord(
                    id: clipID,
                    createdAt: eventTime,
                    reason: reason,
                    peakG: impactG,
                    speedKmh: impactSpeed,
                    useMilesPerHour: useMilesPerHour,
                    durationSeconds: durationSeconds,
                    filename: fallbackFilename,
                    watermark: watermark
                )
            }
        } else {
            writeTelemetryArtifact(
                to: destinationURL,
                watermark: watermark,
                reason: reason,
                peakG: impactG,
                speedKmh: impactSpeed,
                createdAt: eventTime
            )
        }

        return finalizeArchiveRecord(
            id: clipID,
            createdAt: eventTime,
            reason: reason,
            peakG: impactG,
            speedKmh: impactSpeed,
            useMilesPerHour: useMilesPerHour,
            durationSeconds: durationSeconds,
            filename: filename,
            watermark: watermark
        )
    }

    @discardableResult
    public func simulateGShockTest(
        speedKmh: Double = 72.0,
        decelerationG: Double = 0.82,
        useMilesPerHour: Bool = false
    ) async -> IncidentClipRecord? {
        let testTime = now()
        currentSpeedKmh = speedKmh
        currentDecelerationG = decelerationG
        latestTelemetryWatermark = WindshieldTelemetryOverlay.formatWatermark(
            speedKmh: speedKmh,
            decelerationG: decelerationG,
            useMilesPerHour: useMilesPerHour,
            timestamp: testTime
        )
        return await triggerIncidentArchive(
            reason: .simulatedTest,
            decelerationG: decelerationG,
            speedKmh: speedKmh,
            useMilesPerHour: useMilesPerHour,
            at: testTime
        )
    }

    public func toggleLock(clipID: UUID) {
        guard let index = archivedClips.firstIndex(where: { $0.id == clipID }) else { return }
        archivedClips[index].isLocked.toggle()
        saveArchivedClipsIndex()
    }

    public func deleteClip(clipID: UUID) {
        guard let index = archivedClips.firstIndex(where: { $0.id == clipID }) else { return }
        let removed = archivedClips.remove(at: index)
        try? fileManager.removeItem(at: clipURL(for: removed))
        saveArchivedClipsIndex()
    }

    public func clipURL(for record: IncidentClipRecord) -> URL {
        incidentClipsDirectory.appendingPathComponent(record.clipFilename)
    }

    // MARK: - Private Archiving & Sandbox Storage

    private func finalizeArchiveRecord(
        id: UUID,
        createdAt: Date,
        reason: IncidentTriggerReason,
        peakG: Double,
        speedKmh: Double,
        useMilesPerHour: Bool,
        durationSeconds: TimeInterval,
        filename: String,
        watermark: String
    ) -> IncidentClipRecord {
        let record = IncidentClipRecord(
            id: id,
            createdAt: createdAt,
            triggerReason: reason,
            peakDecelerationG: peakG,
            speedKmhAtImpact: speedKmh,
            useMilesPerHour: useMilesPerHour,
            durationSeconds: durationSeconds,
            clipFilename: filename,
            watermarkText: watermark,
            isLocked: false
        )
        archivedClips.insert(record, at: 0)
        pruneArchivedClipsIfNeeded()
        saveArchivedClipsIndex()
        lastIncidentEvent = record
        return record
    }

    private func pruneArchivedClipsIfNeeded() {
        while archivedClips.count > IncidentTriggerPolicy.maxArchivedClips {
            if let oldestUnlockedIndex = archivedClips.lastIndex(where: { !$0.isLocked }) {
                let removed = archivedClips.remove(at: oldestUnlockedIndex)
                try? fileManager.removeItem(at: clipURL(for: removed))
            } else {
                break
            }
        }
    }

    private func writeTelemetryArtifact(
        to url: URL,
        watermark: String,
        reason: IncidentTriggerReason,
        peakG: Double,
        speedKmh: Double,
        createdAt: Date
    ) {
        struct TelemetryArtifactPayload: Codable {
            let createdAt: Date
            let reason: IncidentTriggerReason
            let peakDecelerationG: Double
            let speedKmhAtImpact: Double
            let watermark: String
            let samples: [RollingTelemetrySample]
        }

        let payload = TelemetryArtifactPayload(
            createdAt: createdAt,
            reason: reason,
            peakDecelerationG: peakG,
            speedKmhAtImpact: speedKmh,
            watermark: watermark,
            samples: telemetryRing
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(payload) {
            try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    private func exportWatermarkedClip(
        segmentURLs: [URL],
        watermarkText: String,
        destinationURL: URL
    ) async -> Bool {
        let existingURLs = segmentURLs.filter { fileManager.fileExists(atPath: $0.path) }
        guard !existingURLs.isEmpty else { return false }

        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return false
        }

        var cursorTime = CMTime.zero
        var renderSize = CGSize(width: 1280, height: 720)
        var preferredTransform = CGAffineTransform.identity

        for url in existingURLs {
            let asset = AVURLAsset(url: url)
            do {
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard let videoTrack = tracks.first else { continue }
                let duration = try await asset.load(.duration)
                let naturalSize = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                if naturalSize.width > 0 && naturalSize.height > 0 {
                    renderSize = naturalSize
                    preferredTransform = transform
                }
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                try compVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: cursorTime)
                cursorTime = CMTimeAdd(cursorTime, duration)
            } catch {
                continue
            }
        }

        guard cursorTime > .zero else { return false }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: cursorTime)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        let watermarkLayer = WindshieldTelemetryOverlay.makeCompositionWatermarkLayer(
            text: watermarkText,
            renderSize: renderSize
        )
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(watermarkLayer)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPreset1280x720
        ) else {
            return false
        }
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = false

        if #available(iOS 18.0, *) {
            do {
                try await exportSession.export(to: destinationURL, as: .mp4)
                return true
            } catch {
                return false
            }
        } else {
            exportSession.outputURL = destinationURL
            exportSession.outputFileType = .mp4
            await exportSession.export()
            return exportSession.status == .completed
        }
    }

    private func ensureSandboxDirectories() {
        for dir in [sandboxRootDirectory, rollingBufferDirectory, incidentClipsDirectory] {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            var mutableDir = dir
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? mutableDir.setResourceValues(resourceValues)
        }
    }

    private func clearRollingBufferFiles() {
        let removed = rollingBuffer.clear()
        for segment in removed {
            try? fileManager.removeItem(at: rollingBufferDirectory.appendingPathComponent(segment.filename))
        }
        telemetryRing.removeAll()
        bufferedSeconds = 0
        bufferedSegmentCount = 0
    }

    private func loadArchivedClips() {
        guard let data = try? Data(contentsOf: indexFileURL) else {
            archivedClips = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        archivedClips = (try? decoder.decode([IncidentClipRecord].self, from: data)) ?? []
    }

    private func saveArchivedClipsIndex() {
        ensureSandboxDirectories()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(archivedClips) {
            try? data.write(to: indexFileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    // MARK: - Hardware Motion & AVFoundation Capture

    private func startMotionMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let ax = motion.userAcceleration.x
            let ay = motion.userAcceleration.y
            let az = motion.userAcceleration.z
            MainActor.assumeIsolated {
                self?.ingestMotionAcceleration(x: ax, y: ay, z: az)
            }
        }
    }

    private func stopMotionMonitoring() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    private func startCaptureOrTelemetryLoop() {
        refreshHardwareAndPermissionState()
        if isCameraAvailable && cameraPermissionStatus == .authorized {
            configureCaptureSessionIfNeeded()
            if !captureSession.isRunning {
                let session = captureSession
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                }
            }
            startNewSegmentRecording()
            segmentRotationTimer?.invalidate()
            segmentRotationTimer = Timer.scheduledTimer(
                withTimeInterval: IncidentTriggerPolicy.segmentDurationSeconds,
                repeats: true
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.rotateActiveSegment()
                }
            }
            isRecordingBuffer = true
        } else {
            // Telemetry-only rolling loop (Simulator or camera permission not yet granted)
            isRecordingBuffer = true
            telemetryHeartbeatTimer?.invalidate()
            telemetryHeartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isArmed else { return }
                    let timestamp = self.now()
                    self.latestTelemetryWatermark = WindshieldTelemetryOverlay.formatWatermark(
                        speedKmh: self.currentSpeedKmh,
                        decelerationG: self.currentDecelerationG,
                        useMilesPerHour: false,
                        timestamp: timestamp
                    )
                    self.appendTelemetryRingSample(
                        RollingTelemetrySample(
                            timestamp: timestamp,
                            speedKmh: self.currentSpeedKmh,
                            decelerationG: self.currentDecelerationG
                        ),
                        at: timestamp
                    )
                }
            }
        }
    }

    private func stopCaptureAndRotationTimers() {
        segmentRotationTimer?.invalidate()
        segmentRotationTimer = nil
        telemetryHeartbeatTimer?.invalidate()
        telemetryHeartbeatTimer = nil

        if let output = movieOutput, output.isRecording {
            output.stopRecording()
        }
        if captureSession.isRunning {
            let session = captureSession
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
    }

    private func configureCaptureSessionIfNeeded() {
        guard !isCaptureConfigured else { return }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: camera) else {
            return
        }

        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.hd1280x720) {
            captureSession.sessionPreset = .hd1280x720
        }
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        let output = AVCaptureMovieFileOutput()
        output.maxRecordedDuration = CMTime(
            seconds: IncidentTriggerPolicy.segmentDurationSeconds + 1.0,
            preferredTimescale: 600
        )
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            movieOutput = output
        }
        captureSession.commitConfiguration()
        isCaptureConfigured = true
    }

    private func startNewSegmentRecording() {
        guard let output = movieOutput, !output.isRecording else { return }
        activeSegmentStartTime = now()
        activeSegmentPeakDecelG = currentDecelerationG
        activeSegmentPeakSpeedKmh = currentSpeedKmh
        let segmentURL = rollingBufferDirectory.appendingPathComponent("seg-\(UUID().uuidString).mp4")
        output.startRecording(to: segmentURL, recordingDelegate: self)
    }

    private func rotateActiveSegment() {
        guard isArmed, let output = movieOutput else { return }
        if output.isRecording {
            output.stopRecording()
        } else {
            startNewSegmentRecording()
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension IncidentDashCamEngine: AVCaptureFileOutputRecordingDelegate {
    nonisolated public func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        let finishedAt = Date()
        let hasError = (error != nil)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let start = self.activeSegmentStartTime ?? finishedAt.addingTimeInterval(-IncidentTriggerPolicy.segmentDurationSeconds)
            if !hasError {
                self.recordCompletedSegment(
                    fileURL: outputFileURL,
                    startTime: start,
                    endTime: finishedAt,
                    peakDecelerationG: self.activeSegmentPeakDecelG,
                    peakSpeedKmh: self.activeSegmentPeakSpeedKmh
                )
            } else {
                try? self.fileManager.removeItem(at: outputFileURL)
            }
            if self.isArmed {
                self.startNewSegmentRecording()
            }
        }
    }
}
